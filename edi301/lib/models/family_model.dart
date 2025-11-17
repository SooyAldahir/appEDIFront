// lib/models/family_model.dart
import 'package:flutter/foundation.dart';

// 1. Clase auxiliar para los miembros
class FamilyMember {
  final int idMiembro; // ID de la relación (Miembros_Familia.id_miembro)
  final int idUsuario; // ID del usuario (Usuarios.id_usuario)
  final String fullName;
  final String tipoMiembro; // 'HIJO' o 'ALUMNO_ASIGNADO'

  final int? matricula;
  final String? telefono;
  final String? carrera;
  final String? fechaNacimiento;

  FamilyMember({
    required this.idMiembro,
    required this.idUsuario,
    required this.fullName,
    required this.tipoMiembro,
    this.matricula,
    this.telefono,
    this.carrera,
    this.fechaNacimiento,
  });

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

    return FamilyMember(
      idMiembro: (j['id_miembro'] ?? 0) as int,
      idUsuario: (j['id_usuario'] ?? 0) as int,
      fullName: '$nombre $apellido'.trim(),
      tipoMiembro: (j['tipo_miembro'] ?? 'HIJO') as String,
      matricula: (j['matricula'] as num?)?.toInt(),
      telefono: j['telefono']?.toString(),
      carrera: j['carrera']?.toString(),
      fechaNacimiento: parseDate(j['fecha_nacimiento']),
    );
  }
}

// 2. Clase principal de la Familia
class Family {
  // PK unificada
  final int? id; // mapea id_familia / FamiliaID / id

  // Campos principales
  final String familyName;
  final String? fatherName;
  final String? motherName;
  final String? residencia; // 'INTERNA' | 'EXTERNA'
  final String? direccion;
  final String? descripcion;

  // --- Listas actualizadas ---
  final List<FamilyMember> assignedStudents; // "Alumnos asignados"
  final List<FamilyMember> householdChildren; // "Hijos en casa"

  // IDs de empleados (si algún día los quieres poblar)
  final int? fatherEmployeeId;
  final int? motherEmployeeId;

  final String? papaNumEmpleado;
  final String? mamaNumEmpleado;
  // Getter legacy para no romper referencias: f.residence -> f.residencia
  String get residence => residencia ?? '';

  // --- Constructor actualizado ---
  const Family({
    required this.id,
    required this.familyName,
    this.fatherName,
    this.motherName,
    this.residencia,
    this.direccion,
    this.descripcion,
    this.assignedStudents = const [],
    this.householdChildren = const [],
    this.fatherEmployeeId,
    this.motherEmployeeId,
    this.papaNumEmpleado,
    this.mamaNumEmpleado,
  });

  // --- Factory FromJson actualizado ---
  factory Family.fromJson(Map<String, dynamic> j) {
    // normaliza residencia a 'Interna' / 'Externa' si es posible
    String? _normalizeRes(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      final up = s.toUpperCase();
      if (up.startsWith('INT')) return 'Interna';
      if (up.startsWith('EXT')) return 'Externa';
      return s;
    }

    // --- LÓGICA NUEVA PARA PROCESAR MIEMBROS ---
    final List<FamilyMember> householdChildren = [];
    final List<FamilyMember> assignedStudents = [];

    if (j['miembros'] is List) {
      for (final miembro in (j['miembros'] as List)) {
        if (miembro is Map<String, dynamic>) {
          // Usar el factory de la helper class
          final familyMember = FamilyMember.fromJson(miembro);

          // LÓGICA DE SEPARACIÓN
          if (familyMember.tipoMiembro == 'HIJO') {
            householdChildren.add(familyMember);
          } else if (familyMember.tipoMiembro == 'ALUMNO_ASIGNADO') {
            assignedStudents.add(familyMember);
          }
        }
      }
    }
    // --- FIN DE LÓGICA NUEVA ---

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

      // Usa las nuevas listas que acabamos de crear
      householdChildren: householdChildren,
      assignedStudents: assignedStudents,

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
    );
  }

  Map<String, dynamic> toJson() => {
    'id_familia': id,
    'nombre_familia': familyName,
    'padre': fatherName,
    'madre': motherName,
    'residencia': residencia,
    'direccion': direccion,
    'papa_id': fatherEmployeeId,
    'mama_id': motherEmployeeId,
  };

  // --- copyWith actualizado ---
  Family copyWith({
    int? id,
    String? familyName,
    String? fatherName,
    String? motherName,
    String? residencia,
    String? direccion,
    String? descripcion,
    List<FamilyMember>? assignedStudents,
    List<FamilyMember>? householdChildren,
    int? fatherEmployeeId,
    int? motherEmployeeId,
    String? papaNumEmpleado, // <-- Añadir
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
      assignedStudents: assignedStudents ?? this.assignedStudents,
      householdChildren: householdChildren ?? this.householdChildren,
      fatherEmployeeId: fatherEmployeeId ?? this.fatherEmployeeId,
      motherEmployeeId: motherEmployeeId ?? this.motherEmployeeId,
      papaNumEmpleado: papaNumEmpleado ?? this.papaNumEmpleado,
      mamaNumEmpleado: mamaNumEmpleado ?? this.mamaNumEmpleado,
    );
  }
}
