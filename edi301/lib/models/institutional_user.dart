// lib/models/institutional_user.dart
import 'dart:convert';

// Modelo para la respuesta de la API de ULV
// https://ulv-api.apps.isdapps.uk/api/datos/
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
  });

  factory InstitutionalUser.fromJson(Map<String, dynamic> json) {
    // Limpiamos los valores nulos o 'null'
    String? cleanString(dynamic value) {
      if (value == null || value.toString() == 'null') return null;
      return value.toString();
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      return int.tryParse(value.toString());
    }

    return InstitutionalUser(
      // Asumiendo los nombres de las claves del JSON
      matricula: parseInt(json['Matricula'] ?? json['matricula']),
      nombre: json['Nombre'] ?? json['nombre'] ?? 'Sin Nombre',
      apellidos: json['Apellidos'] ?? json['apellidos'] ?? 'Sin Apellidos',
      correoInstitucional:
          json['Correo Institucional'] ?? json['correoInstitucional'] ?? '',
      residencia: cleanString(json['Residencia'] ?? json['residencia']),
      nivelEducativo: cleanString(
        json['Nivel educativo'] ?? json['nivelEducativo'],
      ),
      campo: cleanString(json['Campo'] ?? json['campo']),
      leNombreEscuelaOficial: cleanString(
        json['LeNombreEscuelaOficial'] ?? json['leNombreEscuelaOficial'],
      ),
      sexo: cleanString(json['Sexo'] ?? json['sexo']), // 'M' o 'F'
      numEmpleado: parseInt(json['NumEmpleado'] ?? json['numEmpleado']),
    );
  }

  // Función para ocultar el correo
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
