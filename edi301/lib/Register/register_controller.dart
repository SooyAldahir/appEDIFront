import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:edi301/models/institutional_user.dart';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/services/otp_service.dart'; // <-- 1. IMPORTA EL SERVICIO

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

  final String _institutionalApiUrl =
      'https://ulv-api.apps.isdapps.uk/api/datos/';

  // --- 2. INSTANCIA EL SERVICIO ---
  final OtpService _otpService = OtpService();

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

  // --- PASO 0: Busca al usuario (SIN CAMBIOS) ---
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

      final Map<String, dynamic> body = jsonDecode(response.body);

      final Map<String, dynamic> data;
      if (body.containsKey('Data')) {
        data = body['Data'] as Map<String, dynamic>;
      } else if (body.containsKey('data')) {
        data = body['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Respuesta de API inválida.');
      }

      final String userType = (data['type'] ?? '').toString().toUpperCase();
      Map<String, dynamic>? userData;

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
        foundUser.value = InstitutionalUser.fromJson(userData);
        registrationStep.value = 1;
      } else {
        throw Exception('No se encontraron datos válidos.');
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      loading.value = false;
    }
  }

  // --- PASO 1: Verifica Email (SIN CAMBIOS) ---
  void verifyEmail() {
    final typedEmail = emailVerificationCtrl.text.trim().toLowerCase();
    final realEmail = foundUser.value?.correoInstitucional.toLowerCase();

    if (typedEmail != realEmail) {
      _snack('El correo electrónico no coincide. Inténtalo de nuevo.');
      return;
    }

    _snack('¡Correos coinciden! Enviando código...', isError: false);
    _sendVerificationCode(realEmail!);
  }

  // --- PASO 2: Enviar Código (ACTUALIZADO CON API REAL) ---
  Future<void> _sendVerificationCode(String email) async {
    loading.value = true;
    try {
      // Llamamos al servicio real
      await _otpService.sendOtp(email);

      _snack('Código enviado a tu correo.', isError: false);
      registrationStep.value = 2; // Avanza si todo salió bien
    } catch (e) {
      _snack(
        'Error al enviar correo: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      loading.value = false;
    }
  }

  // --- PASO 2 (Cont): Validar Código (ACTUALIZADO CON API REAL) ---
  Future<void> verifyCode() async {
    // <-- Ahora es async
    final code = verificationCodeCtrl.text.trim();
    final email = foundUser.value?.correoInstitucional;

    if (code.length != 4) {
      // Asumiendo que el OTP son 4 dígitos
      _snack('Ingresa el código completo.');
      return;
    }

    loading.value = true; // Mostramos carga mientras valida

    try {
      // Llamamos al servicio real
      final isValid = await _otpService.verifyOtp(email!, code);

      if (isValid) {
        _snack('Código correcto', isError: false);
        registrationStep.value = 3;
      } else {
        _snack('El código es incorrecto o ha expirado.');
      }
    } catch (e) {
      _snack('Error al validar: $e');
    } finally {
      loading.value = false;
    }
  }

  // --- PASO 3: Validación Contraseña (SIN CAMBIOS) ---
  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  // --- PASO 4: Registro Final (VERSIÓN BLINDADA) ---
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

    // 1. Lógica de Roles (Tu configuración correcta)
    int idRol;
    if (user.numEmpleado != null) {
      if (user.sexo == 'F') {
        idRol = 3;
      } else {
        idRol = 2;
      }
    } else {
      idRol = 4;
    }

    // 2. Lógica de Residencia y Dirección (BLINDAJE)
    String residenciaEnvio = 'Externa'; // Valor por defecto seguro
    String? direccionEnvio = user.direccion;

    // Normalizamos si viene de la API
    if (user.residencia != null) {
      if (user.residencia!.toUpperCase() == 'INTERNO') {
        residenciaEnvio = 'Interna';
        direccionEnvio = null; // Internos no llevan dirección
      } else {
        residenciaEnvio = 'Externa';
      }
    }

    // Si es Externa y no tiene dirección (ej. Empleado), ponemos una por defecto
    // para evitar el error de la base de datos.
    if (residenciaEnvio == 'Externa' &&
        (direccionEnvio == null || direccionEnvio.isEmpty)) {
      direccionEnvio = 'Dirección no proporcionada por la institución';
    }

    String? fechaNacimientoEnvio = user.fechaNacimiento;

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
        'residencia': residenciaEnvio,
        'direccion': direccionEnvio,

        // --- NUEVOS CAMPOS AGREGADOS ---
        'telefono':
            user.celular, // Mapeamos 'celular' del modelo a 'telefono' de la BD
        'fecha_nacimiento': fechaNacimientoEnvio,
        'carrera':
            user.leNombreEscuelaOficial, // Mapeamos Escuela/Depto a 'carrera'
        // ------------------------------
      };

      final res = await _http.postJson('/api/usuarios', data: payload);
      if (res.statusCode >= 400) {
        String errorMsg = 'Error ${res.statusCode}';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey('error')) {
            errorMsg = body['error'];
          } else if (body is Map && body.containsKey('message')) {
            errorMsg = body['message'];
          }
        } catch (_) {
          errorMsg = res.body;
        }
        // Limpiamos mensaje técnico de SQL si aparece
        if (errorMsg.contains('CK_Usuarios'))
          errorMsg = 'Error de validación en base de datos.';
        if (errorMsg.contains('Violation of UNIQUE KEY'))
          errorMsg = 'El usuario ya está registrado.';

        throw Exception(errorMsg);
      }

      // ¡Éxito FINAL!
      _snack('Registro exitoso. Ahora puedes iniciar sesión.', isError: false);
      goToLoginPage();
    } catch (e) {
      print('❌ Error en registro: $e');
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
