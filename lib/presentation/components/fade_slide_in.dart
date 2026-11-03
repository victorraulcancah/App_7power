import 'package:flutter/material.dart';

/// Hace aparecer a su hijo con un desvanecido y un leve deslizamiento hacia
/// arriba, una sola vez, cuando entra a la pantalla. Con [delay] varias
/// secciones pueden entrar una tras otra.
class FadeSlideIn extends StatelessWidget {
  /// Las pruebas lo apagan (`test/flutter_test_config.dart`): las animaciones
  /// obligan a esperar cuadros que la mayoría de las pruebas no necesita.
  static bool enabled = true;

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Cuánto sube mientras aparece, en píxeles.
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offset = 18,
  });

  @override
  Widget build(BuildContext context) {
    // Quien pide menos movimiento en el sistema no ve la animación.
    if (!enabled || MediaQuery.disableAnimationsOf(context)) return child;

    final total = delay + duration;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      // El retraso se reparte dentro de la misma animación: es la parte inicial
      // en la que no pasa nada.
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offset),
          child: child,
        ),
      ),
    );
  }
}
