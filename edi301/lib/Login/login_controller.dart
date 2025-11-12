import 'dart:convert';
import 'package:flutter/material.dart';
// 1. Importar AMBOS almacenamientos
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/token_storage.dart';
import '../core/api_client_http.dart';

class LoginController {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final loading = ValueNotifier<bool>(false);

  final ApiHttp _http = ApiHttp();
  late BuildContext _ctx;

  // 2. Instanciar el almacenamiento seguro
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

      // --- 3. Guardar el TOKEN en SecureStorage ---
      await _tokenStorage.save(token);

      // --- 4. Guardar los DATOS DE USUARIO en SharedPreferences ---
      // (Esto es lo que faltaba y arregla tu página de perfil)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(data));
      // -----------------------------------------------------------

      // Ruteo opcional según rol/tipo
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

  // Mapa de roles -> ruta
  String _routeForRole(String rol, String tipoUsuario) {
    switch (rol) {
      case 'Admin':
        return 'admin';
      case 'PapaEDI':
      case 'MamaEDI':
        return 'home';
      case 'HijoEDI':
      case 'HijoSanguineo':
        return 'home';
      default:
        if (tipoUsuario == 'EXTERNO') return 'home';
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
