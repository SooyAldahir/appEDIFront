// Roles definidos en la base de datos
class DbRoles {
  static const admin = 'Admin';
  static const papaEDI = 'PapaEDI';
  static const mamaEDI = 'MamaEDI';
  static const hijoEDI = 'HijoEDI';
  static const hijoSanguineo = 'HijoSanguineo';
}

// Grupos lógicos para facilitar la lógica de permisos
class AppRoleGroups {
  static const List<String> padres = [DbRoles.papaEDI, DbRoles.mamaEDI];

  static const List<String> hijos = [DbRoles.hijoEDI, DbRoles.hijoSanguineo];

  // Roles que PUEDEN editar foto/perfil (Admin y Padres)
  static const List<String> canEditProfile = [DbRoles.admin, ...padres];

  // Roles que PUEDEN navegar en la app (Todos, excepto quizás visitantes)
  static const List<String> canAccessApp = [DbRoles.admin, ...padres, ...hijos];
}
