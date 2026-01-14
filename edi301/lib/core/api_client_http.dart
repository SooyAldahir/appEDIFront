import 'dart:async';
import 'dart:convert';
import 'dart:io'; // 👈 Importante para detectar Android
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiHttp extends http.BaseClient {
  ApiHttp._internal();

  static final ApiHttp _i = ApiHttp._internal();
  factory ApiHttp() => _i;

  // 1. IP Dinámica para que funcione en Android y iOS/Web
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  final http.Client _inner = http.Client();
  final Duration _timeout = const Duration(seconds: 20);

  // Headers base solo para JSON
  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('session_token');
    return (t != null && t.isNotEmpty) ? t : null;
  }

  Uri _resolve(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Uri.parse(url);
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = url.startsWith('/') ? url : '/$url';
    return Uri.parse('$base$path');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _readToken();

    // 2. Autenticación siempre
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Siempre aceptamos JSON como respuesta
    request.headers['Accept'] = 'application/json';

    // 3. PROTECCIÓN CRÍTICA:
    // Si NO es multipart (fotos) y no tiene Content-Type, le ponemos JSON.
    // Si ES multipart, NO tocamos el Content-Type (lo maneja la librería con el boundary).
    if (request is! http.MultipartRequest) {
      if (!request.headers.containsKey('Content-Type')) {
        request.headers['Content-Type'] = 'application/json';
      }
    }

    return _inner.send(request).timeout(_timeout);
  }

  // --- MÉTODOS JSON ---

  Future<http.Response> getJson(String url, {Map<String, dynamic>? query}) {
    final uri = _resolve(url).replace(
      queryParameters: {...?query?.map((k, v) => MapEntry(k, v?.toString()))},
    );
    return get(uri).timeout(_timeout);
  }

  Future<http.Response> postJson(String url, {Object? data}) {
    final uri = _resolve(url);
    return post(
      uri,
      headers: _jsonHeaders, // 👈 4. FORZAMOS HEADER AQUÍ PARA EL LOGIN
      body: data == null ? null : jsonEncode(data),
    ).timeout(_timeout);
  }

  Future<http.Response> putJson(String url, {Object? data}) {
    final uri = _resolve(url);
    return put(
      uri,
      headers: _jsonHeaders, // 👈 Forzamos header también en PUT
      body: data == null ? null : jsonEncode(data),
    ).timeout(_timeout);
  }

  Future<http.Response> deleteJson(String url, {Object? data}) {
    final uri = _resolve(url);
    final hasBody = data != null;
    if (hasBody) {
      final req = http.Request('DELETE', uri);
      req.headers.addAll(_jsonHeaders); // 👈 Forzamos header en DELETE con body
      req.body = jsonEncode(data);
      return send(req).then(http.Response.fromStream);
    }
    return delete(uri).timeout(_timeout);
  }

  // --- SUBIDA DE ARCHIVOS ---

  // 5. Agregamos el parámetro 'method' para soportar PUT (fotos de perfil)
  Future<http.StreamedResponse> multipart(
    String url, {
    String method = 'POST',
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) {
    final uri = _resolve(url);
    // Usamos el método dinámico (POST o PUT)
    final req = http.MultipartRequest(method, uri);

    if (fields != null) req.fields.addAll(fields);
    if (files != null) req.files.addAll(files);

    // Al llamar a send(req), la lógica de arriba NO pondrá application/json
    // y dejará que MultipartRequest ponga el 'multipart/form-data; boundary=...' correcto.
    return send(req);
  }

  Future<http.Response> patchJson(String url, {Object? data}) {
    final uri = _resolve(url);
    final req = http.Request('PATCH', uri);
    req.headers.addAll(_jsonHeaders);
    if (data != null) req.body = jsonEncode(data);
    return send(req).then(http.Response.fromStream).timeout(_timeout);
  }
}
