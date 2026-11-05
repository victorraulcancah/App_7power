import 'package:local_auth/local_auth.dart';

/// La huella (o el rostro, o el PIN del teléfono) para desbloquear el app.
class BiometricService {
  /// Se pueden sustituir en las pruebas: la huella es del sistema.
  static Future<bool> Function() isSupported = _isSupported;
  static Future<bool> Function(String reason) authenticate = _authenticate;

  static final LocalAuthentication _auth = LocalAuthentication();

  /// El teléfono puede pedir una huella, un rostro o su PIN, y tiene alguno
  /// registrado. Sin eso no se ofrece el bloqueo: dejaría al cliente fuera.
  static Future<bool> _isSupported() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty ||
          await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Muestra la hoja del sistema. Devuelve true solo si el cliente se identificó;
  /// cancelar, fallar o que el sistema se niegue (demasiados intentos) es false.
  static Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Si la huella falla o no está disponible, sirve el PIN del teléfono: así
        // nadie queda fuera de su cuenta.
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}
