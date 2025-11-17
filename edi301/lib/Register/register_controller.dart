import 'dart:convert';
import 'package:edi301/core/api_client_http.dart';
import 'package:edi301/models/institutional_user.dart';
import 'package:flutter/material.dart';
// --- AÑADIDOS ---
import 'package:http/http.dart' as http;
// --- FIN ---

class RegisterController {
  BuildContext? context;
  final loading = ValueNotifier<bool>(false);

  // --- 1. Controladores simplificados ---
  final documentoCtrl = TextEditingController(); // Para Matrícula o NumEmpleado
  final emailVerificationCtrl =
      TextEditingController(); // Para verificar el correo
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final verificationCodeCtrl =
      TextEditingController(); // Para el código de 4 dígitos

  // --- 2. Manejadores de Estado ---
  // 0 = Ingresar Documento
  // 1 = Verificar Correo (y mostrar datos)
  // 2 = Ingresar Código
  // 3 = Crear Contraseña
  final registrationStep = ValueNotifier<int>(0);

  // Guardará los datos del usuario de la ULV
  final foundUser = ValueNotifier<InstitutionalUser?>(null);

  // --- 3. URL de la API Institucional ---
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

      final data = jsonDecode(response.body);

      // La API devuelve una lista, tomamos el primer resultado
      if (data is List && data.isNotEmpty) {
        final userData = data[0] as Map<String, dynamic>;
        foundUser.value = InstitutionalUser.fromJson(userData);

        // --- ¡ÉXITO! Avanzamos al siguiente paso ---
        registrationStep.value = 1;
      } else {
        throw Exception('No se encontró ningún usuario con ese documento.');
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      loading.value = false;
    }
  }

  /// PASO 1: Verifica que el correo ingresado coincida
  void verifyEmail() {
    final typedEmail = emailVerificationCtrl.text.trim().toLowerCase();
    final realEmail = foundUser.value?.correoInstitucional.toLowerCase();

    if (typedEmail != realEmail) {
      _snack('El correo electrónico no coincide. Inténtalo de nuevo.');
      return;
    }

    // --- ¡ÉXITO! Siguiente paso: Enviar el código ---
    _snack('¡Correos coinciden! Enviando código...', isError: false);
    _sendVerificationCode(realEmail!);
  }

  /// PASO 2: (Simulado) Envía el código de verificación
  Future<void> _sendVerificationCode(String email) async {
    loading.value = true;
    // ---
    // AQUÍ IRÍA LA LÓGICA PARA LLAMAR A TU BACKEND QUE ENVÍA EL CORREO
    // (Por ahora, lo simulamos y saltamos al paso 2)
    // ---
    await Future.delayed(const Duration(seconds: 1)); // Simula la llamada API

    print("--- SIMULACIÓN: Código enviado a $email ---");

    loading.value = false;
    registrationStep.value = 2; // Avanza a la pantalla de "Ingresar Código"
  }

  /// PASO 2 (Continuación): Verifica el código ingresado
  void verifyCode() {
    final code = verificationCodeCtrl.text.trim();

    // ---
    // AQUÍ IRÍA LA LÓGICA PARA LLAMAR A TU BACKEND QUE VALIDA EL CÓDIGO
    // (Por ahora, simulamos que '1234' es el código)
    // ---

    if (code != '1234') {
      // <-- Código quemado temporalmente
      _snack('Código incorrecto.');
      return;
    }

    // --- ¡ÉXITO! Siguiente paso: Crear contraseña ---
    _snack('Código correcto', isError: false);
    registrationStep.value = 3; // Avanza a la pantalla de "Crear Contraseña"
  }

  /// PASO 3: Validación de Contraseña
  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false; // Mayúscula
    if (!password.contains(RegExp(r'[0-9]'))) return false; // Número
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')))
      return false; // Caracter especial
    return true;
  }

  /// PASO 4: Registro Final (en tu base de datos local)
  Future<void> register() async {
    final password = passCtrl.text;
    final confirm = confirmPassCtrl.text;
    final user = foundUser.value;

    if (user == null) {
      _snack('Error fatal: Se perdieron los datos del usuario.');
      registrationStep.value = 0;
      return;
    }

    // Validaciones
    if (password != confirm) {
      _snack('Las contraseñas no coinciden.');
      return;
    }
    if (!_validatePassword(password)) {
      _snack('La contraseña no cumple los requisitos de seguridad.');
      return;
    }

    loading.value = true;

    // ---
    // ¡AQUÍ ES DONDE ASIGNAMOS LOS ROLES!
    // Pregunta: ¿Qué rol va para 'Matricula'? ¿HijoEDI (3) o Alumno Asignado (4)?
    // Usaré '4' (Alumno Asignado) por ahora.
    // ---

    int idRol;
    if (user.numEmpleado != null) {
      // Es empleado
      if (user.sexo == 'F') {
        idRol = 5; // MadreEDI
      } else {
        idRol = 6; // PadreEDI
      }
    } else {
      // Es alumno
      idRol = 4; // Alumno Asignado (HijoEDI)
    }

    try {
      // ESTA ES LA API LOCAL QUE USABAS ANTES
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
        'residencia': user.residencia, // Campo extra
      };

      final res = await _http.postJson('/api/usuarios', data: payload);

      if (res.statusCode >= 400) {
        String errorMsg = 'Error ${res.statusCode}';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey('error')) {
            errorMsg = body['error'];
          }
        } catch (_) {
          errorMsg = res.body;
        }
        throw Exception(errorMsg);
      }

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
