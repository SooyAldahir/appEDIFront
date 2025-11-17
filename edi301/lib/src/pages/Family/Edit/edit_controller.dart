import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:edi301/services/fotos_api.dart';

class EditController {
  BuildContext? context;

  final ImagePicker _picker = ImagePicker();
  final FotosApi _fotosApi = FotosApi();

  // Notificadores para actualizar la UI cuando se selecciona una imagen
  ValueNotifier<XFile?> profileImage = ValueNotifier(null);
  ValueNotifier<XFile?> coverImage = ValueNotifier(null);
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(BuildContext context) async {
    this.context = context;
  }

  // Método para seleccionar la foto de perfil
  Future<void> selectProfileImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        profileImage.value = pickedFile;
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  // Método para seleccionar la foto de portada
  Future<void> selectCoverImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        coverImage.value = pickedFile;
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> saveChanges() async {
    if (isLoading.value) return; // Evitar múltiples clicks

    isLoading.value = true;
    bool profileUploaded = false;
    bool coverUploaded = false;

    try {
      // 1. Subir imagen de perfil si cambió
      if (profileImage.value != null) {
        File imageFile = File(profileImage.value!.path);
        print('Subiendo foto de perfil...');
        await _fotosApi.uploadProfileImage(imageFile);
        profileUploaded = true;
      }

      // 2. Subir imagen de portada si cambió
      if (coverImage.value != null) {
        File imageFile = File(coverImage.value!.path);
        print('Subiendo foto de portada...');
        await _fotosApi.uploadCoverImage(imageFile);
        coverUploaded = true;
      }

      // 3. Mostrar confirmación
      if (context != null) {
        if (!profileUploaded && !coverUploaded) {
          ScaffoldMessenger.of(context!).showSnackBar(
            const SnackBar(
              content: Text('No hay cambios de imagen para guardar'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context!).showSnackBar(
            const SnackBar(content: Text('¡Imágenes actualizadas con éxito!')),
          );
          // Opcional: Navegar hacia atrás después de guardar
          // Navigator.pop(context!);
        }
      }
    } catch (e) {
      // 4. Manejar errores
      if (context != null) {
        ScaffoldMessenger.of(
          context!,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      // 5. Detener la carga
      isLoading.value = false;
    }
  }
}
