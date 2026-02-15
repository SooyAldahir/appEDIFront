import 'package:flutter/material.dart';
import 'forgot_password_controller.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final ForgotPasswordController c = ForgotPasswordController();
  bool _obscure = true;
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color.fromRGBO(19, 67, 107, 1);
    final secondaryColor = const Color.fromRGBO(245, 188, 6, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ValueListenableBuilder<int>(
          valueListenable: c.step,
          builder: (context, step, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (step == 0) ...[
                  const Text(
                    'Ingresa el correo asociado a tu cuenta para enviarte un código de verificación.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: c.emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo Institucional/Personal',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildButton(
                    'Enviar Código',
                    secondaryColor,
                    () => c.sendOtp(context),
                  ),
                ],
                if (step == 1) ...[
                  const Text(
                    'Ingresa el código que hemos enviado a tu correo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: c.otpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Código OTP',
                      prefixIcon: Icon(Icons.password),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildButton(
                    'Verificar',
                    secondaryColor,
                    () => c.verifyOtp(context),
                  ),
                ],
                if (step == 2) ...[
                  const Text(
                    'Ingresa tu nueva contraseña.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: c.passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildButton(
                    'Actualizar Contraseña',
                    Colors.green,
                    () => c.updatePassword(context),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return ValueListenableBuilder<bool>(
      valueListenable: c.loading,
      builder: (context, loading, child) {
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: loading ? null : onPressed,
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
