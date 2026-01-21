import 'package:edi301/core/api_client_http.dart';
import 'package:flutter/material.dart';

class CreateEventPage extends StatefulWidget {
  final Map<String, dynamic>? eventoExistente;

  const CreateEventPage({super.key, this.eventoExistente});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(text: '3');

  DateTime? _selectedDate;
  bool _loading = false;
  int? _idEdicion;

  final ApiHttp _http = ApiHttp();

  @override
  void initState() {
    super.initState();
    if (widget.eventoExistente != null) {
      _cargarDatosInterno(widget.eventoExistente!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.eventoExistente == null && _idEdicion == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        _cargarDatosInterno(Map<String, dynamic>.from(args));
      }
    }
  }

  void _cargarDatosInterno(Map<String, dynamic> datos) {
    print("Cargando datos de evento: $datos");
    _idEdicion = datos['id_evento'] ?? datos['id_actividad'];
    _titleCtrl.text = datos['titulo'] ?? '';
    _descCtrl.text = datos['mensaje'] ?? datos['descripcion'] ?? '';
    _daysCtrl.text = (datos['dias_anticipacion'] ?? 3).toString();
    if (datos['fecha_evento'] != null) {
      _selectedDate = DateTime.tryParse(datos['fecha_evento'].toString());
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Título y Fecha obligatorios")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final data = {
        'titulo': _titleCtrl.text,
        'descripcion': _descCtrl.text,
        'fecha_evento': _selectedDate!.toIso8601String(),
        'dias_anticipacion': int.tryParse(_daysCtrl.text) ?? 3,
      };

      if (_idEdicion == null) {
        await _http.postJson('/api/agenda', data: data);
      } else {
        await _http.putJson('/api/agenda/$_idEdicion', data: data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = _idEdicion != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? "Editar Evento" : "Nuevo Evento"),
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Título del Evento",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Descripción",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            ListTile(
              title: Text(
                _selectedDate == null
                    ? "Seleccionar Fecha del Evento"
                    : "Fecha: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
              tileColor: Colors.grey[200],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "¿Cuántos días antes mostrar?",
                helperText: "Días de anticipación en el feed.",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text(
                      esEdicion ? "Guardar Cambios" : "Publicar Evento",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
