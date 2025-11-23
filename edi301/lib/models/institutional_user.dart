// lib/models/institutional_user.dart
import 'dart:convert';

class InstitutionalUser {
  final int? matricula;
  final String nombre;
  final String apellidos;
  final String correoInstitucional;
  final String? residencia;
  final String? nivelEducativo;
  final String? campo; // Asumo que es 'campus'
  final String? leNombreEscuelaOficial;
  final String? sexo; // ¡IMPORTANTE para los roles de Padre/Madre!
  final int? numEmpleado; // Si es empleado
  final String? direccion; // <-- 1. AÑADIDO

  InstitutionalUser({
    this.matricula,
    required this.nombre,
    required this.apellidos,
    required this.correoInstitucional,
    this.residencia,
    this.nivelEducativo,
    this.campo,
    this.leNombreEscuelaOficial,
    this.sexo,
    this.numEmpleado,
    this.direccion, // <-- 2. AÑADIDO
  });

  factory InstitutionalUser.fromJson(Map<String, dynamic> json) {
    String? cleanString(dynamic value) {
      if (value == null ||
          value.toString() == 'null' ||
          value.toString().isEmpty)
        return null;
      return value.toString();
    }

    int? parseInt(dynamic value) {
      if (value == null || value.toString().isEmpty) return null;
      return int.tryParse(value.toString());
    }

    final bool esEmpleado = json.containsKey('NOMBRES');

    return InstitutionalUser(
      matricula: esEmpleado ? null : parseInt(json['MATRICULA']),
      numEmpleado: esEmpleado ? parseInt(json['MATRICULA']) : null,
      nombre: json['NOMBRES'] ?? json['NOMBRE'] ?? 'Sin Nombre',
      apellidos: json['APELLIDOS'] ?? 'Sin Apellidos',
      correoInstitucional:
          json['EMAIl_INSTITUCIONAL'] ?? json['CORREO_INSTITUCIONAL'] ?? '',
      residencia: cleanString(json['RESIDENCIA']),
      nivelEducativo: cleanString(json['NIVEL_EDUCATIVO']),
      campo: cleanString(json['CAMPO'] ?? json['CAMPUS']),
      leNombreEscuelaOficial: cleanString(
        json['LeNombreEscuelaOficial'] ?? json['DEPARTAMENTO'],
      ),
      sexo: cleanString(json['SEXO']),
      direccion: cleanString(
        json['DIRECCION'],
      ), // <-- 3. AÑADIDO (Lee 'DIRECCION' de la API)
    );
  }

  // ... (función correoOculto sin cambios) ...
  String get correoOculto {
    if (correoInstitucional.isEmpty || !correoInstitucional.contains('@')) {
      return 'correo-no-valido@...';
    }
    final parts = correoInstitucional.split('@');
    final user = parts[0];
    final domain = parts[1];
    if (user.length <= 3) {
      return '${user[0]}***@$domain';
    }
    return '${user.substring(0, 3)}***@$domain';
  }
}
