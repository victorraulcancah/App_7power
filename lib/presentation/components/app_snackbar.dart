import 'package:flutter/material.dart';

/// Avisos breves. Reemplaza el SnackBar anterior para no apilarlos.
class AppSnackbar {
  static void success(BuildContext context, String message) =>
      _show(context, message, Colors.green.shade700, Icons.check_circle_outline);

  static void error(BuildContext context, String message) => _show(
      context, message, Theme.of(context).colorScheme.error, Icons.error_outline);

  static void info(BuildContext context, String message) =>
      _show(context, message, Colors.blue.shade700, Icons.info_outline);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
