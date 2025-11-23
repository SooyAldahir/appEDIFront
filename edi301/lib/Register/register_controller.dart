import 'dart:convert';
import 'package:flutter/material.dart';
// --- AÑADIDOS ---
import 'package:http/http.dart' as http;
import 'package:edi301/models/institutional_user.dart';
import 'package:edi301/core/api_client_http.dart'; // <-- Para la API local
// --- FIN ---

class RegisterController {
  BuildContext? context;
  final loading = ValueNotifier<bool>(false);

  // --- Controladores (sin cambios) ---
  final documentoCtrl = TextEditingController();
  final emailVerificationCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final verificationCodeCtrl = TextEditingController();

  // --- Manejadores de Estado (sin cambios) ---
  final registrationStep = ValueNotifier<int>(0);
  final foundUser = ValueNotifier<InstitutionalUser?>(null);

  // --- URL de la API Institucional (sin cambios) ---
  final String _institutionalApiUrl =
      'https://ulv-api.apps.isdapps.uk/api/datos/';

  Future? init(BuildContext context) {
    this.context = context;
    return null;
  }

  void dispose() {
    documentoCtrl.dispose();
    emailVerificationCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    verificationCodeCtrl.dispose();
    registrationStep.dispose();
    foundUser.dispose();
    loading.dispose();
  }

  void goToLoginPage() {
    if (context != null) {
      Navigator.pushReplacementNamed(context!, 'login');
    }
  }

  // --- FUNCIÓN 'searchByDocument' ACTUALIZADA ---
  /// PASO 0: Busca al usuario en la API Institucional
  Future<void> searchByDocument() async {
    final document = documentoCtrl.text.trim();
    if (document.isEmpty) {
      _snack('Ingresa tu matrícula o número de empleado.');
      return;
    }

    loading.value = true;
    try {
      final uri = Uri.parse('$_institutionalApiUrl$document');
      final response = await http.get(uri);

      if (response.statusCode == 404) {
        throw Exception('No se encontró ningún usuario con ese documento.');
      }
      if (response.statusCode >= 400) {
        throw Exception(
          'Error al conectar con el servidor: ${response.statusCode}',
        );
      }

      // --- INICIO DE LÓGICA DE PARSEO (MODIFICADA) ---
      final Map<String, dynamic> body = jsonDecode(response.body);

      // 1. Determina si la clave es 'Data' (Alumno) o 'data' (Empleado)
      final Map<String, dynamic> data;
      if (body.containsKey('Data')) {
        data = body['Data'] as Map<String, dynamic>;
      } else if (body.containsKey('data')) {
        data = body['data'] as Map<String, dynamic>;
      } else {
        throw Exception(
          'Respuesta de API inválida. Falta el objeto "Data" o "data".',
        );
      }

      final String userType = (data['type'] ?? '').toString().toUpperCase();

      Map<String, dynamic>? userData;

      // 2. Extrae los datos de 'student' o 'employee'
      if (userType == 'ALUMNO' &&
          data['student'] is List &&
          (data['student'] as List).isNotEmpty) {
        userData = (data['student'] as List).first;
      } else if (userType == 'EMPLEADO' &&
          data['employee'] is List &&
          (data['employee'] as List).isNotEmpty) {
        userData = (data['employee'] as List).first;
      }

      if (userData != null) {
        // 3. Pasa los datos al modelo para que los parsee
        // El modelo (que actualizaremos) sabrá cómo leer 'NOMBRES' vs 'NOMBRE'
        foundUser.value = InstitutionalUser.fromJson(userData);

        // --- ¡ÉXITO! Avanzamos al siguiente paso ---
        registrationStep.value = 1;
      } else {
        throw Exception(
          'No se encontraron datos de alumno o empleado válidos.',
        );
      }
      // --- FIN DE LÓGICA DE PARSEO ---
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      loading.value = false;
    }
  }
  // --- FIN DE ACTUALIZACIÓN ---

  /// PASO 1: Verifica que el correo ingresado coincida (sin cambios)
  void verifyEmail() {
    final typedEmail = emailVerificationCtrl.text.trim().toLowerCase();
    // El 'foundUser' ya tiene el correo correcto gracias al modelo
    final realEmail = foundUser.value?.correoInstitucional.toLowerCase();

    if (typedEmail != realEmail) {
      _snack('El correo electrónico no coincide. Inténtalo de nuevo.');
      return;
    }

    // --- ¡ÉXITO! Siguiente paso: Enviar el código ---
    _snack('¡Correos coinciden! Enviando código...', isError: false);
    _sendVerificationCode(realEmail!);
  }

  /// PASO 2: (Simulado) Envía el código de verificación (sin cambios)
  Future<void> _sendVerificationCode(String email) async {
    loading.value = true;
    await Future.delayed(const Duration(seconds: 1)); // Simula la llamada API
    print("--- SIMULACIÓN: Código enviado a $email ---");
    loading.value = false;
    registrationStep.value = 2; // Avanza a la pantalla de "Ingresar Código"
  }

  /// PASO 2 (Continuación): Verifica el código ingresado (sin cambios)
  void verifyCode() {
    final code = verificationCodeCtrl.text.trim();
    if (code != '1234') {
      // <-- Código quemado temporalmente
      _snack('Código incorrecto.');
      return;
    }
    _snack('Código correcto', isError: false);
    registrationStep.value = 3; // Avanza a la pantalla de "Crear Contraseña"
  }

  /// PASO 3: Validación de Contraseña (sin cambios)
  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false; // Mayúscula
    if (!password.contains(RegExp(r'[0-9]'))) return false; // Número
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')))
      return false; // Caracter especial
    return true;
  }

  /// PASO 4: Registro Final (en tu base de datos local) (sin cambios)
  Future<void> register() async {
    final password = passCtrl.text;
    final confirm = confirmPassCtrl.text;
    final user = foundUser.value;

    if (user == null) {
      _snack('Error fatal: Se perdieron los datos del usuario.');
      registrationStep.value = 0;
      return;
    }

    if (password != confirm) {
      _snack('Las contraseñas no coinciden.');
      return;
    }
    if (!_validatePassword(password)) {
      _snack('La contraseña no cumple los requisitos de seguridad.');
      return;
    }

    loading.value = true;

    int idRol;
    if (user.numEmpleado != null) {
      // Es empleado
      if (user.sexo == 'F') {
        idRol = 3; // MadreEDI (Como tú indicaste)
      } else {
        idRol = 2; // PadreEDI (Como tú indicaste)
      }
    } else {
      // Es alumno
      idRol = 4; // Alumno Asignado (HijoEDI)
    }

    // --- INICIO DE CORRECCIÓN ---
    // Revertimos los parches. Ahora enviamos los datos tal cual
    // vienen del modelo. (residencia y direccion pueden ser null).
    // También normalizamos 'INTERNO' a 'Interna' si es que existe.

    String? residenciaNormalizada = user.residencia;
    if (residenciaNormalizada != null &&
        residenciaNormalizada.toUpperCase() == 'INTERNO') {
      residenciaNormalizada = 'Interna';
    } else if (residenciaNormalizada != null &&
        residenciaNormalizada.toUpperCase() == 'EXTERNO') {
      residenciaNormalizada = 'Externa';
    }

    try {
      final ApiHttp _http = ApiHttp();

      final payload = {
        'nombre': user.nombre,
        'apellido': user.apellidos,
        'correo': user.correoInstitucional,
        'contrasena': password,
        'tipo_usuario': user.numEmpleado != null ? 'EMPLEADO' : 'ALUMNO',
        'id_rol': idRol,
        'matricula': user.matricula,
        'num_empleado': user.numEmpleado,
        'residencia': residenciaNormalizada, // <-- Envía 'Externa' o 'null'
        'direccion': user.direccion, // <-- Envía la dirección real o 'null'
      };
      // --- FIN DE CORRECCIÓN ---

      final res = await _http.postJson('/api/usuarios', data: payload);

      // ¡Éxito FINAL!
      _snack('Registro exitoso. Ahora puedes iniciar sesión.', isError: false);
      goToLoginPage();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      loading.value = false;
    }
  }

  void _snack(String msg, {bool isError = true}) {
    if (context != null && context!.mounted) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
