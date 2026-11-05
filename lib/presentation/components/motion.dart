import 'package:flutter/material.dart';

/// Hace "rebotar" a su hijo cada vez que [trigger] cambia: se agranda de golpe y
/// vuelve a su tamaño con un rebote. Sirve para llamar la atención sobre algo
/// que acaba de cambiar (el número del carrito, un corazón recién marcado).
class Bounce extends StatefulWidget {
  /// Las pruebas lo apagan (`test/flutter_test_config.dart`).
  static bool enabled = true;

  /// Cualquier valor: cuando cambia, rebota.
  final Object? trigger;
  final Widget child;

  /// Cuánto se agranda en el punto más alto (1.3 = 30 % más grande).
  final double peak;

  const Bounce({
    super.key,
    required this.trigger,
    required this.child,
    this.peak = 1.3,
  });

  @override
  State<Bounce> createState() => _BounceState();
}

class _BounceState extends State<Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    // Sube rápido...
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: widget.peak).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    // ...y vuelve rebotando.
    TweenSequenceItem(
      tween: Tween(begin: widget.peak, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 75,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(Bounce old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger &&
        Bounce.enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Achica un poco a su hijo mientras se lo presiona, para que responda al
/// tacto. No intercepta los toques: el hijo sigue funcionando igual.
class PressScale extends StatefulWidget {
  /// Las pruebas lo apagan (`test/flutter_test_config.dart`).
  static bool enabled = true;

  final Widget child;
  final double scale;

  const PressScale({super.key, required this.child, this.scale = 0.97});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (PressScale.enabled && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
