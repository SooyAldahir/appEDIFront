import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/auth/token_storage.dart'; // 👈 IMPORTANTE: Usamos tu gestor oficial
import 'package:http/http.dart' as http;

class MensajesApi {
  final String _baseUrl = ApiHttp.baseUrl;
  // Instanciamos el storage oficial
  final TokenStorage _tokenStorage = TokenStorage();

  // 1. Obtener historial del chat
  Future<List<dynamic>> getMensajesFamilia(int idFamilia) async {
    try {
      // 👇 CAMBIO CLAVE: Leemos el token desde TokenStorage, no a mano
      final token = await _tokenStorage.read();

      if (token == null || token.isEmpty) {
        print("⚠️ Chat: No hay token válido en TokenStorage.");
        return [];
      }

      final uri = Uri.parse('$_baseUrl/api/mensajes/familia/$idFamilia');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<dynamic>.from(jsonDecode(response.body));
      } else {
        print("⚠️ Error Chat ${response.statusCode}: ${response.body}");
        return [];
      }
    } catch (e) {
      print("⚠️ Error excepción chat: $e");
      return [];
    }
  }

  // 2. Enviar mensaje
  Future<bool> enviarMensaje(int idFamilia, String mensaje) async {
    try {
      // 👇 CAMBIO CLAVE: Leemos el token desde TokenStorage
      final token = await _tokenStorage.read();

      if (token == null || token.isEmpty) {
        print("⚠️ Chat: No hay token, no se puede enviar.");
        return false;
      }

      final uri = Uri.parse('$_baseUrl/api/mensajes');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'id_familia': idFamilia, 'mensaje': mensaje}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print(
          "⚠️ Error enviando mensaje ${response.statusCode}: ${response.body}",
        );
        return false;
      }
    } catch (e) {
      print("⚠️ Error excepción enviando: $e");
      return false;
    }
  }
}
