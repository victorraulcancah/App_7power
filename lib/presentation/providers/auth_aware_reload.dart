import 'package:flutter/foundation.dart';

/// Para providers cuyos datos dependen de quién está logueado.
///
/// El backend resuelve precio y moneda según el cliente (su lista de precios),
/// así que al iniciar o cerrar sesión lo ya cargado como invitado queda
/// desactualizado y hay que pedirlo de nuevo.
mixin AuthAwareReload on ChangeNotifier {
  bool? _lastAuthenticated;

  /// Si la última sesión conocida estaba iniciada (false mientras no se sepa).
  bool get isAuthenticated => _lastAuthenticated ?? false;

  /// Vuelve a pedir los datos que dependen del cliente.
  Future<void> reloadForAuthChange();

  void onAuthChanged({required bool known, required bool authenticated}) {
    if (!known || _lastAuthenticated == authenticated) return;
    final isFirst = _lastAuthenticated == null;
    _lastAuthenticated = authenticated;

    // Como invitado al abrir la app ya se cargó lo correcto; si lo primero que
    // se sabe es que hay una sesión restaurada, lo cargado antes de saberlo era
    // de invitado y hay que repetirlo.
    if (isFirst && !authenticated) return;

    // Se difiere para no notificar mientras el árbol de widgets se construye.
    Future.microtask(reloadForAuthChange);
  }
}
