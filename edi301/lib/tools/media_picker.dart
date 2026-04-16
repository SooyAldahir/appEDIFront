import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaPicker {
  MediaPicker._();

  static final ImagePicker _picker = ImagePicker();

  /// Muestra un bottom sheet para elegir Cámara o Galería
  /// y regresa el XFile (o null si cancelan).
  static Future<XFile?> pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return null;

    // Cámara: siempre necesita permiso explícito
    if (source == ImageSource.camera) {
      final ok = await _ensureCameraPermission(context);
      if (!ok) return null;
    }
    // Galería en Android 13+: image_picker usa el Photo Picker del sistema,
    // NO requiere READ_MEDIA_IMAGES ni storage. Solo en iOS pedimos permiso.
    else if (Platform.isIOS) {
      final ok = await _ensurePhotosPermissionIOS(context);
      if (!ok) return null;
    }

    return _picker.pickImage(source: source, imageQuality: 85);
  }

  // ── Cámara ────────────────────────────────────────────────────────────────
  static Future<bool> _ensureCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      await _showSettingsDialog(context);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de cámara denegado')),
      );
    }
    return false;
  }

  // ── Galería iOS ───────────────────────────────────────────────────────────
  static Future<bool> _ensurePhotosPermissionIOS(BuildContext context) async {
    final status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      await _showSettingsDialog(context);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de fotos denegado')),
      );
    }
    return false;
  }

  static Future<void> _showSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permiso requerido'),
        content: const Text(
          'Para continuar necesitas habilitar el permiso en Ajustes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
  }
}
