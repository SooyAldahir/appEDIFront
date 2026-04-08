import 'package:edi301/src/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'add_tutor_controller.dart';

class AddTutorPage extends StatefulWidget {
  const AddTutorPage({super.key});

  @override
  State<AddTutorPage> createState() => _AddTutorPageState();
}

class _AddTutorPageState extends State<AddTutorPage> {
  final AddTutorController c = AddTutorController();

  static const _primary = Color.fromRGBO(19, 67, 107, 1);
  static const _accent = Color.fromRGBO(245, 188, 6, 1);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  // ── Campo de texto reutilizable ────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? hint,
    bool optional = false,
    Widget? suffix,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboard,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: optional ? '$label (opcional)' : label,
            prefixIcon: Icon(icon, color: _primary),
            hintText: hint,
            suffixIcon: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // ── Separador de sección ───────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 18,
          color: _primary,
          margin: const EdgeInsets.only(right: 8),
        ),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: _primary,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Tutor Externo'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Descripción
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Registra a un padre o madre que no cuenta con correo institucional.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),

              // ── Relación ────────────────────────────────────────────────
              _sectionLabel('Relación'),
              ValueListenableBuilder<int>(
                valueListenable: c.idRolSeleccionado,
                builder: (context, rol, _) => Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Papá EDI'),
                        value: 2,
                        groupValue: rol,
                        activeColor: _primary,
                        onChanged: (v) => c.idRolSeleccionado.value = v!,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Mamá EDI'),
                        value: 3,
                        groupValue: rol,
                        activeColor: _primary,
                        onChanged: (v) => c.idRolSeleccionado.value = v!,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // ── Datos personales ─────────────────────────────────────────
              _sectionLabel('Datos personales'),
              _field(
                controller: c.nombreCtrl,
                label: 'Nombre(s)',
                icon: Icons.person,
              ),
              _field(
                controller: c.apellidoCtrl,
                label: 'Apellidos',
                icon: Icons.badge,
              ),

              // Fecha de nacimiento
              ValueListenableBuilder<DateTime?>(
                valueListenable: c.fechaNacimiento,
                builder: (context, fecha, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => c.seleccionarFecha(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: fecha == null
                                ? Colors.grey.shade400
                                : _primary,
                            width: fecha == null ? 1 : 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cake,
                              color: fecha == null ? Colors.grey : _primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              c.fechaDisplay,
                              style: TextStyle(
                                fontSize: 16,
                                color: fecha == null
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),

              _field(
                controller: c.telefonoCtrl,
                label: 'Número de teléfono',
                icon: Icons.phone,
                keyboard: TextInputType.phone,
                optional: true,
              ),

              // ── Dirección ───────────────────────────────────────────────
              _sectionLabel('Dirección'),
              _field(
                controller: c.direccionCtrl,
                label: 'Dirección',
                icon: Icons.home,
                hint: 'Calle, número, colonia...',
                optional: true,
              ),

              // ── Acceso ──────────────────────────────────────────────────
              _sectionLabel('Credenciales de acceso'),
              _field(
                controller: c.correoCtrl,
                label: 'Correo electrónico personal',
                icon: Icons.email,
                keyboard: TextInputType.emailAddress,
                hint: 'ejemplo@gmail.com',
              ),
              ValueListenableBuilder<bool>(
                valueListenable: c.mostrarContrasena,
                builder: (_, visible, __) => _field(
                  controller: c.contrasenaCtrl,
                  label: 'Contraseña temporal',
                  icon: Icons.lock,
                  obscure: !visible,
                  suffix: IconButton(
                    icon: Icon(
                      visible ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => c.mostrarContrasena.value = !visible,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Botón guardar ────────────────────────────────────────────
              ValueListenableBuilder<bool>(
                valueListenable: c.loading,
                builder: (_, loading, __) => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    loading ? 'Guardando...' : 'Crear Tutor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: loading ? null : () => c.save(context),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
