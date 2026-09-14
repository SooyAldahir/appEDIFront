/// Tipos de miembro tal y como se guardan en `EDI.Miembros_Familia.tipo_miembro`.
///
/// Esta clase es la ÚNICA fuente de verdad para clasificar, ordenar y etiquetar
/// a los integrantes de una familia. Si se agrega un rol nuevo en la base de
/// datos, basta con registrarlo aquí para que todas las pantallas (detalle
/// admin, "Mi familia" y los reportes PDF) lo muestren en su lugar correcto.
class MemberType {
  static const String padre = 'PADRE';
  static const String madre = 'MADRE';
  static const String hijoSanguineo = 'HIJO';
  static const String alumnoEdi = 'ALUMNO_ASIGNADO';
  static const String tioEdi = 'TIO_EDI';
  static const String desconocido = 'OTRO';

  /// Orden jerárquico en el que deben aparecer los roles en cualquier listado.
  static const List<String> ordenJerarquico = <String>[
    padre,
    madre,
    hijoSanguineo,
    alumnoEdi,
    tioEdi,
    desconocido,
  ];

  /// Sinónimos aceptados. La clave ya viene normalizada (mayúsculas, sin
  /// acentos y con guiones bajos), el valor es el tipo canónico.
  static const Map<String, String> _sinonimos = <String, String>{
    'PADRE': padre,
    'PAPA': padre,
    'PAPA_EDI': padre,
    'PAPAEDI': padre,
    'MADRE': madre,
    'MAMA': madre,
    'MAMA_EDI': madre,
    'MAMAEDI': madre,
    'HIJO': hijoSanguineo,
    'HIJA': hijoSanguineo,
    'HIJO_SANGUINEO': hijoSanguineo,
    'HIJOSANGUINEO': hijoSanguineo,
    'ALUMNO_ASIGNADO': alumnoEdi,
    'ALUMNOASIGNADO': alumnoEdi,
    'ALUMNO': alumnoEdi,
    'ESTUDIANTE': alumnoEdi,
    'HIJO_EDI': alumnoEdi,
    'HIJOEDI': alumnoEdi,
    'TIO_EDI': tioEdi,
    'TIOEDI': tioEdi,
    'TIO': tioEdi,
    'TIA': tioEdi,
    'TIA_EDI': tioEdi,
  };

  static const Map<String, String> _acentos = <String, String>{
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'Ü': 'U',
    'Ñ': 'N',
  };

  /// Convierte cualquier variante recibida del backend al tipo canónico.
  /// Nunca adivina: lo que no reconoce cae en [desconocido] en vez de
  /// colarse en la lista de hijos.
  static String normalize(dynamic raw) {
    if (raw == null) return desconocido;
    var s = raw.toString().trim().toUpperCase();
    if (s.isEmpty) return desconocido;
    _acentos.forEach((acentuada, plana) => s = s.replaceAll(acentuada, plana));
    s = s.replaceAll(RegExp(r'[\s\-]+'), '_');
    return _sinonimos[s] ?? desconocido;
  }

  /// Posición del rol dentro de [ordenJerarquico]. Sirve para ordenar listas.
  static int rank(String tipo) {
    final i = ordenJerarquico.indexOf(normalize(tipo));
    return i == -1 ? ordenJerarquico.length : i;
  }

  /// Etiqueta individual, la que se muestra debajo del nombre de la persona.
  static String label(String tipo) {
    switch (normalize(tipo)) {
      case padre:
        return 'Papá EDI';
      case madre:
        return 'Mamá EDI';
      case hijoSanguineo:
        return 'Hijo sanguíneo';
      case alumnoEdi:
        return 'Hijo EDI';
      case tioEdi:
        return 'Tío EDI';
      default:
        return 'Integrante';
    }
  }

  /// Título de la sección que agrupa a ese rol.
  static String sectionTitle(String tipo) {
    switch (normalize(tipo)) {
      case padre:
      case madre:
        return 'Padres de familia';
      case hijoSanguineo:
        return 'Hijos sanguíneos';
      case alumnoEdi:
        return 'Hijos EDI';
      case tioEdi:
        return 'Tíos EDI';
      default:
        return 'Otros integrantes';
    }
  }

  /// Sección de los niños del hogar, que no viven en `Miembros_Familia`.
  static const String tituloHijosHogar = 'Hijos del hogar (sin cuenta)';
}

/// Hijo del hogar sin cuenta en el sistema (niños pequeños).
class HogarChild {
  final int? idHijo;
  final String nombre;
  final String apellido;
  final String? fechaNacimiento; // formateada "dd/MM/yyyy"

  String get fullName => '$nombre $apellido'.trim();

  const HogarChild({
    this.idHijo,
    required this.nombre,
    required this.apellido,
    this.fechaNacimiento,
  });

  factory HogarChild.fromJson(Map<String, dynamic> j) {
    String? parseDate(dynamic d) {
      if (d == null) return null;
      final s = d.toString().trim();
      if (s.isEmpty) return null;
      try {
        final dt = DateTime.parse(s);
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {
        return s;
      }
    }

    return HogarChild(
      idHijo: (j['id_hijo'] as num?)?.toInt(),
      nombre: (j['nombre'] ?? '').toString(),
      apellido: (j['apellido'] ?? '').toString(),
      fechaNacimiento: parseDate(j['fecha_nacimiento']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class FamilyMember {
  final int idMiembro;
  final int idUsuario;
  final String fullName;

  /// Tipo canónico (ver [MemberType]). Siempre normalizado.
  final String tipoMiembro;

  final int? matricula;
  final String? telefono;
  final String? carrera;
  final String? fechaNacimiento;
  final String? fotoPerfil;

  /// `true` cuando la persona todavía no tiene cuenta vinculada (papá o mamá
  /// capturados a mano en una familia creada manualmente). No se puede abrir
  /// su perfil ni iniciar chat con ella.
  final bool pendiente;

  FamilyMember({
    required this.idMiembro,
    required this.idUsuario,
    required this.fullName,
    // `dynamic` a propósito: el backend puede mandar null o una variante del
    // nombre del rol; MemberType.normalize se encarga de resolverlo.
    required dynamic tipoMiembro,
    this.matricula,
    this.telefono,
    this.carrera,
    this.fechaNacimiento,
    this.fotoPerfil,
    this.pendiente = false,
  }) : tipoMiembro = MemberType.normalize(tipoMiembro);

  /// Etiqueta lista para mostrar: "Hijo EDI", "Tío EDI", "Hijo sanguíneo"...
  String get roleLabel => MemberType.label(tipoMiembro);

  /// Orden jerárquico del rol, para ordenar listados mixtos.
  int get roleRank => MemberType.rank(tipoMiembro);

  /// `true` si se puede navegar a su perfil / abrir chat.
  bool get tieneCuenta => !pendiente && idUsuario != 0;

  factory FamilyMember.fromJson(Map<String, dynamic> j) {
    final nombre = j['nombre'] ?? '';
    final apellido = j['apellido'] ?? '';

    String? parseDate(dynamic d) {
      if (d == null) return null;
      try {
        final date = DateTime.parse(d.toString());
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (e) {
        return d.toString();
      }
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim());
    }

    return FamilyMember(
      idMiembro: parseInt(j['id_miembro']) ?? 0,
      idUsuario: parseInt(j['id_usuario']) ?? 0,
      fullName: '$nombre $apellido'.trim(),
      // Sin default a 'HIJO': un tipo ausente o desconocido no debe disfrazarse
      // de hijo sanguíneo. MemberType lo mandará a "Otros integrantes".
      tipoMiembro: j['tipo_miembro'] ?? j['tipoMiembro'],
      matricula: parseInt(j['matricula']),
      telefono: j['telefono']?.toString(),
      carrera: j['carrera']?.toString(),
      fechaNacimiento: parseDate(j['fecha_nacimiento']),
      fotoPerfil: j['foto_perfil_url']?.toString(),
    );
  }
}

class Family {
  final int? id;

  final String familyName;
  final String? fatherName;
  final String? motherName;
  final String? residencia;
  final String? direccion;
  final String? descripcion;
  final String? fotoPortadaUrl;
  final String? fotoPerfilUrl;
  final bool cerradaManualmente;
  /// Alumnos EDI asignados (`tipo_miembro = 'ALUMNO_ASIGNADO'`).
  final List<FamilyMember> assignedStudents;

  /// Hijos sanguíneos con cuenta (`tipo_miembro = 'HIJO'`).
  final List<FamilyMember> householdChildren;

  /// Niños del hogar sin cuenta (tabla `EDI.Hijos_Hogar`).
  final List<HogarChild> hogarChildren;

  /// Tíos EDI (`tipo_miembro = 'TIO_EDI'`). NO son hijos EDI y no cuentan
  /// para el límite de alumnos por familia.
  final List<FamilyMember> uncles;

  /// Filas PADRE / MADRE de `Miembros_Familia`. Normalmente duplican a
  /// papa_id / mama_id; se usan para completar la sección de padres.
  final List<FamilyMember> parentMembers;

  /// Miembros con un `tipo_miembro` que la app no reconoce. Se muestran en
  /// "Otros integrantes" en vez de desaparecer o contaminar otra sección.
  final List<FamilyMember> otherMembers;

  final int? fatherEmployeeId;
  final int? motherEmployeeId;
  final String? papaNumEmpleado;
  final String? mamaNumEmpleado;
  final String? papaTelefono;
  final String? mamaTelefono;
  final String? papaFotoPerfilUrl;
  final String? mamaFotoPerfilUrl;
  final String? papaFechaNacimiento;
  final String? mamaFechaNacimiento;

  /// Nombres capturados a mano cuando la familia se creó manualmente y el
  /// papá / mamá todavía no se registra en la app.
  final String? papaNombrePendiente;
  final String? mamaNombrePendiente;

  String get residence => residencia ?? '';

  // ── Agrupaciones listas para la UI ─────────────────────────────────────────

  /// Padres de la familia en orden (papá, luego mamá), combinando la fila de
  /// `Familias_EDI` (que trae foto, teléfono y cumpleaños) con las filas
  /// PADRE/MADRE de `Miembros_Familia` que no estén ya representadas.
  List<FamilyMember> get parents {
    final out = <FamilyMember>[];
    final vistos = <int>{};

    FamilyMember? desdeMiembros(int id) {
      for (final p in parentMembers) {
        if (p.idUsuario == id) return p;
      }
      return null;
    }

    void agregarTitular({
      required int? id,
      required String? nombre,
      required String? nombrePendiente,
      required String tipo,
      required String? telefono,
      required String? foto,
      required String? fechaNacimiento,
    }) {
      if (id != null && id != 0) {
        final existente = desdeMiembros(id);
        final display = (nombre ?? '').trim();
        out.add(
          FamilyMember(
            idMiembro: existente?.idMiembro ?? 0,
            idUsuario: id,
            fullName: display.isNotEmpty
                ? display
                : (existente?.fullName ?? MemberType.label(tipo)),
            tipoMiembro: tipo,
            telefono: telefono ?? existente?.telefono,
            fotoPerfil: foto ?? existente?.fotoPerfil,
            fechaNacimiento: fechaNacimiento ?? existente?.fechaNacimiento,
          ),
        );
        vistos.add(id);
        return;
      }

      // Sin usuario vinculado: mostramos el nombre pendiente si existe.
      final pend = (nombrePendiente ?? '').trim();
      if (pend.isNotEmpty) {
        out.add(
          FamilyMember(
            idMiembro: 0,
            idUsuario: 0,
            fullName: pend,
            tipoMiembro: tipo,
            pendiente: true,
          ),
        );
      }
    }

    agregarTitular(
      id: fatherEmployeeId,
      nombre: fatherName,
      nombrePendiente: papaNombrePendiente,
      tipo: MemberType.padre,
      telefono: papaTelefono,
      foto: papaFotoPerfilUrl,
      fechaNacimiento: papaFechaNacimiento,
    );
    agregarTitular(
      id: motherEmployeeId,
      nombre: motherName,
      nombrePendiente: mamaNombrePendiente,
      tipo: MemberType.madre,
      telefono: mamaTelefono,
      foto: mamaFotoPerfilUrl,
      fechaNacimiento: mamaFechaNacimiento,
    );

    for (final p in parentMembers) {
      if (p.idUsuario != 0 && vistos.add(p.idUsuario)) out.add(p);
    }
    return out;
  }

  /// Todos los miembros con cuenta, ordenados por jerarquía de rol y luego
  /// por nombre. Útil para listados planos (reportes, búsquedas).
  List<FamilyMember> get allMembersOrdered {
    final all = <FamilyMember>[
      ...parents,
      ...householdChildren,
      ...assignedStudents,
      ...uncles,
      ...otherMembers,
    ];
    all.sort((a, b) {
      final r = a.roleRank.compareTo(b.roleRank);
      return r != 0
          ? r
          : a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return all;
  }

  /// Total real de integrantes: padres + hijos sanguíneos + niños del hogar
  /// + hijos EDI + tíos EDI.
  int get totalIntegrantes =>
      parents.length +
      householdChildren.length +
      hogarChildren.length +
      assignedStudents.length +
      uncles.length +
      otherMembers.length;

  const Family({
    required this.id,
    required this.familyName,
    this.fatherName,
    this.motherName,
    this.residencia,
    this.direccion,
    this.descripcion,
    this.fotoPortadaUrl,
    this.fotoPerfilUrl,
    this.cerradaManualmente = false,
    this.assignedStudents = const [],
    this.householdChildren = const [],
    this.hogarChildren = const [],
    this.uncles = const [],
    this.parentMembers = const [],
    this.otherMembers = const [],
    this.fatherEmployeeId,
    this.motherEmployeeId,
    this.papaNumEmpleado,
    this.mamaNumEmpleado,
    this.papaTelefono,
    this.mamaTelefono,
    this.papaFotoPerfilUrl,
    this.mamaFotoPerfilUrl,
    this.papaFechaNacimiento,
    this.mamaFechaNacimiento,
    this.papaNombrePendiente,
    this.mamaNombrePendiente,
  });

  factory Family.fromJson(Map<String, dynamic> j) {
    String? _parseDate(dynamic d) {
      if (d == null) return null;
      try {
        final date = DateTime.parse(d.toString());
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (_) {
        return d.toString();
      }
    }

    String? _normalizeRes(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      final up = s.toUpperCase();
      if (up.startsWith('INT')) return 'Interna';
      if (up.startsWith('EXT')) return 'Externa';
      return s;
    }

    bool asBool(dynamic value) {
      return value == true ||
          value == 1 ||
          value?.toString() == '1' ||
          value?.toString().toLowerCase() == 'true';
    }

    final List<FamilyMember> householdChildren = [];
    final List<FamilyMember> assignedStudents = [];
    final List<FamilyMember> uncles = [];
    final List<FamilyMember> parentMembers = [];
    final List<FamilyMember> otherMembers = [];

    if (j['miembros'] is List) {
      for (final miembro in (j['miembros'] as List)) {
        if (miembro is! Map) continue;
        final familyMember = FamilyMember.fromJson(
          Map<String, dynamic>.from(miembro),
        );
        // Cada rol va EXCLUSIVAMENTE a su propia lista. Nada de mezclar
        // tíos con alumnos ni alumnos con hijos sanguíneos.
        switch (familyMember.tipoMiembro) {
          case MemberType.padre:
          case MemberType.madre:
            parentMembers.add(familyMember);
            break;
          case MemberType.hijoSanguineo:
            householdChildren.add(familyMember);
            break;
          case MemberType.alumnoEdi:
            assignedStudents.add(familyMember);
            break;
          case MemberType.tioEdi:
            uncles.add(familyMember);
            break;
          default:
            otherMembers.add(familyMember);
        }
      }
    }

    // Orden alfabético estable dentro de cada grupo.
    int porNombre(FamilyMember a, FamilyMember b) =>
        a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    householdChildren.sort(porNombre);
    assignedStudents.sort(porNombre);
    uncles.sort(porNombre);
    otherMembers.sort(porNombre);

    final List<HogarChild> hogarChildren = [];
    if (j['hijos_hogar'] is List) {
      for (final h in (j['hijos_hogar'] as List)) {
        if (h is Map<String, dynamic>) {
          hogarChildren.add(HogarChild.fromJson(h));
        }
      }
    }

    return Family(
      id: (j['id_familia'] ?? j['FamiliaID'] ?? j['id']) as int?,
      familyName:
          (j['nombre_familia'] ?? j['Nombre_Familia'] ?? j['nombre'] ?? '')
              .toString(),
      fatherName:
          (j['papa_nombre'] ??
                  j['Padre'] ??
                  j['padre'] ??
                  j['fatherName'] ??
                  j['nombre_padre'])
              ?.toString(),
      motherName:
          (j['mama_nombre'] ??
                  j['Madre'] ??
                  j['madre'] ??
                  j['motherName'] ??
                  j['nombre_madre'])
              ?.toString(),
      residencia: _normalizeRes(j['residencia'] ?? j['Residencia']),
      direccion: (j['direccion'] ?? j['Direccion'])?.toString(),
      descripcion: (j['descripcion'] ?? j['Descripcion'])?.toString(),
      fotoPortadaUrl: j['foto_portada_url']?.toString(),
      fotoPerfilUrl: j['foto_perfil_url']?.toString(),
      cerradaManualmente: asBool(j['cerrada_manualmente']),
      householdChildren: householdChildren,
      assignedStudents: assignedStudents,
      hogarChildren: hogarChildren,
      uncles: uncles,
      parentMembers: parentMembers,
      otherMembers: otherMembers,
      fatherEmployeeId:
          (j['papa_id'] ??
                  j['Papa_id'] ??
                  j['PapaId'] ??
                  j['father_employee_id'])
              as int?,
      motherEmployeeId:
          (j['mama_id'] ??
                  j['Mama_id'] ??
                  j['MamaId'] ??
                  j['mother_employee_id'])
              as int?,
      papaNumEmpleado: j['papa_num_empleado']?.toString(),
      mamaNumEmpleado: j['mama_num_empleado']?.toString(),
      papaTelefono: j['papa_telefono']?.toString(),
      mamaTelefono: j['mama_telefono']?.toString(),
      papaFotoPerfilUrl: j['papa_foto_perfil_url']?.toString(),
      mamaFotoPerfilUrl: j['mama_foto_perfil_url']?.toString(),
      papaFechaNacimiento: _parseDate(j['papa_fecha_nacimiento']),
      mamaFechaNacimiento: _parseDate(j['mama_fecha_nacimiento']),
      papaNombrePendiente: _nombrePendiente(
        j['papa_nombre_pendiente'],
        j['papa_apellido_pendiente'],
      ),
      mamaNombrePendiente: _nombrePendiente(
        j['mama_nombre_pendiente'],
        j['mama_apellido_pendiente'],
      ),
    );
  }

  static String? _nombrePendiente(dynamic nombre, dynamic apellido) {
    final full = '${nombre ?? ''} ${apellido ?? ''}'.trim();
    return full.isEmpty ? null : full;
  }

  Map<String, dynamic> toJson() => {
    'id_familia': id,
    'nombre_familia': familyName,
    'padre': fatherName,
    'madre': motherName,
    'residencia': residencia,
    'direccion': direccion,
    'cerrada_manualmente': cerradaManualmente,

    'papa_id': fatherEmployeeId,
    'mama_id': motherEmployeeId,
  };

  Family copyWith({
    int? id,
    String? familyName,
    String? fatherName,
    String? motherName,
    String? residencia,
    String? direccion,
    String? descripcion,
    String? fotoPortadaUrl,
    String? fotoPerfilUrl,
    bool? cerradaManualmente,
    List<FamilyMember>? assignedStudents,
    List<FamilyMember>? householdChildren,
    List<HogarChild>? hogarChildren,
    List<FamilyMember>? uncles,
    List<FamilyMember>? parentMembers,
    List<FamilyMember>? otherMembers,
    int? fatherEmployeeId,
    int? motherEmployeeId,
    String? papaNumEmpleado,
    String? mamaNumEmpleado,
  }) {
    return Family(
      id: id ?? this.id,
      familyName: familyName ?? this.familyName,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      residencia: residencia ?? this.residencia,
      direccion: direccion ?? this.direccion,
      descripcion: descripcion ?? this.descripcion,
      fotoPortadaUrl: fotoPortadaUrl ?? this.fotoPortadaUrl,
      fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
      cerradaManualmente: cerradaManualmente ?? this.cerradaManualmente,
      assignedStudents: assignedStudents ?? this.assignedStudents,
      householdChildren: householdChildren ?? this.householdChildren,
      hogarChildren: hogarChildren ?? this.hogarChildren,
      uncles: uncles ?? this.uncles,
      parentMembers: parentMembers ?? this.parentMembers,
      otherMembers: otherMembers ?? this.otherMembers,
      fatherEmployeeId: fatherEmployeeId ?? this.fatherEmployeeId,
      motherEmployeeId: motherEmployeeId ?? this.motherEmployeeId,
      papaNumEmpleado: papaNumEmpleado ?? this.papaNumEmpleado,
      mamaNumEmpleado: mamaNumEmpleado ?? this.mamaNumEmpleado,
      papaTelefono: papaTelefono,
      mamaTelefono: mamaTelefono,
      papaFotoPerfilUrl: papaFotoPerfilUrl,
      mamaFotoPerfilUrl: mamaFotoPerfilUrl,
      papaFechaNacimiento: papaFechaNacimiento,
      mamaFechaNacimiento: mamaFechaNacimiento,
      papaNombrePendiente: papaNombrePendiente,
      mamaNombrePendiente: mamaNombrePendiente,
    );
  }
}
