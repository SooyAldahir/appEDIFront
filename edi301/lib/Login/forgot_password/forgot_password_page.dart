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
  bool _obscureConfirm = true;

  final TextEditingController _confirmCtrl = TextEditingController();

  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );

  @override
  void initState() {
    super.initState();
    c.passCtrl.addListener(_rebuildOnTyping);
    _confirmCtrl.addListener(_rebuildOnTyping);
  }

  void _rebuildOnTyping() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    c.passCtrl.removeListener(_rebuildOnTyping);
    _confirmCtrl.removeListener(_rebuildOnTyping);
    _confirmCtrl.dispose();
    c.dispose();
    super.dispose();
  }

  // ====== Reglas en vivo ======
  bool get _min8 => c.passCtrl.text.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(c.passCtrl.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(c.passCtrl.text);
  // SOLO: !"#$%&/()=?.,  (regex escapada)
  bool get _hasSpecial =>
      RegExp(r'[!"#\$%&/\(\)=\?\.,@]').hasMatch(c.passCtrl.text);

  bool get _match =>
      c.passCtrl.text.isNotEmpty && c.passCtrl.text == _confirmCtrl.text;

  bool get _allOk => _min8 && _hasUpper && _hasNumber && _hasSpecial && _match;

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color.fromRGBO(19, 67, 107, 1);
    final secondaryColor = const Color.fromRGBO(245, 188, 6, 1);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: primaryColor,
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ValueListenableBuilder<int>(
            valueListenable: c.step,
            builder: (context, step, child) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  0,
                  0,
                  0,
                  MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (step == 0) ...[
                      const Text(
                        'Ingresa el correo asociado a tu cuenta para enviarte un código de verificación.',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: c.emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Correo Institucional',
                          labelStyle: const TextStyle(
                            color: Colors.white70,
                          ), // opcional
                          prefixIcon: const Icon(
                            Icons.email,
                            color: Colors.white,
                          ),

                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(color: Colors.white),
                          ),
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
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(height: 20),

                      _buildOtpRow(),

                      const SizedBox(height: 20),
                      const SizedBox(height: 20),
                      _buildButton(
                        'Verificar',
                        secondaryColor,
                        () => c.verifyOtp(context),
                      ),
                    ],

                    // ===== STEP 2: Nueva contraseña PRO =====
                    if (step == 2) ...[
                      const Text(
                        'Crea una nueva contraseña segura.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: c.passCtrl,
                        obscureText: _obscure,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          labelStyle: TextStyle(color: Colors.white),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                          ),
                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            tooltip: _obscure
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,

                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          labelStyle: TextStyle(color: Colors.white),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.white,
                          ),
                          border: inputBorder,
                          enabledBorder: inputBorder,
                          focusedBorder: inputBorder.copyWith(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            tooltip: _obscureConfirm
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      _RequirementCard(
                        items: [
                          _ReqItem(ok: _min8, text: 'Mínimo 8 caracteres'),
                          _ReqItem(
                            ok: _hasUpper,
                            text: 'Al menos 1 mayúscula (A-Z)',
                          ),
                          _ReqItem(
                            ok: _hasNumber,
                            text: 'Al menos 1 número (0-9)',
                          ),
                          _ReqItem(
                            ok: _hasSpecial,
                            text: r'Al menos 1 especial: !"#$%&/()=?.,@',
                          ),
                          _ReqItem(
                            ok: _match,
                            text: 'Las contraseñas coinciden',
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Botón: deshabilitado si no cumple reglas
                      ValueListenableBuilder<bool>(
                        valueListenable: c.loading,
                        builder: (context, loading, child) {
                          final disabled = loading || !_allOk;

                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: disabled
                                    ? Colors.grey.shade300
                                    : secondaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: disabled
                                  ? null
                                  : () async {
                                      // Extra: por si el user intenta “forzar”
                                      if (!_allOk) return;

                                      // Llama tu flujo actual
                                      await c.updatePassword(context);

                                      // Limpia confirm al terminar (opcional)
                                      if (mounted) _confirmCtrl.clear();
                                    },
                              child: loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Text(
                                      'Actualizar contraseña',
                                      style: TextStyle(
                                        color: disabled
                                            ? Colors.black54
                                            : Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Tip: usa una combinación difícil de adivinar.',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
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
          height: 54,
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: color,
              disabledBackgroundColor: color.withOpacity(0.55),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        );
      },
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              counterText: "",
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(245, 188, 6, 1),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color.fromRGBO(245, 188, 6, 1),
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              if (value.length == 1 && index < 3) {
                FocusScope.of(context).nextFocus();
              } else if (value.isEmpty && index > 0) {
                FocusScope.of(context).previousFocus();
              }

              String code = "";
              for (var cCtrl in _otpControllers) {
                code += cCtrl.text;
              }

              c.otpCtrl.text = code;

              // AUTO SUBMIT cuando los 4 dígitos estén llenos
              if (code.length == 4) {
                FocusScope.of(context).unfocus();
                c.verifyOtp(context);
              }
            },
          ),
        );
      }),
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
        border: Border.all(color: Color.fromRGBO(19, 67, 107, 1)),
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
