import 'dart:convert';
import 'dart:io';
import 'package:edi301/auth/token_storage.dart';
import 'package:edi301/services/familia_api.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditController {
  BuildContext? context;
  int? familyId;

  final ImagePicker _picker = ImagePicker();
  final FamiliaApi _familiaApi = FamiliaApi();
  final TokenStorage _tokenStorage = TokenStorage();

  // Notificadores para actualizar la UI cuando se selecciona una imagen
  ValueNotifier<XFile?> profileImage = ValueNotifier(null);
  ValueNotifier<XFile?> coverImage = ValueNotifier(null);
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  final TextEditingController descripcionCtrl = TextEditingController();
  ValueNotifier<bool> descripcionModificada = ValueNotifier(false);

  Future<void> init(BuildContext context, int familyId) async {
    this.context = context;
    this.familyId = familyId;

    print('✅ EditController inicializado con familia ID: $familyId');

    if (familyId <= 0) {
      print('⚠️ ADVERTENCIA: familyId inválido: $familyId');
    }
    await _loadDescripcion();
  }

  Future<void> _loadDescripcion() async {
    try {
      if (familyId == null) return;

      final token = await _tokenStorage.read();
      if (token == null) return;

      final data = await _familiaApi.getById(familyId!, authToken: token);

      if (data != null) {
        final descripcion = data['descripcion'] ?? '';
        descripcionCtrl.text = descripcion;
        print(
          '📝 Descripción cargada: ${descripcion.isEmpty ? "(vacía)" : descripcion}',
        );
      } else {
        print('⚠️ No se encontraron datos para la familia $familyId');
      }
    } catch (e) {
      print('⚠️ Error al cargar descripción: $e');
    }
  }

  void dispose() {
    profileImage.dispose();
    coverImage.dispose();
    isLoading.dispose();
    descripcionCtrl.dispose();
    descripcionModificada.dispose();
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
    print('🔍 Intentando guardar cambios...');
    print('   - familyId: $familyId');
    print('   - profileImage: ${profileImage.value?.path}');
    print('   - coverImage: ${coverImage.value?.path}');

    if (isLoading.value) {
      print('⏸️ Ya hay una operación en curso');
      return;
    }

    if (familyId == null || familyId! <= 0) {
      // 👈 VALIDACIÓN MEJORADA
      print('❌ Error: familyId es null o inválido: $familyId');
      if (context != null && context!.mounted) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('Error: ID de familia no encontrado')),
        );
      }
      return;
    }

    final hayImagenes = profileImage.value != null || coverImage.value != null;
    final hayDescripcion = descripcionModificada.value;

    if (!hayImagenes && !hayDescripcion) {
      if (context != null && context!.mounted) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('No hay cambios para guardar')),
        );
      }
      return;
    }

    isLoading.value = true;

    try {
      String? token = await _tokenStorage.read();

      if (token == null) {
        print('❌ Token no encontrado');
        if (context != null && context!.mounted) {
          ScaffoldMessenger.of(context!).showSnackBar(
            const SnackBar(
              content: Text('Error: Sesión expirada. Vuelve a iniciar sesión.'),
            ),
          );
        }
        isLoading.value = false;
        return;
      }

      // 👇 AÑADE ESTO - Guardar descripción si cambió
      if (hayDescripcion) {
        print('💬 Guardando descripción...');
        await _familiaApi.updateDescripcion(
          familyId: familyId!,
          descripcion: descripcionCtrl.text.trim(),
          authToken: token,
        );
        print('✅ Descripción guardada');
      }

      // Guardar imágenes si hay
      if (hayImagenes) {
        File? profileFile = profileImage.value != null
            ? File(profileImage.value!.path)
            : null;
        File? coverFile = coverImage.value != null
            ? File(coverImage.value!.path)
            : null;

        print('📤 Guardando imágenes...');

        await _familiaApi.updateFamilyFotos(
          familyId: familyId!,
          profileImage: profileFile,
          coverImage: coverFile,
          authToken: token,
        );

        print('✅ Imágenes guardadas');
      }

      print('✅ Todos los cambios guardados exitosamente');

      if (context != null && context!.mounted) {
        ScaffoldMessenger.of(context!).showSnackBar(
          const SnackBar(content: Text('¡Cambios guardados con éxito!')),
        );

        // Opcional: Regresar a la página anterior
        Navigator.pop(context!);
      }
    } catch (e) {
      print('❌ Error al guardar: $e');
      if (context != null && context!.mounted) {
        ScaffoldMessenger.of(
          context!,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      isLoading.value = false;
    }
  }
}
