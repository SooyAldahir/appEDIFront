import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:edi301/Register/register_controller.dart';
import 'package:flutter/scheduler.dart';
import 'package:edi301/models/institutional_user.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final RegisterController _controller = RegisterController();

  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );

  // Colores
  static const primaryColor = Color.fromRGBO(19, 67, 107, 1);
  static const accentColor = Color.fromRGBO(245, 188, 6, 1);

  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context);
    });

    _controller.passCtrl.addListener(_rebuildOnTyping);
    _controller.confirmPassCtrl.addListener(_rebuildOnTyping);
  }

  void _rebuildOnTyping() {
    if (!mounted) return;
    setState(() {});
  }

  // ====== Reglas en vivo ======
  bool get _min8 => _controller.passCtrl.text.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_controller.passCtrl.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_controller.passCtrl.text);
  bool get _hasSpecial =>
      RegExp(r'[!"#\$%&/\(\)=\?\.,@]').hasMatch(_controller.passCtrl.text);

  bool get _match =>
      _controller.passCtrl.text.isNotEmpty &&
      _controller.passCtrl.text == _controller.confirmPassCtrl.text;

  bool get _allOk => _min8 && _hasUpper && _hasNumber && _hasSpecial && _match;

  @override
  void dispose() {
    _controller.passCtrl.removeListener(_rebuildOnTyping);
    _controller.confirmPassCtrl.removeListener(_rebuildOnTyping);

    for (final c in _otpControllers) {
      c.dispose();
    }

    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _controller.goToLoginPage,
        ),
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: _controller.registrationStep,
                  builder: (context, step, child) {
                    switch (step) {
                      case 1:
                        return _buildStep1VerifyEmail();
                      case 2:
                        return _buildStep2VerifyCode();
                      case 3:
                        return _buildStep3SetPassword();
                      case 0:
                      default:
                        return _buildStep0EnterDocument();
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep0EnterDocument() {
    return Column(
      children: [
        const Image(
          image: AssetImage('assets/img/logo_edi.png'),
          width: 225,
          height: 225,
        ),
        const SizedBox(height: 20),
        const Text(
          'Ingresa tu Matrícula o Número de Colaborador',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _textField(
          controller: _controller.documentoCtrl,
          hint: 'Matrícula / No. Colaborador',
          icon: Icons.badge_outlined,
          keyboard: TextInputType.number,
        ),
        _buttonAction(text: 'Buscar', onPressed: _controller.searchByDocument),
      ],
    );
  }

  Widget _buildStep1VerifyEmail() {
    return ValueListenableBuilder<InstitutionalUser?>(
      valueListenable: _controller.foundUser,
      builder: (context, user, child) {
        if (user == null) {
          _controller.registrationStep.value = 0;
          return const Center(child: Text('Error, intente de nuevo.'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: const Image(
                image: AssetImage('assets/img/logo_edi.png'),
                width: 225,
                height: 225,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Eres tú?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildDataRow('Nombre:', '${user.nombre} ${user.apellidos}'),
            _buildDataRow(
              'Identificador:',
              (user.matricula ?? user.numEmpleado).toString(),
            ),
            _buildDataRow('Escuela:', user.leNombreEscuelaOficial ?? 'N/A'),
            _buildDataRow('Nivel:', user.nivelEducativo ?? 'N/A'),
            _buildDataRow('Campus:', user.campo ?? 'N/A'),
            _buildDataRow('Residencia:', user.residencia ?? 'N/A'),
            _buildDataRow('Correo:', user.correoOculto),
            const SizedBox(height: 20),
            const Text(
              'Para verificar tu identidad, escribe tu correo institucional completo:',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            _textField(
              controller: _controller.emailVerificationCtrl,
              hint: 'Correo completo',
              icon: Icons.mail_outline,
              keyboard: TextInputType.emailAddress,
            ),
            _buttonAction(
              text: 'Verificar Correo y Enviar Código',
              onPressed: _controller.verifyEmail,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStep2VerifyCode() {
    return Column(
      children: [
        const Image(
          image: AssetImage('assets/img/logo_edi.png'),
          width: 150,
          height: 150,
        ),
        const SizedBox(height: 20),
        Text(
          'Revisa tu correo: ${_controller.foundUser.value?.correoOculto ?? '...'}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'Ingresa el código de 4 dígitos que recibiste.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        _buildOtpRow(),
        const SizedBox(height: 20),
        _buttonAction(
          text: 'Validar Código',
          onPressed: _controller.verifyCode,
        ),
      ],
    );
  }

  Widget _buildStep3SetPassword() {
    return Column(
      children: [
        const Image(
          image: AssetImage('assets/img/logo_edi.png'),
          width: 150,
          height: 150,
        ),
        const SizedBox(height: 20),
        const Text(
          '¡Verificación exitosa! \nAhora crea tu contraseña:',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),

        _textField(
          controller: _controller.passCtrl,
          hint: 'Contraseña',
          icon: Icons.key_outlined,
          obscure: _obscurePass,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePass ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _obscurePass = !_obscurePass;
              });
            },
          ),
        ),

        _textField(
          controller: _controller.confirmPassCtrl,
          hint: 'Confirmar contraseña',
          icon: Icons.key_outlined,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirm = !_obscureConfirm;
              });
            },
          ),
        ),

        const SizedBox(height: 12),

        _RequirementCard(
          items: [
            _ReqItem(ok: _min8, text: 'Mínimo 8 caracteres'),
            _ReqItem(ok: _hasUpper, text: 'Al menos 1 mayúscula (A-Z)'),
            _ReqItem(ok: _hasNumber, text: 'Al menos 1 número (0-9)'),
            _ReqItem(
              ok: _hasSpecial,
              text: r'Al menos 1 especial: !"#$%&/()=?.,@',
            ),
            _ReqItem(ok: _match, text: 'Las contraseñas coinciden'),
          ],
        ),

        const SizedBox(height: 18),

        ValueListenableBuilder<bool>(
          valueListenable: _controller.loading,
          builder: (context, isLoading, child) {
            final disabled = isLoading || !_allOk;

            return SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: disabled ? null : _controller.register,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: accentColor,
                  disabledBackgroundColor: accentColor.withOpacity(0.45),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Completar Registro',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: disabled ? Colors.black54 : Colors.black,
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: accentColor, width: 2)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(15),
          prefixIcon: Icon(icon, color: Colors.white),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildOtpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (index) {
        return SizedBox(
          width: 60,
          height: 60,
          child: TextField(
            controller: _otpControllers[index],
            autofocus: index == 0,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: "",
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: accentColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.length == 1 && index < 3) {
                FocusScope.of(context).nextFocus();
              } else if (value.isEmpty && index > 0) {
                FocusScope.of(context).previousFocus();
              }

              String code = "";
              for (var c in _otpControllers) {
                code += c.text;
              }

              _controller.verificationCodeCtrl.text = code;

              // Auto validación al completar 4 dígitos
              if (code.length == 4) {
                FocusScope.of(context).unfocus();
                _controller.verifyCode();
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buttonAction({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (context, isLoading, child) {
          return ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: accentColor,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// ======= UI checklist =======

class _ReqItem {
  final bool ok;
  final String text;
  const _ReqItem({required this.ok, required this.text});
}

class _RequirementCard extends StatelessWidget {
  final List<_ReqItem> items;
  const _RequirementCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color.fromRGBO(19, 67, 107, 1),
        borderRadius: BorderRadius.circular(14),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((it) {
          final color = it.ok ? Colors.green : Colors.red;
          final icon = it.ok ? Icons.check_circle : Icons.cancel;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    it.text,
                    style: TextStyle(
                      color: it.ok
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
