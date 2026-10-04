import 'package:edi301/core/api_error.dart';
import 'package:edi301/services/users_api.dart';
import 'package:flutter/material.dart';

/// Recuperación de contraseña.
///
/// El OTP ya no se toca desde aquí. Antes esta pantalla llamaba directamente
/// al servicio de verificación (con sus credenciales dentro del APK), decidía
/// ella misma si el código era correcto y luego le pedía al servidor cambiar
/// la contraseña. El servidor nunca se enteraba de que hubiera un código, así
/// que bastaba con conocer un correo institucional para quedarse con la cuenta.
///
/// Ahora: la app pide "manda un código", y al guardar manda código y
/// contraseña juntos. El servidor verifica y cambia en la misma operación.
/// Por eso el paso del código ya no lo comprueba nadie en el teléfono: la
/// comprobación de verdad pasa al guardar.
class ForgotPasswordController {
  final UsersApi _usersApi = UsersApi();

  final emailCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  final step = ValueNotifier<int>(0);
  final loading = ValueNotifier<bool>(false);

  void dispose() {
    emailCtrl.dispose();
    otpCtrl.dispose();
    passCtrl.dispose();
    step.dispose();
    loading.dispose();
  }

  // =========================
  // VALIDACIÓN DE CONTRASEÑA
  // =========================
  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    if (!RegExp(r'[!"#\$%&/\(\)=\?\.,@]').hasMatch(password)) return false;
    return true;
  }

  String? _passwordError(String password) {
    if (password.length < 8) {
      return 'Debe tener al menos 8 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Debe contener al menos una mayúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Debe contener al menos un número';
    }
    if (!RegExp(r'[!"#\$%&/\(\)=\?\.,@]').hasMatch(password)) {
      return 'Debe contener un carácter especial: !"#\$%&/()=?.,';
    }
    return null;
  }

  // =========================
  // ENVÍO DEL CÓDIGO
  // =========================
  Future<void> sendOtp(BuildContext context) async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack(context, 'Ingresa tu correo');
      return;
    }
    if (!email.contains('@')) {
      _snack(context, 'Ingresa un correo válido');
      return;
    }

    loading.value = true;
    try {
      // Si el correo no tiene cuenta, esto lanza y NO se avanza de paso: no
      // tiene sentido mandar a alguien a teclear un código que nunca va a
      // llegar. El mensaje lo pone el servidor.
      final mensaje = await _usersApi.enviarCodigoVerificacion(
        email,
        proposito: 'RESET',
      );
      step.value = 1;
      if (context.mounted) _snack(context, mensaje, error: false);
    } catch (e) {
      if (context.mounted) _snack(context, friendlyError(e));
    } finally {
      loading.value = false;
    }
  }

  /// Pide otro código sin salir del paso en el que está.
  ///
  /// Hace falta porque el código caduca, y ahora se usa más tarde que antes:
  /// se manda al guardar, después de escribir una contraseña que tiene que
  /// cumplir cuatro reglas.
  Future<void> reenviarCodigo(BuildContext context) async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) return;

    loading.value = true;
    try {
      await _usersApi.enviarCodigoVerificacion(email, proposito: 'RESET');
      if (context.mounted) {
        _snack(context, 'Te enviamos un código nuevo.', error: false);
      }
    } catch (e) {
      if (context.mounted) _snack(context, friendlyError(e));
    } finally {
      loading.value = false;
    }
  }

  // =========================
  // PASO DEL CÓDIGO
  // =========================
  /// Solo avanza de paso. No comprueba el código contra el servidor: eso pasa
  /// al guardar, junto con el cambio de contraseña, y es justamente lo que
  /// hace que no se pueda saltar.
  void verifyOtp(BuildContext context) {
    final codigo = otpCtrl.text.trim();
    if (codigo.isEmpty) {
      _snack(context, 'Ingresa el código');
      return;
    }
    step.value = 2;
  }

  // =========================
  // ACTUALIZAR CONTRASEÑA
  // =========================
  Future<void> updatePassword(BuildContext context) async {
    final password = passCtrl.text.trim();

    final validationError = _passwordError(password);
    if (validationError != null) {
      _snack(context, validationError);
      return;
    }

    final codigo = otpCtrl.text.trim();
    if (codigo.isEmpty) {
      _snack(context, 'Falta el código que te enviamos.');
      step.value = 1;
      return;
    }

    loading.value = true;
    try {
      final r = await _usersApi.resetPasswordConCodigo(
        emailCtrl.text.trim(),
        codigo,
        password,
      );

      if (!context.mounted) return;

      if (r.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(r.mensaje, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        return;
      }

      // El código caducó o está mal: se vuelve a pedirlo en vez de dejar a la
      // persona atascada en una pantalla que no avanza.
      if (r.codigoInvalido) {
        otpCtrl.clear();
        step.value = 1;
      }
      _snack(context, r.mensaje);
    } catch (e) {
      if (context.mounted) _snack(context, friendlyError(e));
    } finally {
      loading.value = false;
    }
  }

  void _snack(BuildContext context, String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green.shade700,
      ),
    );
  }
}
