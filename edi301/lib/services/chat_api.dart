import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';

class ChatApi {
  final ApiHttp _http = ApiHttp();

  // 1. Obtener lista de mis chats
  Future<List<dynamic>> getMyChats() async {
    final res = await _http.getJson('/api/chat');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  // 2. Obtener mensajes de una sala
  Future<List<dynamic>> getMessages(int idSala) async {
    final res = await _http.getJson('/api/chat/$idSala/messages');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  // 3. Enviar mensaje
  Future<bool> sendMessage(int idSala, String mensaje) async {
    final res = await _http.postJson(
      '/api/chat/message',
      data: {'id_sala': idSala, 'mensaje': mensaje},
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // 4. Iniciar Chat Privado (Magia: Crea o devuelve existente)
  // Devuelve el id_sala
  Future<int?> initPrivateChat(int targetUserId) async {
    final res = await _http.postJson(
      '/api/chat/private',
      data: {'targetUserId': targetUserId},
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body);
      return body['id_sala']; // El backend debe devolver { id_sala: 123 }
    }
    return null;
  }
}
