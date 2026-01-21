// Roles definidos en la base de datos
class DbRoles {
  static const admin = 'Admin';
  static const papaEDI = 'PapaEDI';
  static const mamaEDI = 'MamaEDI';
  static const hijoEDI = 'HijoEDI';
  static const hijoSanguineo = 'HijoSanguineo';
}

class AppRoleGroups {
  static const List<String> padres = [DbRoles.papaEDI, DbRoles.mamaEDI];

  static const List<String> hijos = [DbRoles.hijoEDI, DbRoles.hijoSanguineo];

  static const List<String> canEditProfile = [DbRoles.admin, ...padres];

  static const List<String> canAccessApp = [DbRoles.admin, ...padres, ...hijos];
}
