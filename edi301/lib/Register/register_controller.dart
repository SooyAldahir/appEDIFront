import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:edi301/core/api_client_http.dart';

class RegisterController {
  BuildContext? context;
  final ApiHttp _http = ApiHttp();
  final loading = ValueNotifier<bool>(false);

  // Controladores para todos los campos requeridos por la API
  final nombreCtrl = TextEditingController();
  final apellidoCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final matriculaCtrl = TextEditingController();
  final numEmpleadoCtrl = TextEditingController();

  // 'ALUMNO' o 'EMPLEADO'
  final tipoUsuario = ValueNotifier<String>('ALUMNO');

  Future? init(BuildContext context) {
    this.context = context;
    return null;
  }

  void dispose() {
    nombreCtrl.dispose();
    apellidoCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    matriculaCtrl.dispose();
    numEmpleadoCtrl.dispose();
    tipoUsuario.dispose();
    loading.dispose();
  }

  void goToLoginPage() {
    if (context != null) {
      Navigator.pushReplacementNamed(context!, 'login');
    }
  }

  Future<void> register() async {
    if (context == null) return;
    final tipo = tipoUsuario.value;

    // --- 1. Validación de campos ---
    final nombre = nombreCtrl.text.trim();
    final apellido = apellidoCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();
    final confirm = confirmPassCtrl.text.trim();
    final matricula = int.tryParse(matriculaCtrl.text.trim());
    final numEmpleado = int.tryParse(numEmpleadoCtrl.text.trim());

    if (nombre.isEmpty ||
        apellido.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      _snack('Por favor, llena todos los campos.');
      return;
    }
    if (password != confirm) {
      _snack('Las contraseñas no coinciden.');
      return;
    }
    if (tipo == 'ALUMNO' && matricula == null) {
      _snack('La matrícula es requerida para alumnos.');
      return;
    }
    if (tipo == 'EMPLEADO' && numEmpleado == null) {
      _snack('El número de empleado es requerido.');
      return;
    }
    // La validación de @ulv.edu.mx la hará el backend

    loading.value = true;

    try {
      // --- 2. Construir el Payload ---
      // ASUNCIÓN: Usamos 'id_rol = 2' como rol por defecto para
      // 'HijoEDI' o un rol de usuario estándar.
      // El rol '1' suele ser 'Admin'.
      final payload = {
        'nombre': nombre,
        'apellido': apellido,
        'correo': email,
        'contrasena': password,
        'tipo_usuario': tipo,
        'id_rol': 4, // <-- Asignamos un rol de usuario estándar
        'matricula': tipo == 'ALUMNO' ? matricula : null,
        'num_empleado': tipo == 'EMPLEADO' ? numEmpleado : null,
      };

      // --- 3. Llamar a la API correcta ---
      final res = await _http.postJson('/api/usuarios', data: payload);

      if (res.statusCode >= 400) {
        // Intentar leer el error específico del backend
        String errorMsg = 'Error ${res.statusCode}';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body.containsKey('error')) {
            errorMsg =
                body['error']; // ej: "El correo debe ser institucional..."
          }
        } catch (_) {
          errorMsg = res.body;
        }
        throw Exception(errorMsg);
      }

      // ¡Éxito!
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
        ),
      );
    }
  }
}
