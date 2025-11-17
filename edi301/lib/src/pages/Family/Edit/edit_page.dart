import 'dart:io'; // Necesario para File()
import 'package:edi301/src/pages/Family/Edit/edit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart'; // Necesario para XFile

class EditPage extends StatefulWidget {
  const EditPage({super.key});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  final EditController _controller = EditController();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _controller.init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Foto del perfil',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    // --- MODIFICADO ---
                    onTap: () {
                      _controller.selectProfileImage();
                    },
                    child: const Text(
                      'Editar',
                      style: TextStyle(fontSize: 16, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // --- MODIFICADO ---
            ValueListenableBuilder<XFile?>(
              valueListenable: _controller.profileImage,
              builder: (context, image, child) {
                return CircleAvatar(
                  radius: 60,
                  backgroundImage: image != null
                      ? FileImage(File(image.path))
                            as ImageProvider // Muestra la nueva imagen
                      : const AssetImage(
                          // Muestra la imagen por defecto
                          'assets/img/los-24-mandamientos-de-la-familia-feliz-lg.jpg',
                        ),
                );
              },
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Foto de portada',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    // --- MODIFICADO ---
                    onTap: () {
                      _controller.selectCoverImage();
                    },
                    child: const Text(
                      'Editar',
                      style: TextStyle(fontSize: 16, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // --- MODIFICADO ---
            SizedBox(
              width: double.infinity,
              height: 200,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ValueListenableBuilder<XFile?>(
                    valueListenable: _controller.coverImage,
                    builder: (context, image, child) {
                      return image != null
                          ? Image.file(
                              // Muestra la nueva imagen
                              File(image.path),
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              // Muestra la imagen por defecto
                              'assets/img/familia-extensa-e1591818033557.jpg',
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Descripcion',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Editar',
                      style: TextStyle(fontSize: 16, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Esta es una pequeña descripción de ejemplo para mostrar el apartado de la descripción para la familia a la que corresponda',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30), // Espacio antes del botón
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              // --- MODIFICADO ---
              // Escucha el estado de carga del controlador
              child: ValueListenableBuilder<bool>(
                valueListenable: _controller.isLoading,
                builder: (context, loading, child) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(19, 67, 107, 1),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    // Deshabilita el botón si está cargando
                    onPressed: loading
                        ? null
                        : () {
                            _controller.saveChanges();
                          },
                    // Muestra el indicador o el texto
                    child: loading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : const Text(
                            'Guardar Cambios',
                            style: TextStyle(fontSize: 18),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
