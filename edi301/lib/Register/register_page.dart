import 'package:flutter/material.dart';
import 'package:edi301/Register/register_controller.dart';
import 'package:flutter/scheduler.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final RegisterController _controller = RegisterController();

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
    const primaryColor = Color.fromRGBO(19, 67, 107, 1);
    const accentColor = Color.fromRGBO(245, 188, 6, 1);

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
            child: Column(
              children: [
                const Image(
                  image: AssetImage('assets/img/logo_edi.png'),
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 20),

                // Selector de Tipo de Usuario
                _buildUserTypeSelector(accentColor),
                const SizedBox(height: 10),

                // Campos comunes
                _textField(
                  controller: _controller.nombreCtrl,
                  hint: 'Nombre(s)',
                  icon: Icons.person_outline,
                ),
                _textField(
                  controller: _controller.apellidoCtrl,
                  hint: 'Apellidos',
                  icon: Icons.person_outline,
                ),
                _textField(
                  controller: _controller.emailCtrl,
                  hint: 'Correo institucional (@ulv.edu.mx)',
                  icon: Icons.mail_outline,
                  keyboard: TextInputType.emailAddress,
                ),

                // Campos condicionales (Matrícula / Num. Empleado)
                ValueListenableBuilder<String>(
                  valueListenable: _controller.tipoUsuario,
                  builder: (context, tipo, child) {
                    if (tipo == 'ALUMNO') {
                      return _textField(
                        controller: _controller.matriculaCtrl,
                        hint: 'Matrícula',
                        icon: Icons.school_outlined,
                        keyboard: TextInputType.number,
                      );
                    } else {
                      return _textField(
                        controller: _controller.numEmpleadoCtrl,
                        hint: 'Número de Empleado',
                        icon: Icons.work_outline,
                        keyboard: TextInputType.number,
                      );
                    }
                  },
                ),

                // Contraseñas
                _textField(
                  controller: _controller.passCtrl,
                  hint: 'Contraseña',
                  icon: Icons.key_outlined,
                  obscure: true,
                ),
                _textField(
                  controller: _controller.confirmPassCtrl,
                  hint: 'Confirmar contraseña',
                  icon: Icons.key_outlined,
                  obscure: true,
                ),

                _buttonAction(accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget para el selector Alumno/Empleado
  Widget _buildUserTypeSelector(Color accentColor) {
    return ValueListenableBuilder<String>(
      valueListenable: _controller.tipoUsuario,
      builder: (context, tipo, child) {
        return ToggleButtons(
          isSelected: [tipo == 'ALUMNO', tipo == 'EMPLEADO'],
          onPressed: (index) {
            _controller.tipoUsuario.value = index == 0 ? 'ALUMNO' : 'EMPLEADO';
          },
          borderRadius: BorderRadius.circular(30),
          fillColor: accentColor.withOpacity(0.3),
          selectedColor: accentColor,
          color: Colors.white70,
          borderColor: accentColor,
          selectedBorderColor: accentColor,
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.school),
                  SizedBox(width: 8),
                  Text('Soy Alumno'),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.work),
                  SizedBox(width: 8),
                  Text('Soy Empleado'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Widget reutilizable para campos de texto
  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color.fromRGBO(245, 188, 6, 1), width: 2),
        ),
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
        ),
      ),
    );
  }

  Widget _buttonAction(Color accentColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: ValueListenableBuilder<bool>(
        valueListenable: _controller.loading,
        builder: (context, isLoading, child) {
          return ElevatedButton(
            onPressed: isLoading ? null : _controller.register,
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
                : const Text(
                    'Registrarme',
                    style: TextStyle(
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
