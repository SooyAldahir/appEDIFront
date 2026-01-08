import 'dart:convert';
import '../core/api_client_http.dart';

// --- MODELO ---
class Evento {
  // Usamos 'idActividad' para ser consistentes con la BD y el código del detalle
  final int idActividad;
  final String titulo;
  final String? descripcion;
  final DateTime fechaEvento;
  final String? horaEvento;
  final String? imagen;
  final String estadoPublicacion;
  // 👇 CAMPO NUEVO
  final int? diasAnticipacion;

  Evento({
    required this.idActividad,
    required this.titulo,
    this.descripcion,
    required this.fechaEvento,
    this.horaEvento,
    this.imagen,
    required this.estadoPublicacion,
    this.diasAnticipacion,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      // 👇 MAPEO ROBUSTO:
      // Busca 'id_actividad' (lista) o 'id_evento' (feed) o usa 0 por defecto
      idActividad: json['id_actividad'] ?? json['id_evento'] ?? 0,

      titulo: json['titulo'] ?? '',
      descripcion:
          json['descripcion'] ?? json['mensaje'], // Soporta alias del feed
      // Manejo seguro de fechas
      fechaEvento: json['fecha_evento'] != null
          ? DateTime.parse(json['fecha_evento'].toString())
          : DateTime.now(),

      horaEvento: json['hora_evento'],
      imagen: json['imagen'],
      estadoPublicacion: json['estado_publicacion'] ?? 'Publicada',

      // 👇 LECTURA DEL NUEVO CAMPO
      diasAnticipacion: json['dias_anticipacion'],
    );
  }
}

// --- API SERVICE ---
class EventosApi {
  final ApiHttp _http = ApiHttp();

  // --- FUNCIÓN CREAR (MEJORADA) ---
  Future<Map<String, dynamic>> crearEvento({
    required String titulo,
    required DateTime fecha,
    String? hora,
    String? descripcion,
    String? imagenUrl,
    int diasAnticipacion = 3, // 👇 Agregamos esto con valor default
  }) async {
    final payload = {
      "titulo": titulo,
      "descripcion": descripcion,
      "fecha_evento": fecha
          .toIso8601String(), // Enviamos ISO completo, el backend lo maneja
      "hora_evento": hora,
      "imagen": imagenUrl,
      "estado_publicacion": "Publicada",
      "dias_anticipacion": diasAnticipacion, // 👇 Lo enviamos al backend
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

  // --- FUNCIÓN LISTAR ---
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

    return <Evento>[];
  }
}
