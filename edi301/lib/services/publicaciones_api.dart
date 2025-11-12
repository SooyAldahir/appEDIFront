import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_client_http.dart';

class PublicacionesApi {
  final ApiHttp _http = ApiHttp();

  Future<int> crearPost(int idUsuario) async {
    final r = await _http.postJson(
      '/api/publicaciones',
      data: {"IdUsuario": idUsuario},
    );
    if (r.statusCode >= 400)
      throw Exception('Error ${r.statusCode}: ${r.body}');
    return (jsonDecode(r.body) as Map)['PostID'] as int;
  }

  Future<void> like(int postId) async {
    final r = await _http.postJson('/api/publicaciones/$postId/like');
    if (r.statusCode >= 400)
      throw Exception('Error ${r.statusCode}: ${r.body}');
  }
}
