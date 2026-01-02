import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client_http.dart';

class PublicacionesApi {
  final ApiHttp _http = ApiHttp();

  // ---------------------------------------------------------------------------
  // 1. CREAR PUBLICACIÓN (Con Token Manual para evitar error 401)
  // ---------------------------------------------------------------------------
  Future<bool> crearPost({
    required int idUsuario,
    int? idFamilia,
    String? mensaje,
    File? imagen,
    String categoria = 'Familiar',
    String tipo = 'POST',
  }) async {
    try {
      final uri = Uri.parse('${ApiHttp.baseUrl}/api/publicaciones');
      final request = http.MultipartRequest('POST', uri);

      // --- A. OBTENER TOKEN ---
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        final userStr = prefs.getString('user');
        if (userStr != null) {
          final u = jsonDecode(userStr);
          token = u['token'] ?? u['session_token'] ?? u['access_token'];
        }
      }

      // --- B. AGREGAR HEADER DE AUTORIZACIÓN ---
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      } else {
        print("⚠️ Advertencia: Intentando subir post sin token.");
      }

      // --- C. AGREGAR CAMPOS DE TEXTO ---
      request.fields['id_usuario'] = idUsuario.toString();
      if (idFamilia != null) {
        request.fields['id_familia'] = idFamilia.toString();
      }
      request.fields['mensaje'] = mensaje ?? '';
      request.fields['categoria_post'] = categoria;
      request.fields['tipo'] = tipo;

      // --- D. AGREGAR IMAGEN ---
      if (imagen != null) {
        // Nota: Asegúrate que tu backend espere 'imagen' o 'image'.
        // Usualmente es 'imagen' según tu código anterior.
        final file = await http.MultipartFile.fromPath('imagen', imagen.path);
        request.files.add(file);
      }

      // --- E. ENVIAR ---
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("✅ Post creado con éxito");
        return true;
      } else {
        print(
          "❌ Error creando post (${response.statusCode}): ${response.body}",
        );
        return false;
      }
    } catch (e) {
      print("❌ Excepción en crearPost: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. OBTENER PENDIENTES
  // ---------------------------------------------------------------------------
  Future<List<dynamic>> getPendientes(int idFamilia) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. BUSCAR TOKEN
      String? token = prefs.getString('token');
      if (token == null) {
        final uStr = prefs.getString('user');
        if (uStr != null) {
          token = jsonDecode(uStr)['session_token'];
        }
      }

      // 2. PREPARAR URL Y HEADERS
      final url = Uri.parse(
        '${ApiHttp.baseUrl}/api/publicaciones/familia/$idFamilia/pendientes',
      );

      final headers = {'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token'; // <--- LA LLAVE MAESTRA
      }

      // 3. HACER LA PETICIÓN
      final res = await http.get(url, headers: headers);

      if (res.statusCode == 200) {
        return List<dynamic>.from(jsonDecode(res.body));
      } else {
        print("⚠️ Error Server pendientes (${res.statusCode}): ${res.body}");
        return [];
      }
    } catch (e) {
      print("⚠️ Error obteniendo pendientes: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 3. FEED DE LA FAMILIA
  // ---------------------------------------------------------------------------
  Future<List<dynamic>> getPostsFamilia(int idFamilia) async {
    try {
      final res = await _http.getJson('/api/publicaciones/familia/$idFamilia');
      if (res.statusCode == 200) {
        return List<dynamic>.from(jsonDecode(res.body));
      }
      return [];
    } catch (e) {
      print("⚠️ Error feed familia: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 4. MIS POSTS (HISTORIAL)
  // ---------------------------------------------------------------------------
  Future<List<dynamic>> getMisPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Búsqueda del token
      String? token = prefs.getString('token');
      if (token == null) {
        final userStr = prefs.getString('user');
        if (userStr != null) {
          final userJson = jsonDecode(userStr);
          token =
              userJson['token'] ??
              userJson['session_token'] ??
              userJson['access_token'];
        }
      }

      if (token == null) {
        print("⚠️ No encontré token en el celular.");
        return [];
      }

      final url = Uri.parse('${ApiHttp.baseUrl}/api/publicaciones/mis-posts');

      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        return List<dynamic>.from(jsonDecode(res.body));
      } else {
        print("Error Server (${res.statusCode}): ${res.body}");
        return [];
      }
    } catch (e) {
      print("⚠️ Error obteniendo mis posts: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 5. APROBAR O RECHAZAR SOLICITUD
  // ---------------------------------------------------------------------------
  Future<bool> responderSolicitud(int idPost, String nuevoEstado) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      if (token == null) {
        // Fallback buscar en user
        final uStr = prefs.getString('user');
        if (uStr != null) {
          token = jsonDecode(uStr)['session_token'];
        }
      }

      final url = Uri.parse(
        '${ApiHttp.baseUrl}/api/publicaciones/$idPost/estado',
      );

      final res = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'estado': nuevoEstado}),
      );

      return res.statusCode == 200;
    } catch (e) {
      print("⚠️ Error respondiendo solicitud: $e");
      return false;
    }
  }
}
