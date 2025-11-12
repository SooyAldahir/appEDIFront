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
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] ?? j['IdUsuario'],
    email: j['email'] ?? j['E_mail'],
    name: j['name'] ?? j['Nombre'],
    lastName: j['lastName'] ?? j['Apellido'],
    tipo: j['tipo'] ?? j['TipoUsuario'],
    matricula: j['matricula'] ?? j['Matricula'],
    numEmpleado: j['numEmpleado'] ?? j['NumEmpleado'],
    activo: (j['activo'] ?? j['es_Activo']) == true,
    admin: (j['admin'] ?? j['es_Admin']) == true,
    token: j['session_token'],
  );
}
