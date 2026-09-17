import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de un intento de autenticación biométrica.
enum BiometricResult {
  /// La persona se identificó correctamente.
  success,

  /// Canceló o falló el intento; puede volver a intentarlo.
  failed,

  /// El equipo no tiene sensor, o no hay huellas / rostro registrados.
  unavailable,

  /// El sistema bloqueó el sensor por demasiados intentos fallidos.
  lockedOut,
}

/// Desbloqueo con huella / Face ID.
///
/// IMPORTANTE: esto NO es autenticación contra el servidor. El servidor no
/// puede verificar una huella. Lo que hace es proteger localmente el
/// `session_token` que ya se obtuvo con usuario y contraseña: si la persona
/// se identifica, la app reutiliza esa sesión; si no, hay que escribir la
/// contraseña otra vez. La contraseña nunca se guarda en el dispositivo.
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  static const String _prefKey = 'biometric_unlock_enabled';
  static const String _promptShownKey = 'biometric_prompt_shown';

  final LocalAuthentication _auth = LocalAuthentication();

  /// ¿El equipo puede pedir biométrico Y hay alguno registrado?
  ///
  /// `isDeviceSupported` dice si hay hardware; `canCheckBiometrics` si el
  /// usuario tiene algo enrolado. Hacen falta las dos: un teléfono con lector
  /// pero sin huellas dadas de alta no sirve.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Nombre legible del método disponible, para los textos de la interfaz.
  Future<String> friendlyName() async {
    try {
      final tipos = await _auth.getAvailableBiometrics();
      if (tipos.contains(BiometricType.face)) return 'Face ID';
      if (tipos.contains(BiometricType.fingerprint)) return 'huella';
      if (tipos.contains(BiometricType.iris)) return 'iris';
      return 'biometría';
    } catch (_) {
      return 'biometría';
    }
  }

  /// Pide la identificación al sistema.
  ///
  /// `biometricOnly: false` a propósito: si el sensor falla o la persona trae
  /// guantes, el sistema ofrece el PIN o patrón del equipo como alternativa.
  /// Cerrarle esa puerta deja gente fuera de su propia cuenta.
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true, // sobrevive a que la app pase a segundo plano
          useErrorDialogs: true,
        ),
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          return BiometricResult.unavailable;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometricResult.lockedOut;
        default:
          return BiometricResult.failed;
      }
    } catch (_) {
      return BiometricResult.failed;
    }
  }

  // ── Preferencia del usuario ────────────────────────────────────────────────
  // Es una bandera, no un secreto: vive en SharedPreferences sin problema.

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  /// Para ofrecerlo una sola vez tras el primer login y no volver a insistir.
  Future<bool> wasPromptShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_promptShownKey) ?? false;
    } catch (_) {
      return true; // ante la duda, no molestar
    }
  }

  Future<void> markPromptShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_promptShownKey, true);
    } catch (_) {}
  }
}
