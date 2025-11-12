// lib/services/familia_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/models/family_model.dart';

class FamiliaApi {
  final ApiHttp _http = ApiHttp();

  String _normalizeResidence(String r) {
    final s = r.trim().toUpperCase();
    if (s.startsWith('INT')) return 'INTERNA';
    if (s.startsWith('EXT')) return 'EXTERNA';
    return 'INTERNA';
  }

  Future<Family> createFamily({
    required String nombreFamilia,
    required String residencia, // 'INTERNA' | 'EXTERNA'
    String? direccion,
    int? papaId,
    int? mamaId,
    List<int>? hijos, // <-- NUEVO PARÁMETRO
  }) async {
    final payload = <String, dynamic>{
      'nombre_familia': nombreFamilia,
      'residencia': _normalizeResidence(residencia),
      if (direccion != null && direccion.trim().isNotEmpty)
        'direccion': direccion.trim(),
      if (papaId != null) 'papa_id': papaId,
      if (mamaId != null) 'mama_id': mamaId,
      if (hijos != null && hijos.isNotEmpty) 'hijos': hijos, // <-- NUEVO CAMPO
    };

    final res = await _http.postJson('/api/familias', data: payload);
    debugPrint('POST /api/familias -> ${res.statusCode} :: ${res.body}');
    if (res.statusCode >= 400) {
      // Intenta decodificar el error del backend para un mensaje más claro
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded.containsKey('error')) {
          throw Exception(decoded['error']);
        }
      } catch (_) {}
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      final Map<String, dynamic> m = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'])
          : decoded;
      return Family.fromJson(m);
    }
    throw Exception('Respuesta inválida del servidor al crear familia');
  }

  Future<List<Map<String, dynamic>>> buscarFamiliasPorNombre(String q) async {
    final res = await _http.getJson('/api/familias/search', query: {'name': q});
    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is List) {
      return data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (data is Map && data.values.isNotEmpty && data.values.first is List) {
      final list = data.values.first as List;
      return list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> getById(int id) async {
    final res = await _http.getJson('/api/familias/$id');
    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<Map<String, dynamic>?> getByIdent(int ident) async {
    final res = await _http.getJson('/api/familias/por-ident/$ident');
    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}
