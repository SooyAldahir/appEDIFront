class UserModel {
  final int idUsuario;
  final String nombre;
  final String apellido;
  final String correo;
  final String tipoUsuario;
  final int idRol;
  final String nombreRol;
  final String sessionToken;

  UserModel({
    required this.idUsuario,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.tipoUsuario,
    required this.idRol,
    required this.nombreRol,
    required this.sessionToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    idUsuario: json['id_usuario'],
    nombre: json['nombre'] ?? '',
    apellido: json['apellido'] ?? '',
    correo: json['correo'] ?? '',
    tipoUsuario: json['tipo_usuario'] ?? '',
    idRol: json['id_rol'],
    nombreRol: json['nombre_rol'] ?? '',
    sessionToken: json['session_token'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id_usuario': idUsuario,
    'nombre': nombre,
    'apellido': apellido,
    'correo': correo,
    'tipo_usuario': tipoUsuario,
    'id_rol': idRol,
    'nombre_rol': nombreRol,
    'session_token': sessionToken,
  };
}
