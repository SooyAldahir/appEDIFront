import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Importante para el mimeType
import 'package:edi301/auth/token_storage.dart';

class FotosApi {
  // NOTA: Asegúrate de que esta URL sea la correcta.
  // La estoy tomando de tu archivo 'api_client_http.dart'
  final String _baseUrl = 'http://192.168.100.18:3000/api';
  final TokenStorage _tokenStorage = TokenStorage();

  Future<String> _uploadImage(String endpoint, File imageFile) async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw Exception('Token no encontrado. Inicie sesión de nuevo.');
    }

    var uri = Uri.parse('$_baseUrl/$endpoint');
    var request = http.MultipartRequest('POST', uri);

    // Añadir cabecera de autenticación
    request.headers['Authorization'] = 'Bearer $token';

    // Añadir el archivo
    String fileName = imageFile.path.split('/').last;
    request.files.add(
      await http.MultipartFile.fromPath(
        'foto', // Este es el nombre del campo que espera el backend (req.files.foto)
        imageFile.path,
        filename: fileName,
        contentType: MediaType(
          'image',
          'jpeg',
        ), // Ajusta si es necesario (png, etc.)
      ),
    );

    // Enviar la petición
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.body; // O parsea el JSON si el backend devuelve algo
    } else {
      throw Exception(
        'Error al subir imagen. Código: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Método específico para la foto de perfil
  Future<void> uploadProfileImage(File imageFile) async {
    try {
      await _uploadImage('fotos/perfil', imageFile);
      print('Foto de perfil subida exitosamente.');
    } catch (e) {
      print('Error en uploadProfileImage: $e');
      rethrow;
    }
  }

  // Método específico para la foto de portada
  Future<void> uploadCoverImage(File imageFile) async {
    try {
      await _uploadImage('fotos/portada', imageFile);
      print('Foto de portada subida exitosamente.');
    } catch (e) {
      print('Error en uploadCoverImage: $e');
      rethrow;
    }
  }
}
