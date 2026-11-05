import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/push/push_messaging.dart';
import '../providers/push_provider.dart';
import '../utils/push_route.dart';
import 'lock_gate.dart';

/// Muestra los avisos que llegan con el app abierta (una barra con "Ver") y abre
/// la pantalla correspondiente cuando el cliente toca una notificación.
class PushHost extends StatefulWidget {
  final Widget child;

  const PushHost({super.key, required this.child});

  @override
  State<PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<PushHost> {
  final List<StreamSubscription<PushMessage>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    final push = context.read<PushProvider>();
    _subscriptions
      ..add(push.foreground.listen(_showBanner))
      ..add(push.opened.listen(_open));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  /// El Navigator de la app; el host vive por encima de él.
  NavigatorState? get _navigator => LockGate.navigatorKey.currentState;

  void _open(PushMessage message) {
    final page = PushRoute.pageFor(message);
    if (page == null) return;
    _navigator?.push(MaterialPageRoute(builder: (_) => page));
  }

  void _showBanner(PushMessage message) {
    final context = LockGate.navigatorKey.currentContext;
    if (context == null) return;

    final text = [message.title, message.body].whereType<String>().join(': ');
    if (text.isEmpty) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6),
        action: PushRoute.pageFor(message) == null
            ? null
            : SnackBarAction(label: 'Ver', onPressed: () => _open(message)),
      ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
