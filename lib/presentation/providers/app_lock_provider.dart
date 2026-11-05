import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/security/biometric_service.dart';

/// Bloqueo del app con la huella: cuando está activo, al abrir el app (y al
/// volver a ella tras un rato) hay que identificarse antes de ver la cuenta.
/// Solo se aplica a quien tiene la sesión iniciada.
class AppLockProvider extends ChangeNotifier {
  static const _enabledKey = 'biometric_lock_v1';
  static const _offeredKey = 'biometric_lock_offered_v1';

  /// Cuánto tiempo puede estar el app en segundo plano antes de volver a
  /// pedir la huella.
  static const Duration relockAfter = Duration(seconds: 60);

  final DateTime Function() _now;

  AppLockProvider({DateTime Function()? now}) : _now = now ?? DateTime.now;

  bool _enabled = false;
  bool _locked = false;
  bool _available = false;
  bool _offered = false;
  bool _loaded = false;
  bool _authenticating = false;
  DateTime? _leftAt;

  /// El bloqueo está activado en este teléfono.
  bool get enabled => _enabled;

  /// El app está bloqueada ahora mismo (si hay sesión, se muestra el bloqueo).
  bool get locked => _locked;

  /// El teléfono puede identificar al cliente (huella, rostro o PIN).
  bool get available => _available;

  bool get isAuthenticating => _authenticating;

  /// Ya se leyó lo guardado. Hasta entonces no se sabe si hay que bloquear.
  bool get isLoaded => _loaded;

  /// Lee lo guardado y, si el bloqueo estaba activo, arranca bloqueada.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _offered = prefs.getBool(_offeredKey) ?? false;
    _available = await BiometricService.isSupported();

    // Si el teléfono ya no puede identificar (se quitó la huella y el PIN), el
    // bloqueo se apaga: de lo contrario nadie podría entrar.
    if (_enabled && !_available) {
      _enabled = false;
      await prefs.setBool(_enabledKey, false);
    }

    _locked = _enabled;
    _loaded = true;
    notifyListeners();
  }

  /// Pide la huella. Si el cliente se identifica, el app se desbloquea.
  Future<bool> unlock() async {
    if (_authenticating) return false;
    _authenticating = true;
    notifyListeners();

    final ok = await BiometricService.authenticate(
      'Desbloquea 7Power para ver tu cuenta',
    );

    _authenticating = false;
    if (ok) _locked = false;
    notifyListeners();
    return ok;
  }

  /// Activa o desactiva el bloqueo. Para cambiarlo hay que identificarse, así
  /// nadie más puede apagarlo con el teléfono desbloqueado. Devuelve el estado
  /// en que quedó.
  Future<bool> setEnabled(bool value) async {
    if (value == _enabled) return _enabled;
    if (value && !_available) return _enabled;

    final ok = await BiometricService.authenticate(
      value
          ? 'Confirma tu huella para activar el bloqueo'
          : 'Confirma tu huella para desactivar el bloqueo',
    );
    if (!ok) return _enabled;

    _enabled = value;
    // Quien acaba de activarlo ya se identificó: no se bloquea al instante.
    _locked = false;
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, value);
    notifyListeners();
    return _enabled;
  }

  /// Si conviene ofrecer el bloqueo (una sola vez, tras iniciar sesión).
  bool get shouldOffer => _loaded && _available && !_enabled && !_offered;

  /// Anota que ya se ofreció, para no insistir.
  Future<void> markOffered() async {
    _offered = true;
    await (await SharedPreferences.getInstance()).setBool(_offeredKey, true);
  }

  /// Cierre de sesión: no hay nada que proteger hasta la próxima.
  void onLoggedOut() {
    if (_locked) {
      _locked = false;
      notifyListeners();
    }
  }

  /// El app pasó a segundo plano.
  void onBackgrounded() => _leftAt = _now();

  /// El app volvió al frente: si estuvo fuera un rato, se bloquea.
  void onResumed() {
    final left = _leftAt;
    _leftAt = null;
    if (!_enabled || left == null || _locked) return;
    if (_now().difference(left) >= relockAfter) {
      _locked = true;
      notifyListeners();
    }
  }
}
