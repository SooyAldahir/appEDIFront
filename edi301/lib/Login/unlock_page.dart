import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edi301/auth/token_storage.dart';
import 'package:edi301/services/biometric_service.dart';
import 'package:edi301/services/socket_service.dart';

/// Pantalla de bloqueo: hay una sesión guardada y el usuario activó el
/// desbloqueo biométrico, así que en vez del formulario de login se pide huella
/// o Face ID. Siempre queda la salida "Entrar con contraseña".
class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  static const _navy = Color.fromRGBO(19, 67, 107, 1);
  static const _gold = Color.fromRGBO(245, 188, 6, 1);

  final BiometricService _biometrics = BiometricService();
  final TokenStorage _tokenStorage = TokenStorage();

  bool _working = true;
  String _metodo = 'biometría';
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  Future<void> _preparar() async {
    _metodo = await _biometrics.friendlyName();
    if (mounted) setState(() {});
    await _intentar();
  }

  Future<void> _intentar() async {
    if (!mounted) return;
    setState(() {
      _working = true;
      _mensaje = null;
    });

    final resultado = await _biometrics.authenticate(
      reason: 'Confirma tu identidad para entrar a EDI 301',
    );

    if (!mounted) return;

    switch (resultado) {
      case BiometricResult.success:
        await _entrar();
        return;

      case BiometricResult.unavailable:
        // Se desactivó el sensor o se borraron las huellas desde que lo
        // habilitó: se apaga la opción y se manda al login normal.
        await _biometrics.setEnabled(false);
        if (mounted) _irALogin(conservarSesion: true);
        return;

      case BiometricResult.lockedOut:
        setState(() {
          _working = false;
          _mensaje =
              'Demasiados intentos. Desbloquea tu teléfono con tu PIN y vuelve '
              'a intentarlo, o entra con tu contraseña.';
        });
        return;

      case BiometricResult.failed:
        setState(() {
          _working = false;
          _mensaje = 'No se pudo verificar tu identidad.';
        });
        return;
    }
  }

  /// Biométrico correcto: la sesión guardada sigue siendo válida, así que se
  /// levanta el socket y se entra directo.
  Future<void> _entrar() async {
    final token = await _tokenStorage.read();
    if (token == null || token.isEmpty) {
      // La sesión desapareció (el usuario borró datos, por ejemplo).
      if (mounted) _irALogin(conservarSesion: false);
      return;
    }

    await SocketService().reconnectWithAuth();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('home', (_) => false);
  }

  /// Sale al login. Si [conservarSesion] es false se borra el token: es el caso
  /// de "prefiero entrar con mi contraseña".
  Future<void> _irALogin({required bool conservarSesion}) async {
    if (!conservarSesion) {
      await _tokenStorage.clear();
      await _biometrics.setEnabled(false);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user');
      } catch (_) {}
      SocketService().disconnect();
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    _metodo == 'Face ID'
                        ? Icons.face_retouching_natural
                        : Icons.fingerprint,
                    size: 52,
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'EDI 301',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _working
                      ? 'Esperando tu $_metodo...'
                      : 'Desbloquea con tu $_metodo para continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                  ),
                ),
                if (_mensaje != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _mensaje!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _gold, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 32),
                if (_working)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _gold,
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Intentar de nuevo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _intentar,
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _working
                      ? null
                      : () => _irALogin(conservarSesion: false),
                  child: Text(
                    'Entrar con mi contraseña',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
