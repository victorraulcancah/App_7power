import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/components.dart';
import '../providers/app_lock_provider.dart';

/// La oferta, una sola vez tras iniciar sesión, de entrar con la huella.
class BiometricOffer {
  /// Pregunta si se quiere activar el bloqueo con huella, si el teléfono puede y
  /// aún no se preguntó. Si el cliente acepta, se le pide la huella una vez
  /// para confirmar.
  static Future<void> maybeShow(BuildContext context) async {
    final lock = context.read<AppLockProvider>();
    if (!lock.shouldOffer) return;

    // Se anota antes de preguntar: no se vuelve a insistir, responda lo que
    // responda (se puede activar luego desde Mi cuenta).
    await lock.markOffered();
    if (!context.mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.fingerprint_rounded,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('¿Entrar con tu huella?'),
        content: const Text(
          'Protege tu cuenta: al abrir el app te pediremos tu huella. '
          'Puedes cambiarlo cuando quieras en Mi cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;

    final enabled = await lock.setEnabled(true);
    if (context.mounted && enabled) {
      AppSnackbar.success(context, 'Bloqueo con huella activado');
    }
  }
}
