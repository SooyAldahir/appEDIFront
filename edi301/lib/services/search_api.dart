// lib/services/search_api.dart
import 'dart:convert';
import '../core/api_client_http.dart';

class UserMini {
  final int id;
  final String nombre;
  final String apellido;
  final String tipo;
  final int? matricula;
  final int? numEmpleado;
  final String? email;
  final String? fotoPerfil;

  UserMini({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.tipo,
    this.matricula,
    this.numEmpleado,
    this.email,
    this.fotoPerfil,
  });

  factory UserMini.fromJson(Map<String, dynamic> j) => UserMini(
    id: (j['IdUsuario'] ?? j['id'] ?? j['id_usuario'] ?? 0) as int,
    nombre: (j['Nombre'] ?? j['nombre'] ?? '') as String,
    apellido: (j['Apellido'] ?? j['apellido'] ?? '') as String,
    tipo: (j['TipoUsuario'] ?? j['tipo_usuario'] ?? '') as String,
    matricula: _toIntOrNull(j['Matricula'] ?? j['matricula']),
    numEmpleado: _toIntOrNull(j['NumEmpleado'] ?? j['num_empleado']),
    email: (j['E_mail'] ?? j['correo'])?.toString(),
    fotoPerfil: (j['FotoPerfil'] ?? j['foto_perfil'] ?? j['fotoPerfil'])
        ?.toString(),
  );
}

class FamilyMini {
  final int id;
  final String nombre;
  final String? residencia;
  final String? biografia;

  FamilyMini({
    required this.id,
    required this.nombre,
    this.residencia,
    this.biografia,
  });

  factory FamilyMini.fromJson(Map<String, dynamic> j) => FamilyMini(
    id: (j['FamiliaID'] ?? j['id_familia'] ?? j['id'] ?? 0) as int,
    nombre:
        (j['Nombre_Familia'] ?? j['nombre_familia'] ?? j['nombre'] ?? '')
            as String,
    residencia: (j['Residencia'] ?? j['residencia'])?.toString(),
    biografia: (j['Biografia'] ?? j['biografia'])?.toString(),
  );
}

class SearchResult {
  final List<UserMini> alumnos;
  final List<UserMini> empleados;
  final List<FamilyMini> familias;
  final List<UserMini> externos;

  SearchResult({
    required this.alumnos,
    required this.empleados,
    required this.familias,
    required this.externos,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
    alumnos: _parseUsers(j['alumnos']),
    empleados: _parseUsers(j['empleados']),
    familias: _parseFamilies(j['familias']),
    externos: _parseUsers(j['externos']),
  );
}

List<UserMini> _parseUsers(dynamic v) {
  if (v is List) {
    return v
        .map((e) => UserMini.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return const [];
}

List<FamilyMini> _parseFamilies(dynamic v) {
  if (v is List) {
    return v
        .map((e) => FamilyMini.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return const [];
}

/// El servidor respondio 429: demasiadas busquedas en poco tiempo.
///
/// Se distingue del resto de errores a proposito. Un 429 no significa "no hay
/// resultados", significa "pregunta otra vez en un momento", y la pantalla
/// tiene que decir eso en lugar de quedarse en blanco.
class BusquedaSaturada implements Exception {
  const BusquedaSaturada();
  @override
  String toString() => 'Demasiadas busquedas seguidas';
}

class SearchApi {
  final ApiHttp _http = ApiHttp();

  Future<dynamic> _safeGet(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _http.getJson(path, query: query);
      // El 429 no se traga: es el unico error que la pantalla necesita
      // distinguir, porque la respuesta correcta es esperar, no rendirse.
      if (res.statusCode == 429) throw const BusquedaSaturada();
      if (res.statusCode >= 400) return const [];
      return jsonDecode(res.body);
    } on BusquedaSaturada {
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  /// Dos peticiones por busqueda, no cuatro.
  ///
  /// Antes eran: tres a /api/usuarios (identicas salvo por `tipo`) mas una o
  /// dos de familias. Con el buscador disparando en cada tecla, escribir un
  /// apellido gastaba decenas de peticiones y chocaba con el limite del
  /// servidor, que responde 429 y deja la pantalla en blanco.
  Future<SearchResult> searchAll(String input) async {
    final q = input.trim();
    if (q.length < 2) {
      return SearchResult(
        alumnos: const [],
        empleados: const [],
        familias: const [],
        externos: const [],
      );
    }

    final isNumeric = RegExp(r'^\d+$').hasMatch(q);

    // Los tres tipos en una sola llamada: el backend acepta la lista separada
    // por comas y devuelve TipoUsuario en cada fila, que es con lo que se
    // reparten abajo.
    final usuariosF = _safeGet(
      '/api/usuarios',
      query: {'tipo': 'ALUMNO,EMPLEADO,EXTERNO', 'q': q},
    );

    // Para un numero se hacian dos llamadas, una con `matricula` y otra con
    // `numEmpleado`. Son la misma: el backend compara el valor contra las dos
    // columnas en la misma consulta, asi que la segunda devolvia exactamente
    // lo mismo que la primera.
    final familiasF = isNumeric
        ? _safeGet(
            '/api/usuarios/familias/by-doc/search',
            query: {'matricula': q},
          )
        : _safeGet('/api/familias/search', query: {'name': q});

    final resps = await Future.wait<dynamic>([usuariosF, familiasF]);

    List<dynamic> ensureList(dynamic d) {
      if (d == null) return const [];
      if (d is List) return d;
      if (d is Map && d.containsKey('data') && d['data'] is List) {
        return d['data'] as List;
      }
      if (d is Map && d.containsKey('rows') && d['rows'] is List) {
        return d['rows'] as List;
      }
      if (d is Map && d.values.length == 1 && d.values.first is List) {
        return List.from(d.values.first as List);
      }
      return const [];
    }

    final usuarios = ensureList(resps[0])
        .map((e) => UserMini.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    List<UserMini> soloDe(String tipo) =>
        usuarios.where((u) => u.tipo.toUpperCase() == tipo).toList();

    final familias = ensureList(resps[1])
        .map((e) => FamilyMini.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SearchResult(
      alumnos: soloDe('ALUMNO'),
      empleados: soloDe('EMPLEADO'),
      familias: familias,
      externos: soloDe('EXTERNO'),
    );
  }
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}
