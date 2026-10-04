import 'dart:convert';

import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/core/api_error.dart';

/// Alumnos en periodo de prueba: los que todavía no tienen matrícula ni
/// correo institucional.
///
/// Salvo `promoverme`, todo esto es solo para Admin; el backend responde 403
/// a cualquier otro rol.
class AlumnosPruebaApi {
  final _http = ApiHttp();

  /// Lista de seguimiento, con los más atrasados primero.
  Future<ListaPrueba> lista({bool incluirInactivos = false}) async {
    final r = await _http.getJson(
      '/api/alumnos-prueba',
      query: {if (incluirInactivos) 'inactivos': '1'},
    );
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
    return ListaPrueba.fromJson(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  /// Cuentas a prueba que comparten nombre con una ya matriculada: la persona
  /// probablemente se registró de nuevo en vez de promover la que tenía.
  Future<List<Map<String, dynamic>>> duplicados() async {
    final r = await _http.getJson('/api/alumnos-prueba/duplicados');
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
    final d = jsonDecode(r.body);
    if (d is! List) return const [];
    return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> crear({
    required String nombre,
    required String apellido,
    required String correoPersonal,
    required String contrasena,
    String? telefono,
    String? carrera,
    String? residencia,
    String? fechaNacimiento,
  }) async {
    final r = await _http.postJson('/api/alumnos-prueba', data: {
      'nombre': nombre,
      'apellido': apellido,
      'correo_personal': correoPersonal,
      'contrasena': contrasena,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      if (carrera != null && carrera.isNotEmpty) 'carrera': carrera,
      if (residencia != null && residencia.isNotEmpty) 'residencia': residencia,
      if (fechaNacimiento != null && fechaNacimiento.isNotEmpty)
        'fecha_nacimiento': fechaNacimiento,
    });
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
  }

  /// Promoción hecha por un administrador. No lleva código: la garantía es
  /// que hay alguien de la oficina mirando el documento.
  Future<void> promoverComoAdmin({
    required int idUsuario,
    required int matricula,
    required String correoInstitucional,
    String? carrera,
  }) async {
    final r = await _http.patchJson(
      '/api/alumnos-prueba/$idUsuario/promover',
      data: {
        'matricula': matricula,
        'correo_institucional': correoInstitucional,
        if (carrera != null && carrera.isNotEmpty) 'carrera': carrera,
      },
    );
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
  }

  /// Promoción hecha por el propio alumno.
  ///
  /// El código llega al correo institucional que está declarando: verificarlo
  /// es lo que demuestra que ese correo es suyo y no el de un compañero. Sin
  /// eso, cualquiera con cuenta a prueba podría reclamar el correo de otro.
  Future<void> promoverme({
    required int matricula,
    required String correoInstitucional,
    required String codigo,
    String? carrera,
  }) async {
    final r = await _http.postJson('/api/alumnos-prueba/me/promover', data: {
      'matricula': matricula,
      'correo_institucional': correoInstitucional,
      'codigo': codigo,
      if (carrera != null && carrera.isNotEmpty) 'carrera': carrera,
    });
    if (r.statusCode >= 400) throw Exception(parseHttpError(r));
  }
}

class ListaPrueba {
  final int diasPeriodo;
  final int total;
  final int vencidos;
  final List<AlumnoPrueba> alumnos;

  ListaPrueba({
    required this.diasPeriodo,
    required this.total,
    required this.vencidos,
    required this.alumnos,
  });

  factory ListaPrueba.fromJson(Map<String, dynamic> j) => ListaPrueba(
        diasPeriodo: (j['dias_periodo'] as num?)?.toInt() ?? 90,
        total: (j['total'] as num?)?.toInt() ?? 0,
        vencidos: (j['vencidos'] as num?)?.toInt() ?? 0,
        alumnos: (j['alumnos'] is List)
            ? (j['alumnos'] as List)
                .map((e) => AlumnoPrueba.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );
}

class AlumnoPrueba {
  final int id;
  final String nombre;
  final String apellido;
  final String? correoPersonal;
  final String? telefono;
  final String? nombreFamilia;
  final int dias;
  final bool vencido;
  final bool activo;

  AlumnoPrueba({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.dias,
    required this.vencido,
    required this.activo,
    this.correoPersonal,
    this.telefono,
    this.nombreFamilia,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();

  factory AlumnoPrueba.fromJson(Map<String, dynamic> j) => AlumnoPrueba(
        id: (j['id_usuario'] as num?)?.toInt() ?? 0,
        nombre: (j['nombre'] ?? '').toString(),
        apellido: (j['apellido'] ?? '').toString(),
        correoPersonal: j['correo_personal']?.toString(),
        telefono: j['telefono']?.toString(),
        nombreFamilia: j['nombre_familia']?.toString(),
        dias: (j['dias'] as num?)?.toInt() ?? 0,
        vencido: (j['vencido'] as num?)?.toInt() == 1 || j['vencido'] == true,
        activo: j['activo'] == true || j['activo'] == 1,
      );
}
