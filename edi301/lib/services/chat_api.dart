import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';

class ChatApi {
  final ApiHttp _http = ApiHttp();

  Future<List<dynamic>> getMyChats() async {
    final res = await _http.getJson('/api/chat');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  Future<List<dynamic>> getMessages(int idSala) async {
    final res = await _http.getJson('/api/chat/$idSala/messages');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  Future<bool> sendMessage(int idSala, String mensaje) async {
    final res = await _http.postJson(
      '/api/chat/message',
      data: {'id_sala': idSala, 'mensaje': mensaje},
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<int?> initPrivateChat(int targetUserId) async {
    final res = await _http.postJson(
      '/api/chat/private',
      data: {'targetUserId': targetUserId},
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body);
      return body['id_sala'];
    }
    return null;
  }
}
