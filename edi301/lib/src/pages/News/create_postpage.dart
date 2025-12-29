import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/publicaciones_api.dart';
// Importa tu modelo de usuario o servicio de autenticación para obtener el ID actual

class CreatePostPage extends StatefulWidget {
  final int idUsuario;
  final int?
  idFamilia; // Puede ser null si el usuario no tiene familia asignada

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Escribe algo o sube una foto")));
      return;
    }

    setState(() => _cargando = true);

    try {
      await _api.crearPost(
        idUsuario: widget.idUsuario,
        idFamilia: widget.idFamilia,
        mensaje: _mensajeController.text,
        imagen: _imagenSeleccionada,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Solicitud enviada a tus padres")),
        );
        Navigator.pop(context); // Regresa a la pantalla anterior
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Nueva Publicación"), elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Área de texto
            TextField(
              controller: _mensajeController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "¿Qué quieres compartir hoy?",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            SizedBox(height: 20),

            // Previsualización de imagen
            if (_imagenSeleccionada != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _imagenSeleccionada!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => setState(() => _imagenSeleccionada = null),
                  ),
                ],
              ),

            // Botón para subir foto
            OutlinedButton.icon(
              onPressed: _seleccionarImagen,
              icon: Icon(Icons.photo_camera),
              label: Text("Agregar Foto"),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),

            SizedBox(height: 20),

            // Botón Enviar
            ElevatedButton(
              onPressed: _cargando ? null : _enviarPost,
              child: _cargando
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text("Enviar Solicitud", style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.green, // Color de tu diseño
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
