import 'dart:convert';
import 'package:http/http.dart' as http;

class OtpService {
  final String _baseUrl = 'https://api-otp.app.syswork.online/api/v1';

  final String _serviceEmail = 'irving.patricio@ulv.edu.mx';
  final String _servicePassword = 'irya0904';

  /// 1. Autenticación
  Future<String> _authenticate() async {
    final url = Uri.parse('$_baseUrl/user/login');
    print('🔐 Autenticando servicio OTP...');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _serviceEmail,
          'password': _servicePassword,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final token = body['token'].toString();
        print('🔐 Token obtenido (Longitud: ${token.length})');
        return token;
      } else {
        print('❌ Error Auth: ${response.body}');
        throw Exception('Fallo la autenticación del servicio OTP.');
      }
    } catch (e) {
      print('❌ Error Conexión Auth: $e');
      rethrow;
    }
  }

  /// 2. Enviar el OTP
  Future<void> sendOtp(String userEmail) async {
    try {
      final token = await _authenticate();

      // URL Correcta
      final url = Uri.parse(
        'https://api-otp.app.syswork.online/api/v1/otp_app/',
      );

      print('📧 Enviando OTP a: $userEmail');

      // --- ESTRATEGIA MULTI-HEADER ---
      // Enviamos el token en varios formatos para asegurar que el servidor lo lea
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Estándar JWT
        'x-access-token': token, // Común en Node.js
        'token': token, // Alternativa simple
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'email': userEmail,
          'subject': 'Verificacion de Email',
          'message': 'Verifica tu email con el codigo de abajo',
          'duration': 1,
        }),
      );

      print('📧 Estatus SendOTP: ${response.statusCode}');

      if (response.statusCode >= 400) {
        print('❌ Error SendOTP Body: ${response.body}');
        try {
          final body = jsonDecode(response.body);
          throw Exception(body['message'] ?? 'Error (${response.statusCode})');
        } catch (_) {
          throw Exception(
            'Error al enviar (${response.statusCode}): ${response.body}',
          );
        }
      }

      print('✅ OTP Enviado con éxito');
    } catch (e) {
      print('❌ Excepción en sendOtp: $e');
      rethrow;
    }
  }

  /// 3. Verificar el OTP
  Future<bool> verifyOtp(String userEmail, String otpCode) async {
    try {
      final token = await _authenticate();

      // URL Correcta (según PDF página 3)
      final url = Uri.parse('$_baseUrl/email_verification/verifyOTP');

      print('🔍 Verificando OTP...');

      // Aplicamos la misma estrategia de headers aquí
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'x-access-token': token,
        'token': token,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'email': userEmail, 'otp': otpCode}),
      );

      if (response.statusCode == 200) {
        print('✅ Código verificado. Body: ${response.body}');
        // Verificamos si la respuesta confirma la verificación
        try {
          final body = jsonDecode(response.body);
          if (body['verified'] == true) return true;
        } catch (_) {}

        return true; // Asumimos true si es 200, basado en historial
      }

      print('⚠️ Código incorrecto o error: ${response.body}');
      return false;
    } catch (e) {
      print('❌ Error VerifyOTP: $e');
      return false;
    }
  }
}
