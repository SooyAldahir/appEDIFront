// lib/src/pages/Search/family_mapper.dart
import 'package:edi301/models/family_model.dart';

class FamilyMapper {
  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Mapea un registro del backend a nuestro modelo Family unificado.
  static Family fromBackend(Map<String, dynamic> j) {
    // residencia: normalizamos a 'Interna' | 'Externa'
    final resRaw = _str(j['residencia'] ?? j['Residencia']);
    final residence = resRaw == null
        ? null
        : (resRaw.toUpperCase().startsWith('INT')
              ? 'Interna'
              : (resRaw.toUpperCase().startsWith('EXT') ? 'Externa' : resRaw));

    return Family(
      id: _int(j['id_familia'] ?? j['FamiliaID'] ?? j['id']),
      familyName:
          _str(j['nombre_familia'] ?? j['Nombre_Familia'] ?? j['nombre']) ?? '',
      // <- ahora tomamos los nombres que vienen del JOIN
      fatherName: _str(j['papa_nombre'] ?? j['Padre'] ?? j['fatherName']),
      motherName: _str(j['mama_nombre'] ?? j['Madre'] ?? j['motherName']),
      // ids de empleados (varias variantes por compatibilidad)
      fatherEmployeeId: _int(
        j['papa_id'] ?? j['Papa_id'] ?? j['PapaId'] ?? j['father_employee_id'],
      ),
      motherEmployeeId: _int(
        j['mama_id'] ?? j['Mama_id'] ?? j['MamaId'] ?? j['mother_employee_id'],
      ),
      // 👇 OJO: propiedad en el modelo debe llamarse 'residence' (como usas en la UI)
      residencia: residence,
      direccion: _str(j['direccion'] ?? j['Direccion']),
      // listas locales para la UI
      assignedStudents: const [],
      householdChildren: const [],
    );
  }
}
