import 'package:flutter/material.dart';
import 'package:edi301/Register/register_controller.dart';
import 'package:flutter/scheduler.dart';
import 'package:edi301/models/institutional_user.dart'; // <-- Importa el nuevo modelo

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final RegisterController _controller = RegisterController();

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
  }

  @override
  void dispose() {
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
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            // --- Escucha el "paso" actual del registro ---
            child: ValueListenableBuilder<int>(
              valueListenable: _controller.registrationStep,
              builder: (context, step, child) {
                // Muestra la UI correspondiente al paso
                switch (step) {
                  case 1:
                    return _buildStep1VerifyEmail();
                  case 2:
                    return _buildStep2VerifyCode();
                  case 3:
                    return _buildStep3SetPassword();
                  case 0: // Por defecto
                  default:
                    return _buildStep0EnterDocument();
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  /// --- PASO 0: Ingresar Documento ---
  Widget _buildStep0EnterDocument() {
    return Column(
      children: [
        const Image(
          image: AssetImage('assets/img/logo_edi.png'),
          width: 150,
          height: 150,
        ),
        const SizedBox(height: 20),
        const Text(
          'Ingresa tu Matrícula o Número de Empleado',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _textField(
          controller: _controller.documentoCtrl,
          hint: 'Matrícula / No. Empleado',
          icon: Icons.badge_outlined,
          keyboard: TextInputType.number,
        ),
        _buttonAction(
          text: 'Buscar',
          onPressed: _controller.searchByDocument, // Llama a la nueva función
        ),
      ],
    );
  }

  /// --- PASO 1: Mostrar Datos y Verificar Correo ---
  Widget _buildStep1VerifyEmail() {
    return ValueListenableBuilder<InstitutionalUser?>(
      valueListenable: _controller.foundUser,
      builder: (context, user, child) {
        if (user == null) {
          // Si los datos se pierden, regresa al paso 0
          _controller.registrationStep.value = 0;
          return const Center(child: Text('Error, intente de nuevo.'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: const Image(
                image: AssetImage('assets/img/logo_edi.png'),
                width: 100,
                height: 100,
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

            // --- INICIO DE CORRECCIÓN ---
            _buildDataRow('Nombre:', '${user.nombre} ${user.apellidos}'),
            _buildDataRow(
              'Matricula/ NumEmpleado:',
              (user.matricula ?? user.numEmpleado).toString(),
            ),
            _buildDataRow('Escuela:', user.leNombreEscuelaOficial ?? 'N/A'),

            // --- AÑADIDOS ---
            _buildDataRow('Nivel:', user.nivelEducativo ?? 'N/A'),
            _buildDataRow('Campus:', user.campo ?? 'N/A'),
            _buildDataRow('Residencia:', user.residencia ?? 'N/A'),

            // --- FIN DE AÑADIDOS ---
            _buildDataRow(
              'Correo:',
              user.correoOculto,
            ), // Muestra el correo oculto
            // --- FIN DE CORRECCIÓN ---
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

  /// --- PASO 2: Ingresar Código de Verificación ---
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
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const Text(
          'Hemos enviado un código de 4 dígitos. (Pista: es 1234 por ahora)',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _textField(
          controller: _controller.verificationCodeCtrl,
          hint: 'Código de 4 dígitos',
          icon: Icons.pin_outlined,
          keyboard: TextInputType.number,
        ),
        _buttonAction(
          text: 'Validar Código',
          onPressed: _controller.verifyCode,
        ),
      ],
    );
  }

  /// --- PASO 3: Crear Contraseña ---
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
        const Text(
          'Debe tener 8+ caracteres, 1 mayúscula, 1 número y 1 caracter especial.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // --- INICIO DE MODIFICACIÓN ---

        // Campo de Contraseña
        _textField(
          controller: _controller.passCtrl,
          hint: 'Contraseña',
          icon: Icons.key_outlined,
          obscure: _obscurePass, // Usa la variable de estado
          suffixIcon: IconButton(
            // Añade el botón "ojito"
            icon: Icon(
              _obscurePass ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _obscurePass = !_obscurePass; // Cambia el estado
              });
            },
          ),
        ),

        // Campo de Confirmar Contraseña
        _textField(
          controller: _controller.confirmPassCtrl,
          hint: 'Confirmar contraseña',
          icon: Icons.key_outlined,
          obscure: _obscureConfirm, // Usa la variable de estado
          suffixIcon: IconButton(
            // Añade el botón "ojito"
            icon: Icon(
              _obscureConfirm ? Icons.visibility : Icons.visibility_off,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _obscureConfirm = !_obscureConfirm; // Cambia el estado
              });
            },
          ),
        ),

        // --- FIN DE MODIFICACIÓN ---
        _buttonAction(
          text: 'Completar Registro',
          onPressed: _controller.register, // Llama a la función final
        ),
      ],
    );
  }

  // --- WIDGETS REUTILIZABLES ---

  // Fila para mostrar los datos
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

  // Widget reutilizable para campos de texto
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

  // Widget reutilizable para el botón
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
