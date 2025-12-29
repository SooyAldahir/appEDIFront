import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/api_client_http.dart';

class PublicacionesApi {
  final ApiHttp _http = ApiHttp();

  Future<void> crearPost({
    required int idUsuario,
    required int? idFamilia,
    required String mensaje,
    File? imagen,
    String categoria = 'Familiar',
  }) async {
    final r = await _http.multipart(
      '/api/publicaciones',
      fields: {
        'id_usuario': idUsuario.toString(),
        'id_familia': idFamilia?.toString() ?? '',
        'mensaje': mensaje,
        'categoria_post': categoria,
      },
      files: imagen != null
          ? [await http.MultipartFile.fromPath('image', imagen.path)]
          : [],
    );

    // CORREGIDO: Usamos getJson en lugar de get
    Future<List<dynamic>> getPendientes(int idFamilia) async {
      final r = await _http.getJson('/api/publicaciones/pendientes/$idFamilia');

      if (r.statusCode >= 400) {
        throw Exception('Error obteniendo pendientes: ${r.body}');
      }

      return jsonDecode(r.body) as List<dynamic>;
    }

    Future<void> updateEstado(int postId, String nuevoEstado) async {
      final r = await _http.putJson(
        '/api/publicaciones/$postId/estado', // Asegúrate que esta ruta coincida con tu backend
        data: {"estado": nuevoEstado},
      );

      if (r.statusCode >= 400) {
        throw Exception('Error actualizando estado: ${r.body}');
      }
    }

    Future<void> like(int postId) async {
      final r = await _http.postJson('/api/publicaciones/$postId/like');
      if (r.statusCode >= 400)
        throw Exception('Error ${r.statusCode}: ${r.body}');
    }
  }
}
