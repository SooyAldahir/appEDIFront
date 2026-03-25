import 'package:edi301/services/users_api.dart';
import 'package:flutter/material.dart';
import 'package:edi301/services/otp_service.dart';

class ForgotPasswordController {
  final OtpService _otpService = OtpService();
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
  // ENVÍO OTP
  // =========================
  Future<void> sendOtp(BuildContext context) async {
    if (emailCtrl.text.trim().isEmpty) {
      _snack(context, 'Ingresa tu correo');
      return;
    }

    loading.value = true;

    try {
      await _otpService.sendOtp(emailCtrl.text.trim());
      step.value = 1;
    } catch (e) {
      _snack(context, 'Error al enviar código. Verifica tu correo.');
    } finally {
      loading.value = false;
    }
  }

  // =========================
  // VERIFICAR OTP
  // =========================
  Future<void> verifyOtp(BuildContext context) async {
    if (otpCtrl.text.trim().isEmpty) {
      _snack(context, 'Ingresa el código');
      return;
    }

    loading.value = true;

    try {
      final valid = await _otpService.verifyOtp(
        emailCtrl.text.trim(),
        otpCtrl.text.trim(),
      );

      if (valid) {
        step.value = 2;
      } else {
        _snack(context, 'Código incorrecto');
      }
    } catch (e) {
      _snack(context, 'Error al verificar código');
    } finally {
      loading.value = false;
    }
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

    loading.value = true;

    try {
      final success = await _usersApi.resetPassword(
        emailCtrl.text.trim(),
        password,
      );

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contraseña actualizada con éxito',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context);
        }
      } else {
        _snack(context, 'Error al actualizar la base de datos');
      }
    } catch (e) {
      _snack(context, 'Error de servidor');
    } finally {
      loading.value = false;
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}
