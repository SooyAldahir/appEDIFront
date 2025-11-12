class UserMini {
  final int id;
  final String nombre;
  final String apellido;
  final String tipo;
  final int? matricula;
  final int? numEmpleado;

  UserMini({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.tipo,
    this.matricula,
    this.numEmpleado,
  });

  factory UserMini.fromJson(Map<String, dynamic> j) => UserMini(
    id: j['id_usuario'] ?? 0,
    nombre: j['nombre'] ?? '',
    apellido: j['apellido'] ?? '',
    tipo: j['tipo_usuario'] ?? '',
    matricula: j['matricula'],
    numEmpleado: j['num_empleado'],
  );
}

class FamilyMini {
  final int id;
  final String nombre;
  final String? residencia;

  FamilyMini({required this.id, required this.nombre, this.residencia});

  factory FamilyMini.fromJson(Map<String, dynamic> j) => FamilyMini(
    id: j['id_familia'] ?? 0,
    nombre: j['nombre_familia'] ?? '',
    residencia: j['residencia'],
  );
}

class SearchResponse {
  final List<UserMini> alumnos;
  final List<UserMini> empleados;
  final List<FamilyMini> familias;

  SearchResponse({
    required this.alumnos,
    required this.empleados,
    required this.familias,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final alumnos =
        (json['alumnos'] as List?)?.map((e) => UserMini.fromJson(e)).toList() ??
        [];
    final empleados =
        (json['empleados'] as List?)
            ?.map((e) => UserMini.fromJson(e))
            .toList() ??
        [];
    final familias =
        (json['familias'] as List?)
            ?.map((e) => FamilyMini.fromJson(e))
            .toList() ??
        [];
    return SearchResponse(
      alumnos: alumnos,
      empleados: empleados,
      familias: familias,
    );
  }
}
