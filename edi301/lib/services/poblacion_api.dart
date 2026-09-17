import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

/// Censo de usuarios de la app, para estudios y muestreo.
/// Solo Admin: el backend responde 403 a cualquier otro rol.
class PoblacionApi {
  final _http = ApiHttp();

  Future<Map<String, dynamic>> resumen() async {
    final r = await _http.getJson('/api/poblacion');
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }
}
