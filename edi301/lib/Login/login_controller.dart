import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/token_storage.dart';
import '../core/api_client_http.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:edi301/services/users_api.dart';

class LoginController {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final loading = ValueNotifier<bool>(false);

  final ApiHttp _http = ApiHttp();
  late BuildContext _ctx;

  final TokenStorage _tokenStorage = TokenStorage();
  final UsersApi _usersApi = UsersApi();

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
      final res = await _http.postJson(
        '/api/auth/login',
        data: {'login': login, 'password': password},
      );

      if (res.statusCode >= 400) {
        throw Exception('Credenciales inválidas (${res.statusCode})');
      }

      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;

      final token = (data['session_token'] ?? data['token'] ?? '').toString();
      if (token.isEmpty) throw Exception('No se recibió session_token');

      await _tokenStorage.save(token);

      try {
        final idUsuario = data['id_usuario'] ?? data['IdUsuario'];

        if (idUsuario != null) {
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

          try {
            String? fcmToken = await FirebaseMessaging.instance.getToken();
            if (fcmToken != null) {
              print("FCM Token obtenido: $fcmToken");
              int idInt = int.parse(idUsuario.toString());
              await _usersApi.updateFcmToken(idInt, fcmToken);
            }
          } catch (e) {
            print("No se pudo registrar el token FCM: $e");
          }
        }
      } catch (e) {
        print('Error en carga de datos adicionales: $e');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_token', token);
      await prefs.setString('user', jsonEncode(data));
      final rol = (data['rol'] ?? data['role'] ?? '').toString();
      final tipoUsuario = (data['TipoUsuario'] ?? data['tipoUsuario'] ?? '')
          .toString();
      final route = _routeForRole(rol, tipoUsuario);

      if (!_ctx.mounted) return;
      FocusScope.of(_ctx).unfocus();
      Navigator.of(_ctx).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      loading.value = false;
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
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
