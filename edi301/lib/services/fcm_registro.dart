import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edi301/services/users_api.dart';

/// Registro del token de notificaciones, en un solo lugar.
///
/// Antes esto estaba escrito tres veces —en el arranque, en el login y en el
/// refresco— y cada copia hacía algo distinto. La del arranque esperaba el
/// token de APNs en iOS; la del login no, así que en iOS `getToken()` fallaba
/// justo cuando más importa (el primer inicio de sesión tras instalar) y ese
/// dispositivo se quedaba sin token para siempre.
class FcmRegistro {
  static final UsersApi _usersApi = UsersApi();

  /// Pide permiso de notificaciones a través de Firebase Messaging.
  ///
  /// Es distinto de pedirlo con flutter_local_notifications: en iOS, ESTE es
  /// el que hace que la app se registre en APNs. Solo con el permiso del
  /// plugin local, el token de APNs podía no llegar nunca.
  static Future<void> pedirPermiso() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM: no se pudo pedir permiso: $e');
    }
  }

  /// El token de FCM, esperando primero a APNs en iOS.
  ///
  /// El token de APNs no está listo en el instante del arranque: iOS lo
  /// entrega de forma asíncrona al AppDelegate. Un solo intento se adelanta
  /// según la red y el dispositivo, que es la razón por la que esto "funciona
  /// en algunos y en otros no". Se reintenta con espera creciente.
  static Future<String?> obtenerToken({int intentos = 6}) async {
    if (Platform.isIOS) {
      String? apns;
      for (var i = 0; i < intentos; i++) {
        try {
          apns = await FirebaseMessaging.instance.getAPNSToken();
        } catch (e) {
          debugPrint('FCM: getAPNSToken falló: $e');
        }
        if (apns != null) break;
        // 0.3 s, 0.6 s, 0.9 s... ~6 s en total con 6 intentos.
        await Future<void>.delayed(Duration(milliseconds: 300 * (i + 1)));
      }
      if (apns == null) {
        // En el simulador esto es normal y no hay nada que hacer.
        debugPrint('FCM: sin token de APNs; no se puede registrar en este dispositivo.');
        return null;
      }
    }

    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t == null || t.isEmpty) return null;
      return t;
    } catch (e) {
      debugPrint('FCM: getToken falló: $e');
      return null;
    }
  }

  /// Manda el token al servidor. Devuelve true si quedó registrado.
  ///
  /// Se manda SIEMPRE, sin mirar `last_fcm_token_sent`, porque cada inicio de
  /// sesión crea una fila de sesión nueva con el token vacío: saltarse el
  /// envío porque "este token ya se mandó una vez" deja esa sesión muda.
  static Future<bool> registrar({String motivo = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null || userJson.isEmpty) return false;

    int? idUsuario;
    try {
      final u = jsonDecode(userJson);
      if (u is Map) {
        final raw = u['id_usuario'] ?? u['IdUsuario'];
        idUsuario = raw == null ? null : int.tryParse(raw.toString());
      }
    } catch (_) {}
    if (idUsuario == null) return false;

    final token = await obtenerToken();
    if (token == null) return false;

    // El servidor ignora este id y usa el de la sesión; se sigue mandando por
    // compatibilidad con versiones anteriores del backend.
    final ok = await _usersApi.updateFcmToken(idUsuario, token);
    if (ok) {
      await prefs.setString('last_fcm_token_sent', token);
      debugPrint('FCM: token registrado${motivo.isEmpty ? '' : ' ($motivo)'}');
    } else {
      debugPrint('FCM: el servidor no aceptó el token${motivo.isEmpty ? '' : ' ($motivo)'}');
    }
    return ok;
  }

  /// Escucha los cambios de token.
  ///
  /// Se engancha UNA vez al arrancar y SIN comprobar si hay sesión. Antes se
  /// salía temprano cuando nadie había iniciado sesión, así que quien entraba
  /// en ese mismo arranque se quedaba sin escucha: si el token rotaba después,
  /// el servidor nunca se enteraba.
  static void escucharRefresco() {
    FirebaseMessaging.instance.onTokenRefresh.listen((nuevo) async {
      if (nuevo.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      // La comprobación va aquí, en el momento del evento, no al enganchar.
      if (userJson == null || userJson.isEmpty) return;
      if (prefs.getString('last_fcm_token_sent') == nuevo) return;
      await registrar(motivo: 'refresco');
    });
  }
}
