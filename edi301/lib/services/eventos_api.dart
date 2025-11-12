// lib/services/eventos_api.dart
import 'dart:convert';
import '../core/api_client_http.dart';

// --- MODELO (para la lista) ---
// (Lo ponemos aquí para simplicidad)
class Evento {
  final int id;
  final String titulo;
  final String? descripcion;
  final DateTime fechaEvento;
  final String? horaEvento;
  final String? imagen;
  final String estado;

  Evento({
    required this.id,
    required this.titulo,
    this.descripcion,
    required this.fechaEvento,
    this.horaEvento,
    this.imagen,
    required this.estado,
  });

  factory Evento.fromJson(Map<String, dynamic> j) {
    return Evento(
      id: j['id_actividad'],
      titulo: j['titulo'],
      descripcion: j['descripcion'],
      fechaEvento: DateTime.parse(j['fecha_evento']),
      horaEvento: j['hora_evento'],
      imagen: j['imagen'],
      estado: j['estado_publicacion'],
    );
  }
}
// --- FIN DEL MODELO ---

class EventosApi {
  final ApiHttp _http = ApiHttp();

  // --- FUNCIÓN CORREGIDA ---
  Future<Map<String, dynamic>> crearEvento({
    required String titulo,
    required DateTime fecha,
    String? hora, // (ej: "13:00")
    String? descripcion,
    String? imagenUrl,
  }) async {
    final payload = {
      "titulo": titulo,
      "descripcion": descripcion,
      "fecha_evento": fecha.toIso8601String().split('T').first, // "YYYY-MM-DD"
      "hora_evento": hora, // "HH:MM"
      "imagen": imagenUrl,
      "estado_publicacion": "Publicada",
    };

    final res = await _http.postJson('/api/agenda', data: payload);

    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) {
      return body;
    }
    throw Exception('La API no retornó un evento válido');
  }
  // --- FIN FUNCIÓN CORREGIDA ---

  Future<List<Evento>> listar() async {
    final res = await _http.getJson('/api/agenda');

    if (res.statusCode >= 400) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body);

    if (data is List) {
      return data
          .map<Evento>(
            (e) => Evento.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    }

    // Fallback por si acaso
    return <Evento>[];
  }
}
