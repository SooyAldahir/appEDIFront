import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api_client_http.dart';
import '../../../../services/eventos_api.dart';

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
  File? _imagenSeleccionada;
  String? _imagenUrlRemota;

  bool _loading = false;
  int? _idEdicion;

  final EventosApi _api = EventosApi();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.eventoExistente != null) {
      _cargarDatos(widget.eventoExistente!);
    }
  }

  void _cargarDatos(Map<String, dynamic> datos) {
    _idEdicion = datos['id_evento'] ?? datos['id_actividad'];
    _titleCtrl.text = datos['titulo'] ?? '';
    _descCtrl.text = datos['mensaje'] ?? datos['descripcion'] ?? '';
    _daysCtrl.text = (datos['dias_anticipacion'] ?? 3).toString();
    _imagenUrlRemota = datos['imagen'];

    if (datos['fecha_evento'] != null) {
      _selectedDate = DateTime.tryParse(datos['fecha_evento'].toString());
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imagenSeleccionada = File(image.path);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Título y Fecha son obligatorios")),
      );
      return;
    }

    setState(() => _loading = true);

    final success = await _api.guardarEvento(
      id: _idEdicion,
      titulo: _titleCtrl.text,
      descripcion: _descCtrl.text,
      fecha: _selectedDate!,
      diasAnticipacion: int.tryParse(_daysCtrl.text) ?? 3,
      imagenFile: _imagenSeleccionada,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al guardar el evento")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = _idEdicion != null;

    ImageProvider? imagenProvider;
    if (_imagenSeleccionada != null) {
      imagenProvider = FileImage(_imagenSeleccionada!);
    } else if (_imagenUrlRemota != null && _imagenUrlRemota!.isNotEmpty) {
      // ApiHttp.baseUrl ya maneja la IP correcta según Android/Web
      imagenProvider = NetworkImage('${ApiHttp.baseUrl}$_imagenUrlRemota');
    }

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
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                  image: imagenProvider != null
                      ? DecorationImage(
                          image: imagenProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imagenProvider == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                          SizedBox(height: 10),
                          Text(
                            "Toca para agregar imagen",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            if (imagenProvider != null)
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.edit),
                  label: const Text("Cambiar imagen"),
                ),
              ),

            const SizedBox(height: 20),

            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Título del Evento",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Descripción",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
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
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Días de anticipación",
                helperText: "Días antes para mostrar en el feed.",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(245, 188, 6, 1),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                      esEdicion ? "Guardar Cambios" : "Publicar Evento",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
