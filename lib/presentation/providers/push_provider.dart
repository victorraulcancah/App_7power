import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/push/push_messaging.dart';
import '../../data/datasources/push_remote_datasource.dart';
import 'auth_provider.dart';

/// Notificaciones push del cliente: registra su teléfono en el servidor cuando
/// inicia sesión, lo quita al cerrarla y entrega los avisos que llegan.
///
/// Es opcional de punta a punta: si el app no está configurada con Firebase o el
/// cliente no da permiso, no hace nada y todo lo demás funciona igual.
class PushProvider extends ChangeNotifier {
  final PushMessaging messaging;
  final PushRemoteDataSource remote;

  PushProvider({required this.messaging, required this.remote});

  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  final List<StreamSubscription<void>> _subscriptions = [];

  String? _token;
  bool _active = false;
  bool _starting = false;
  bool? _wasAuthenticated;
  AuthProvider? _auth;

  /// Llegó un aviso con el app abierta.
  Stream<PushMessage> get foreground => _foreground.stream;

  /// El cliente tocó un aviso (o el aviso abrió el app).
  Stream<PushMessage> get opened => _opened.stream;

  /// Este teléfono está registrado para recibir avisos.
  bool get active => _active;

  /// Se engancha a la sesión: cuando el cliente entra se registra el teléfono, y
  /// antes de cerrar la sesión se quita (todavía con el permiso de ese cliente).
  void attach(AuthProvider auth) {
    if (!identical(_auth, auth)) {
      _auth = auth;
      auth.addLogoutHook(unregister);
    }
    onAuthChanged(auth.isAuthenticated);
  }

  Future<void> onAuthChanged(bool authenticated) async {
    if (authenticated == _wasAuthenticated) return;
    _wasAuthenticated = authenticated;

    if (authenticated) {
      await _start();
    } else {
      _stopListening();
    }
  }

  Future<void> _start() async {
    if (_active || _starting) return;
    _starting = true;
    try {
      if (!await messaging.init()) return;

      final token = await messaging.token();
      if (token != null) {
        _token = token;
        await _register(token);
      }

      _subscriptions
        ..add(messaging.onTokenRefresh.listen((t) {
          _token = t;
          _register(t);
        }))
        ..add(messaging.onForeground.listen(_foreground.add))
        ..add(messaging.onOpened.listen(_opened.add));

      // Si el aviso abrió el app desde cero, se entrega como "tocado".
      final initial = await messaging.initialMessage();
      if (initial != null) _opened.add(initial);

      _active = true;
      notifyListeners();
    } catch (_) {
      // Sin notificaciones; el resto del app sigue igual.
    } finally {
      _starting = false;
    }
  }

  /// Registra el teléfono en el servidor. Si falla (sin red) se reintenta en el
  /// próximo inicio de sesión o cuando Firebase renueve el identificador.
  Future<void> _register(String token) async {
    try {
      await remote.register(token);
    } catch (_) {}
  }

  /// Quita este teléfono del cliente que cierra sesión, para que sus avisos no
  /// sigan llegando aquí.
  Future<void> unregister() async {
    final token = _token;
    _token = null;
    _stopListening();

    if (token != null) {
      try {
        await remote.unregister(token);
      } catch (_) {}
      try {
        await messaging.deleteToken();
      } catch (_) {}
    }
  }

  void _stopListening() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    if (_active) {
      _active = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopListening();
    _foreground.close();
    _opened.close();
    super.dispose();
  }
}
