import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/app_snackbar.dart';

/// Abre [url] fuera de la app (navegador, correo, teléfono...). Si el sistema
/// no puede, avisa en vez de fallar en silencio.
Future<void> openUrl(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    AppSnackbar.error(context, 'No se pudo abrir el enlace.');
  }
}
