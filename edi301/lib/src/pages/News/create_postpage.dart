import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/publicaciones_api.dart';

class CreatePostPage extends StatefulWidget {
  final int idUsuario;
  final int? idFamilia;

  const CreatePostPage({Key? key, required this.idUsuario, this.idFamilia})
    : super(key: key);

  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _mensajeController = TextEditingController();
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();
  final PublicacionesApi _api = PublicacionesApi();

  bool _cargando = false;

  // Variable para controlar qué tipo de contenido se sube
  String _tipoSeleccionado = 'POST'; // Puede ser 'POST' o 'STORY'

  Future<void> _seleccionarImagen() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        _imagenSeleccionada = File(photo.path);
      });
    }
  }

  Future<void> _enviarPost() async {
    if (_mensajeController.text.isEmpty && _imagenSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Escribe algo o sube una foto")),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      await _api.crearPost(
        idUsuario: widget.idUsuario,
        idFamilia: widget.idFamilia,
        mensaje: _mensajeController.text,
        imagen: _imagenSeleccionada,
        categoria: 'Familiar', // Siempre es Familiar en esta pantalla
        tipo: _tipoSeleccionado, // Enviamos lo que el usuario eligió
      );

      if (mounted) {
        // Mensaje diferente según el tipo
        String mensajeExito = _tipoSeleccionado == 'STORY'
            ? "Historia enviada a aprobación ⏳"
            : "Publicación enviada a aprobación ⏳";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeExito), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Contenido"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- SELECTOR DE TIPO (POST vs HISTORIA) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTypeChip('Publicación', 'POST', Icons.grid_view),
                const SizedBox(width: 15),
                _buildTypeChip('Historia', 'STORY', Icons.history_edu),
              ],
            ),
            const SizedBox(height: 20),

            // Área de texto
            TextField(
              controller: _mensajeController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: _tipoSeleccionado == 'STORY'
                    ? "Agrega un texto a tu historia..."
                    : "¿Qué quieres compartir hoy?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 20),

            // Previsualización de imagen
            if (_imagenSeleccionada != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _imagenSeleccionada!,
                      height: _tipoSeleccionado == 'STORY'
                          ? 350
                          : 250, // Historia más alta
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _imagenSeleccionada = null),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Botón para subir foto
            OutlinedButton.icon(
              onPressed: _seleccionarImagen,
              icon: const Icon(Icons.photo_library),
              label: const Text("Seleccionar Foto/Video"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Botón Enviar
            ElevatedButton(
              onPressed: _cargando ? null : _enviarPost,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      "Enviar a Aprobación",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para los botones de selección
  Widget _buildTypeChip(String label, String value, IconData icon) {
    final isSelected = _tipoSeleccionado == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) setState(() => _tipoSeleccionado = value);
      },
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
