import 'dart:io';
import 'package:edi301/services/familia_api.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditController {
  BuildContext? context;
  int? familyId;

  final ImagePicker _picker = ImagePicker();
  final FamiliaApi _familiaApi = FamiliaApi();

  // Notificadores para actualizar la UI cuando se selecciona una imagen
  ValueNotifier<XFile?> profileImage = ValueNotifier(null);
  ValueNotifier<XFile?> coverImage = ValueNotifier(null);
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  Future<void> init(BuildContext context, int familyId) async {
    this.context = context;
    this.familyId = familyId;
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
    if (isLoading.value) return;
    if (familyId == null) {
      ScaffoldMessenger.of(context!).showSnackBar(
        const SnackBar(content: Text('Error: ID de familia no encontrado')),
      );
      return;
    }
    if (profileImage.value == null && coverImage.value == null) {
      ScaffoldMessenger.of(context!).showSnackBar(
        const SnackBar(content: Text('No hay cambios de imagen para guardar')),
      );
      return;
    }

    isLoading.value = true;

    try {
      // Preparamos los archivos (si existen)
      File? profileFile = profileImage.value != null
          ? File(profileImage.value!.path)
          : null;
      File? coverFile = coverImage.value != null
          ? File(coverImage.value!.path)
          : null;

      // ¡Aquí está la magia!
      // Debes obtener el token de donde lo tengas guardado (ej: TokenStorage)
      // String? token = await TokenStorage.getToken();
      String? token = "TU_TOKEN_DE_AUTENTICACION_AQUI"; // REEMPLAZA ESTO

      await _familiaApi.updateFamilyFotos(
        familyId: familyId!,
        profileImage: profileFile,
        coverImage: coverFile,
        authToken: token, // Pasar el token
      );

      // 3. Mostrar confirmación
      if (context != null) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('¡Imágenes actualizadas con éxito!')),
        );
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
