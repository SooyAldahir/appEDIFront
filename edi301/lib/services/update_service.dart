import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/src/widgets/update_dialog.dart';

/// Avisa cuando hay una versión nueva en las tiendas.
///
/// La señal viene del backend (`GET /api/app-version`), no de leer las fichas
/// de App Store y Play Store. Dos razones: esas fichas cambian de formato y
/// tardan en propagar, y así el enlace de la tienda se puede corregir sin
/// recompilar la app.
///
/// Hay dos niveles:
/// - **opcional**: hay algo más nuevo. Se puede posponer 24 horas.
/// - **obligatoria**: la versión instalada está por debajo del mínimo
///   soportado. El diálogo no se puede cerrar. Es la red de seguridad para
///   cuando un cambio de backend rompe clientes viejos, como pasó con la
///   autenticación del socket.
///
/// Regla de oro: ante cualquier problema (sin red, respuesta rara, backend
/// caído) esto no hace nada. Un fallo de este servicio jamás debe impedirle
/// a alguien usar la app.
class UpdateService with WidgetsBindingObserver {
  UpdateService(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;
  final ApiHttp _http = ApiHttp();

  static const _kPospuestaHasta = 'update_pospuesta_hasta';
  static const _kPospuestaVersion = 'update_pospuesta_version';

  /// Cuánto se respeta un "más tarde".
  static const Duration _espera = Duration(hours: 24);

  /// Evita que el diálogo se apile si la consulta corre dos veces.
  bool _mostrando = false;

  /// Evita consultar en cada vuelta a primer plano si acaba de hacerlo.
  DateTime? _ultimaConsulta;
  static const Duration _minimoEntreConsultas = Duration(minutes: 30);

  void iniciar() {
    WidgetsBinding.instance.addObserver(this);
    // Al arrancar se consulta siempre, sin importar el mínimo entre consultas.
    verificar(ignorarIntervalo: true);
  }

  void detener() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de la tienda, esto hace que el aviso desaparezca solo si ya
    // actualizó, sin tener que cerrar y abrir la app.
    if (state == AppLifecycleState.resumed) verificar();
  }

  Future<void> verificar({bool ignorarIntervalo = false}) async {
    if (_mostrando) return;

    if (!ignorarIntervalo && _ultimaConsulta != null) {
      if (DateTime.now().difference(_ultimaConsulta!) < _minimoEntreConsultas) {
        return;
      }
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final plataforma = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : Platform.operatingSystem;

      final res = await _http.getJson(
        '/api/app-version',
        query: {'plataforma': plataforma, 'version': info.version},
      );
      _ultimaConsulta = DateTime.now();

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final estado = (data['estado'] ?? 'al_dia').toString();
      if (estado == 'al_dia') return;

      final url = (data['url_tienda'] ?? '').toString();
      if (url.isEmpty) return; // sin enlace, el botón no llevaría a ningún lado

      final obligatoria = estado == 'obligatoria';
      final versionNueva = (data['version_publicada'] ?? '').toString();

      if (!obligatoria && await _estaPospuesta(versionNueva)) return;

      await _mostrarDialogo(
        obligatoria: obligatoria,
        versionNueva: versionNueva,
        versionActual: info.version,
        notas: (data['notas'] ?? '').toString(),
        url: url,
      );
    } catch (e) {
      // Silencioso a propósito: sin red, backend caído o respuesta inesperada
      // simplemente no se avisa. La app sigue funcionando igual.
      debugPrint('No se pudo verificar la versión de la app: $e');
    }
  }

  /// Un "más tarde" vale 24 horas, y solo para esa versión concreta: si
  /// mientras tanto sale otra más nueva, se vuelve a avisar enseguida.
  Future<bool> _estaPospuesta(String versionNueva) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasta = prefs.getInt(_kPospuestaHasta);
      final version = prefs.getString(_kPospuestaVersion);
      if (hasta == null || version != versionNueva) return false;
      return DateTime.now().millisecondsSinceEpoch < hasta;
    } catch (_) {
      return false;
    }
  }

  Future<void> _posponer(String versionNueva) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kPospuestaHasta,
        DateTime.now().add(_espera).millisecondsSinceEpoch,
      );
      await prefs.setString(_kPospuestaVersion, versionNueva);
    } catch (_) {
      // Si no se pudo guardar, lo peor que pasa es que vuelva a preguntar.
    }
  }

  Future<void> _mostrarDialogo({
    required bool obligatoria,
    required String versionNueva,
    required String versionActual,
    required String notas,
    required String url,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    _mostrando = true;
    try {
      await showDialog<void>(
        context: context,
        // Una actualización obligatoria no se esquiva tocando fuera.
        barrierDismissible: !obligatoria,
        builder: (_) => UpdateDialog(
          obligatoria: obligatoria,
          versionNueva: versionNueva,
          versionActual: versionActual,
          notas: notas,
          onActualizar: () => abrirTienda(url),
          onMasTarde: obligatoria ? null : () => _posponer(versionNueva),
        ),
      );
    } finally {
      _mostrando = false;
    }
  }

  /// Abre la ficha de la tienda fuera de la app.
  ///
  /// `externalApplication` es importante: en Android hace que sea la app de
  /// Play Store la que abra la ficha, no un navegador dentro de la nuestra.
  static Future<bool> abrirTienda(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('No se pudo abrir la tienda: $e');
      return false;
    }
  }
}
