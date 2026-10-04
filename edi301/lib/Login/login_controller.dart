import 'dart:convert';
import 'package:edi301/services/fcm_registro.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/token_storage.dart';
import '../core/api_client_http.dart';
import '../core/api_error.dart';
import 'package:edi301/services/socket_service.dart';
import 'package:edi301/src/pages/Family/family_match_modal.dart';

class LoginController {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final loading = ValueNotifier<bool>(false);

  final ApiHttp _http = ApiHttp();
  late BuildContext _ctx;

  final TokenStorage _tokenStorage = TokenStorage();

  void init(BuildContext context) => _ctx = context;

  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    loading.dispose();
  }

  void goToRegisterPage() {
    Navigator.pushNamed(_ctx, 'register');
  }

  Future<void> goToHomePage() async {
    final login = emailCtrl.text.trim();
    final password = passCtrl.text;

    if (login.isEmpty || password.isEmpty) {
      _snack('Ingresa usuario y contraseña');
      return;
    }

    loading.value = true;

    try {
      // Identificación del dispositivo para multi-sesión.
      // Usamos solo dart:io para no agregar dependencias nuevas.
      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
              ? 'android'
              : Platform.operatingSystem;
      final deviceInfo =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'
              .trim();
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getOrCreateDeviceId(prefs);

      final res = await _http.postJson(
        '/api/auth/login',
        data: {
          'login': login,
          'password': password,
          'platform': platform,
          'device_info': deviceInfo,
          'device_id': deviceId,
        },
      );

      if (res.statusCode == 401 || res.statusCode == 400) {
        throw Exception('Correo o contraseña incorrectos. Verifica tus datos.');
      }
      if (res.statusCode == 403) {
        throw Exception('Tu cuenta está desactivada. Contacta al administrador.');
      }
      if (res.statusCode == 404) {
        throw Exception('No existe una cuenta registrada con ese correo.');
      }
      if (res.statusCode >= 400) {
        throw Exception(parseHttpError(res));
      }

      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;

      final token = (data['session_token'] ?? data['token'] ?? '').toString();
      if (token.isEmpty) throw Exception('No se recibió session_token');

      // Única escritura del token: queda en el almacén seguro del sistema.
      // Guardarlo antes de cualquier petición autenticada evita el fallo del
      // primer login, porque ApiHttp lo lee de aquí.
      await _tokenStorage.save(token);

      // El socket se autentica con ese mismo token. Al arrancar la app sin
      // sesión no se conectó, así que aquí se levanta con las credenciales
      // recién obtenidas.
      await SocketService().reconnectWithAuth();

      // Cargar datos extra (familia) si aplica
      final idUsuario = data['id_usuario'] ?? data['IdUsuario'];
      if (idUsuario != null) {
        try {
          final familiaRes = await _http.getJson('/api/usuarios/$idUsuario');
          if (familiaRes.statusCode == 200) {
            final usuarioCompleto =
                jsonDecode(familiaRes.body) as Map<String, dynamic>;
            final idFamilia =
                usuarioCompleto['id_familia'] ?? usuarioCompleto['FamiliaID'];
            if (idFamilia != null) {
              data['id_familia'] = idFamilia;
            }
          }
        } catch (e) {
          print('Error consultando usuario completo: $e');
        }
      }

      // Guardar sesión local
      await prefs.setString('user', jsonEncode(data));

      // Aquí estaba el bug de iOS.
      //
      // Esta copia llamaba a getToken() directamente, sin esperar el token de
      // APNs, mientras que la del arranque sí lo esperaba. En iOS getToken()
      // falla si APNs no está listo, y justo en el primer inicio de sesión
      // tras instalar no lo está: el token no se mandaba nunca y ese
      // dispositivo se quedaba sin notificaciones hasta que se reiniciaba la
      // app. Ahora las dos rutas usan el mismo código, que espera y reintenta.
      //
      // Se registra en cada login aunque el token no haya cambiado: cada
      // inicio de sesión crea una fila de sesión nueva con el token vacío.
      await FcmRegistro.registrar(motivo: 'login');

      final rol = (data['rol'] ?? data['role'] ?? '').toString();
      final tipoUsuario = (data['TipoUsuario'] ?? data['tipoUsuario'] ?? '')
          .toString();
      final route = _routeForRole(rol, tipoUsuario);

      if (!_ctx.mounted) return;
      FocusScope.of(_ctx).unfocus();

      // Cierra el contexto de autocompletado indicando que las credenciales
      // SÍ sirvieron. Esto es lo que hace que iOS muestre "¿Guardar esta
      // contraseña en el Llavero?" y que Android ofrezca guardarla en el
      // Gestor de Google. Va solo en la ruta de éxito: si el login falla, no
      // hay que ofrecer guardar nada.
      TextInput.finishAutofillContext();

      // ── Modal "Elige tu familia" (familias manuales pendientes) ──────────
      // Si el registro previo dejó candidatos pendientes en SharedPreferences,
      // los mostramos ahora — el usuario ya está autenticado.
      await _maybeShowFamilyMatch(prefs, idUsuario);

      if (!_ctx.mounted) return;
      Navigator.of(_ctx).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      loading.value = false;
    }
  }

  Future<String> _getOrCreateDeviceId(SharedPreferences prefs) async {
    const key = 'edi301_device_id';
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
        '${random.nextInt(1 << 32).toRadixString(36)}-'
        '${random.nextInt(1 << 32).toRadixString(36)}';
    await prefs.setString(key, id);
    return id;
  }

  /// Muestra el modal "Elige tu familia" si el registro previo dejó
  /// candidatos pendientes en SharedPreferences. Borra la marca tras mostrar
  /// el modal (independientemente de si el usuario eligió o saltó).
  Future<void> _maybeShowFamilyMatch(SharedPreferences prefs, dynamic idUsuario) async {
    final raw = prefs.getString('pending_family_match');
    if (raw == null || raw.isEmpty) return;

    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return;

      // Aseguramos que es el mismo usuario que acaba de registrarse
      final pendienteId = parsed['id_usuario'];
      if (pendienteId != null && idUsuario != null &&
          pendienteId.toString() != idUsuario.toString()) {
        return; // No coincide → no mostrar (otra cuenta)
      }

      final list = parsed['candidatos'];
      if (list is! List || list.isEmpty) return;

      final candidatos = list
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!_ctx.mounted) return;
      final realId = int.tryParse((idUsuario ?? pendienteId).toString()) ?? 0;
      if (realId <= 0) return;

      await FamilyMatchModal.show(_ctx, idUsuario: realId, candidatos: candidatos);
    } catch (e) {
      print('Error mostrando family match modal: $e');
    } finally {
      // Limpiar para que no vuelva a aparecer en futuros logins
      await prefs.remove('pending_family_match');
    }
  }

  String _routeForRole(String rol, String tipoUsuario) {
    switch (rol) {
      case 'Admin':
      case 'PapaEDI':
      case 'MamaEDI':
      case 'HijoEDI':
      case 'HijoSanguineo':
        return 'home';
      default:
        return 'home';
    }
  }

  void _snack(String msg) {
    if (!_ctx.mounted) return;
    ScaffoldMessenger.of(_ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}
