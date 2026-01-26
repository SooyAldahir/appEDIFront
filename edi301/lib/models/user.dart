class User {
  final int id;
  final String email;
  final String name;
  final String lastName;
  final String tipo;
  final int? matricula;
  final int? numEmpleado;
  final bool activo;
  final bool admin;
  final String? token;
  final String? photoUrl;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.lastName,
    required this.tipo,
    this.matricula,
    this.numEmpleado,
    required this.activo,
    required this.admin,
    this.token,
    this.photoUrl,
  });

  String? get urlFotoPerfil => photoUrl;

  int get idUsuario => id;

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] ?? j['IdUsuario'] ?? j['id_usuario'] ?? 0,
    email: j['email'] ?? j['E_mail'] ?? j['e_mail'] ?? '',
    name: j['name'] ?? j['Nombre'] ?? j['nombre'] ?? '',
    lastName: j['lastName'] ?? j['Apellido'] ?? j['apellido'] ?? '',
    tipo: j['tipo'] ?? j['TipoUsuario'] ?? j['tipo_usuario'] ?? '',

    matricula: j['matricula'] ?? j['Matricula'],
    numEmpleado: j['numEmpleado'] ?? j['NumEmpleado'] ?? j['num_empleado'],

    activo:
        (j['activo'] ?? j['es_Activo'] ?? j['activo']) == true ||
        (j['activo'] == 1) ||
        (j['es_Activo'] == 1),

    admin: (j['admin'] ?? j['es_Admin']) == true,
    token: j['session_token'],

    photoUrl: j['url_foto_perfil'] ?? j['url_imagen'] ?? j['FotoPerfil'],
  );
}
