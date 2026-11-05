import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/api_constants.dart';

/// Inicio de sesión con Google en el teléfono: muestra la hoja del sistema para
/// elegir la cuenta y devuelve el `id_token` que el servidor valida.
class GoogleIdToken {
  /// Se puede sustituir en las pruebas: la hoja de Google es del sistema.
  /// Devuelve null si el cliente cancela.
  static Future<String?> Function() fetch = _fetch;

  /// Cierra la cuenta de Google en el teléfono, para que la próxima vez deje
  /// elegir otra. Si Google no se usó, no hace nada.
  static Future<void> signOut() async {
    if (!_initialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // No es importante.
    }
  }

  static bool _initialized = false;

  static Future<String?> _fetch() async {
    final google = GoogleSignIn.instance;
    if (!_initialized) {
      await google.initialize(serverClientId: ApiConstants.googleServerClientId);
      _initialized = true;
    }

    try {
      final account = await google.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
