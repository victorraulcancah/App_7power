import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/components.dart';
import '../providers/app_lock_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';
import 'biometric_offer.dart';

/// Pone el bloqueo con huella por encima de todo el app (pantallas, hojas y
/// diálogos incluidos) cuando corresponde: bloqueo activo y sesión iniciada.
///
/// También avisa al bloqueo cuando el app pasa a segundo plano y vuelve, para
/// pedir la huella otra vez tras un rato fuera.
class LockGate extends StatefulWidget {
  /// El Navigator de la app. El bloqueo vive por encima de él, así que para abrir
  /// diálogos necesita su contexto.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final Widget child;

  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  int _seenLogins = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = context.read<AppLockProvider>();
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        lock.onBackgrounded();
      case AppLifecycleState.resumed:
        lock.onResumed();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();
    final status = context.select<AuthProvider, AuthStatus>((a) => a.status);
    final authenticated = status == AuthStatus.authenticated;

    // Justo después de iniciar sesión (no al restaurarla al abrir el app) se
    // ofrece, una sola vez, entrar con la huella.
    final logins = context.select<AuthProvider, int>((a) => a.loginCount);
    if (logins > _seenLogins) {
      _seenLogins = logins;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = LockGate.navigatorKey.currentContext;
        if (mounted && navigator != null) BiometricOffer.maybeShow(navigator);
      });
    }

    // Al cerrar sesión el bloqueo se libera (no hay nada que proteger).
    if (!authenticated && lock.locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppLockProvider>().onLoggedOut();
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (lock.locked && authenticated) const LockScreen(),
      ],
    );
  }
}

/// Pantalla de bloqueo: pide la huella al aparecer y deja reintentar o salir de
/// la cuenta (y entrar con la contraseña).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    // La hoja de la huella aparece sola, sin tener que tocar nada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppLockProvider>().unlock();
    });
  }

  Future<void> _logout() async {
    final lock = context.read<AppLockProvider>();
    await context.read<AuthProvider>().logout();
    lock.onLoggedOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lock = context.watch<AppLockProvider>();
    final logo = context.select<CompanyProvider, String?>((c) => c.info?.logoUrl);

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(url: logo, height: 56),
                const SizedBox(height: 36),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'La app está bloqueada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usa tu huella para ver tu cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: lock.isAuthenticating ? null : lock.unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(lock.isAuthenticating ? 'Verificando...' : 'Desbloquear'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _logout,
                  child: const Text(
                    'Cerrar sesión y usar mi contraseña',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
