// lib/src/pages/Admin/agenda/crear_evento_page.dart
import 'package:flutter/material.dart';
import 'package:edi301/src/pages/Admin/agenda/agenda_controller.dart';

class CrearEventoPage extends StatefulWidget {
  const CrearEventoPage({super.key});

  @override
  State<CrearEventoPage> createState() => _CrearEventoPageState();
}

class _CrearEventoPageState extends State<CrearEventoPage> {
  final AgendaController _controller = AgendaController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller.init(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _controller.fechaEvento ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _controller.fechaEvento) {
      setState(() {
        _controller.fechaEvento = picked;
      });
    }
  }

  Future<void> _selectHora(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _controller.horaEvento ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _controller.horaEvento = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromRGBO(19, 67, 107, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Evento'),
        backgroundColor: primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _controller.tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título del evento'),
              validator: (v) => v!.isEmpty ? 'El título es requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller.descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller.imagenCtrl,
              decoration: const InputDecoration(
                labelText: 'URL de la imagen (Opcional)',
              ),
              //keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // --- Selectores de Fecha y Hora ---
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Fecha del Evento'),
                    subtitle: Text(
                      _controller.fechaEvento != null
                          ? '${_controller.fechaEvento!.day}/${_controller.fechaEvento!.month}/${_controller.fechaEvento!.year}'
                          : 'No seleccionada',
                    ),
                    leading: const Icon(Icons.calendar_today),
                    onTap: () => _selectFecha(context),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Hora (Opcional)'),
                    subtitle: Text(
                      _controller.horaEvento != null
                          ? _controller.horaEvento!.format(context)
                          : 'No seleccionada',
                    ),
                    leading: const Icon(Icons.access_time),
                    onTap: () => _selectHora(context),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // --- Switch de Recordatorio ---
            ValueListenableBuilder<bool>(
              valueListenable: _controller.crearRecordatorio,
              builder: (context, value, child) {
                return SwitchListTile(
                  title: const Text('Establecer recordatorio'),
                  subtitle: const Text(
                    'Programar un recordatorio recurrente para este evento',
                  ),
                  value: value,
                  onChanged: (newValue) {
                    _controller.crearRecordatorio.value = newValue;
                  },
                );
              },
            ),

            // --- Opciones de Recordatorio (condicional) ---
            ValueListenableBuilder<bool>(
              valueListenable: _controller.crearRecordatorio,
              builder: (context, crear, child) {
                if (!crear) return const SizedBox.shrink();

                // Estos son los campos para el *recordatorio*
                return Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.withOpacity(0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Opciones del Recordatorio",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _controller.recordatorioHoraCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hora del recordatorio (ej: 13:00)',
                          icon: Icon(Icons.alarm),
                        ),
                        validator: (v) => (v!.isEmpty || v.length < 5)
                            ? 'Formato HH:MM requerido'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _controller.recordatorioTipo,
                        decoration: const InputDecoration(
                          labelText: 'Frecuencia',
                          icon: Icon(Icons.repeat),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'DAY',
                            child: Text('Diariamente'),
                          ),
                          DropdownMenuItem(
                            value: 'WEEK',
                            child: Text('Semanalmente'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _controller.recordatorioTipo = v!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _controller.recordatorioDiasAntesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Iniciar recordatorios (días antes)',
                          icon: Icon(Icons.notification_add),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // --- Botón de Guardar ---
            ValueListenableBuilder<bool>(
              valueListenable: _controller.loading,
              builder: (context, isLoading, child) {
                return ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _controller.guardarEvento();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(isLoading ? 'GUARDANDO...' : 'GUARDAR EVENTO'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
