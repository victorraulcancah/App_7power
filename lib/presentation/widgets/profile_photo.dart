import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/user_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';

enum PhotoSource { camera, gallery }

/// Elige una foto de la cámara o de la galería. Devuelve la ruta del archivo,
/// o null si se canceló.
class ProfilePhotoPicker {
  /// Se puede sustituir en las pruebas: la cámara y la galería son del sistema.
  static Future<String?> Function(PhotoSource source) pick = _pick;

  static Future<String?> _pick(PhotoSource source) async {
    final file = await ImagePicker().pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      // El servidor acepta hasta 2 MB: una foto de 1080 px con compresión media
      // pesa unos cientos de KB.
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    return file?.path;
  }
}

/// El cambio de foto de perfil: la hoja con las opciones, la subida y el aviso
/// del resultado.
class ProfilePhoto {
  /// Muestra las opciones (cámara, galería y, si ya hay foto, quitarla) y hace lo
  /// que se elija.
  static Future<void> change(BuildContext context) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PhotoSheet(hasPhoto: user.photoUrl != null),
    );
    if (choice == null || !context.mounted) return;

    final auth = context.read<AuthProvider>();

    if (choice == _Choice.remove) {
      final error = await _withProgress(context, auth.removePhoto);
      if (!context.mounted) return;
      error == null
          ? AppSnackbar.success(context, 'Quitaste tu foto de perfil')
          : AppSnackbar.error(context, error);
      return;
    }

    final String? path;
    try {
      path = await ProfilePhotoPicker.pick(
        choice == _Choice.camera ? PhotoSource.camera : PhotoSource.gallery,
      );
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, 'No se pudo abrir la cámara o la galería.');
      }
      return;
    }
    if (path == null || !context.mounted) return;

    final error = await _withProgress(context, () => auth.updatePhoto(path!));
    if (!context.mounted) return;
    error == null
        ? AppSnackbar.success(context, 'Foto de perfil actualizada')
        : AppSnackbar.error(context, error);
  }

  /// Corre [action] con un indicador de carga encima, para que no se toque nada
  /// mientras se sube.
  static Future<String?> _withProgress(
    BuildContext context,
    Future<String?> Function() action,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      return await action();
    } finally {
      navigator.pop();
    }
  }
}

enum _Choice { camera, gallery, remove }

class _PhotoSheet extends StatelessWidget {
  final bool hasPhoto;

  const _PhotoSheet({required this.hasPhoto});

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, _Choice.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(context, _Choice.gallery),
          ),
          if (hasPhoto)
            ListTile(
              leading: Icon(Icons.delete_outline, color: error),
              title: Text('Quitar foto', style: TextStyle(color: error)),
              onTap: () => Navigator.pop(context, _Choice.remove),
            ),
        ],
      ),
    );
  }
}

/// El avatar del cliente (su foto o sus iniciales) con una cámara en la esquina:
/// al tocarlo se cambia la foto.
class ProfileAvatar extends StatelessWidget {
  final UserEntity user;
  final double radius;

  /// Colores del círculo cuando se muestran las iniciales.
  final Color background;
  final Color foreground;

  const ProfileAvatar({
    super.key,
    required this.user,
    this.radius = 34,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      child: GestureDetector(
        onTap: () => ProfilePhoto.change(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: background,
              foregroundColor: foreground,
              foregroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              // Si la foto no carga se ven las iniciales.
              onForegroundImageError: user.photoUrl != null ? (_, _) {} : null,
              child: Text(
                user.initials,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: radius * 0.6),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: radius * 0.42,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
