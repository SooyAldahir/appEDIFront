import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/api_client_http.dart';

class Evento {
  final int idActividad;
  final String titulo;
  final String? descripcion;
  final DateTime fechaEvento;
  final String? horaEvento;
  final String? imagen; // URL relativa que viene del backend
  final String estadoPublicacion;
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
      idActividad: json['id_actividad'] ?? json['id_evento'] ?? 0,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? json['mensaje'],
      fechaEvento: json['fecha_evento'] != null
          ? DateTime.parse(json['fecha_evento'].toString())
          : DateTime.now(),
      horaEvento: json['hora_evento'],
      imagen: json['imagen'],
      estadoPublicacion: json['estado_publicacion'] ?? 'Publicada',
      diasAnticipacion: json['dias_anticipacion'],
    );
  }
}

class EventosApi {
  // Usamos tu cliente Singleton que ya maneja tokens y base URL
  final ApiHttp _http = ApiHttp();

  /// Crea o actualiza un evento enviando imagen (si existe)
  Future<bool> guardarEvento({
    int? id, // Si es null => CREAR, Si tiene valor => ACTUALIZAR
    required String titulo,
    required DateTime fecha,
    String? hora,
    String? descripcion,
    File? imagenFile, // Archivo físico seleccionado del celular
    int diasAnticipacion = 3,
  }) async {
    try {
      // 1. Definir URL y Método
      final String endpoint = id == null ? '/api/agenda' : '/api/agenda/$id';
      final String method = id == null ? 'POST' : 'PUT';

      // 2. Preparar campos de texto (Todo debe ser String)
      final Map<String, String> fields = {
        'titulo': titulo,
        'descripcion': descripcion ?? '',
        'fecha_evento': fecha.toIso8601String(),
        'hora_evento': hora ?? '',
        'dias_anticipacion': diasAnticipacion.toString(),
        'estado_publicacion': 'Publicada',
      };

      // 3. Preparar Archivo (si existe)
      List<http.MultipartFile>? files;
      if (imagenFile != null) {
        files = [
          await http.MultipartFile.fromPath(
            'imagen', // Debe coincidir con backend: req.files.imagen
            imagenFile.path,
          ),
        ];
      }

      // 4. Usar tu método 'multipart' de ApiHttp
      //    Este método ya inyecta el Token automáticamente.
      final streamedResponse = await _http.multipart(
        endpoint,
        method: method,
        fields: fields,
        files: files,
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        print('Error Agenda (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      print('Excepción en guardarEvento: $e');
      return false;
    }
  }

  /// Listar eventos (Se mantiene igual, solo validando tipos)
  Future<List<Evento>> listar() async {
    try {
      final res = await _http.getJson('/api/agenda');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data
              .map<Evento>((e) => Evento.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (e) {
      print('Error listando eventos: $e');
    }
    return [];
  }
}
