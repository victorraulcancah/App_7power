import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Pantalla de carga de la tienda, igual a la de la web: fondo de la empresa
/// (`splash_color_fondo`), su logo girando y flotando con brillo rojo, ondas
/// que se expanden y el texto (`splash_texto`) en mayúsculas.
class SplashScreen extends StatefulWidget {
  /// Fondo cuando la empresa aún no lo define (o no se conoce todavía).
  static const Color defaultBackground = Color(0xFF000000);
  static const String defaultText = 'Cargando...';

  /// Rojo de la marca que usa la web para los brillos.
  static const Color _glow = Color(0xFFFE2E33);

  final Color background;
  final String? logoUrl;
  final String text;

  const SplashScreen({
    super.key,
    this.background = defaultBackground,
    this.logoUrl,
    this.text = defaultText,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Una vuelta completa dura el mínimo común de los ciclos de la web: giro
  /// 4 s, ondas y texto 2 s, flotado 3 s.
  static const _cycle = Duration(seconds: 12);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fase 0..1 de una animación que dura [seconds] segundos y se repite.
  double _phase(double seconds) =>
      (_controller.value * _cycle.inSeconds % seconds) / seconds;

  /// Fase de una animación "alternate": sube y baja suavemente 0 → 1 → 0.
  double _pingPong(double seconds) {
    final t = _phase(seconds);
    return Curves.easeInOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
  }

  /// Giro de la web: 360° en 4 s, con un leve agrandado a los 90° y 270°.
  double _spinScale(double t) {
    final distance = (t % 0.5 - 0.25).abs();
    return 1 + 0.08 * (1 - distance / 0.25);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width <= 480;
    final logoWidth = math.min(compact ? 150.0 : 200.0, size.width * 0.5);
    final logoHeight = logoWidth / 2;

    return ColoredBox(
      color: widget.background,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final spin = _phase(4);
          final glow = _pingPong(2);
          final float = _pingPong(3) * -10;
          final text = _pingPong(2);

          return Stack(
            alignment: Alignment.center,
            children: [
              _Wave(progress: _phase(2), strength: 0.15),
              _Wave(progress: (_phase(2) - 0.25) % 1, strength: 0.08),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, float),
                    child: Transform.rotate(
                      angle: spin * 2 * math.pi,
                      child: Transform.scale(
                        scale: _spinScale(spin),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(logoHeight),
                            boxShadow: [
                              BoxShadow(
                                color: SplashScreen._glow.withValues(
                                  alpha: 0.08 + 0.22 * glow,
                                ),
                                blurRadius: 30 + 25 * glow,
                                spreadRadius: 4 + 8 * glow,
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: logoWidth,
                            height: logoHeight,
                            child: BrandLogo(
                              url: widget.logoUrl,
                              height: logoHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 22 : 24),
                  Opacity(
                    opacity: 0.7 + 0.3 * text,
                    // Con su propia capa: el texto con sombra no admite la
                    // opacidad "heredada" y Impeller avisa en el registro.
                    child: RepaintBoundary(
                      child: Text(
                        widget.text.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 13 : 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          decoration: TextDecoration.none,
                          shadows: [
                            Shadow(
                              color: SplashScreen._glow.withValues(
                                alpha: 0.3 + 0.5 * text,
                              ),
                              blurRadius: 10 + 10 * text,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Onda roja que se expande desde el centro y se desvanece (de 200 a 450 px).
class _Wave extends StatelessWidget {
  final double progress;
  final double strength;

  const _Wave({required this.progress, required this.strength});

  @override
  Widget build(BuildContext context) {
    final diameter = 200 + 250 * progress;
    return Opacity(
      opacity: 1 - progress,
      child: RepaintBoundary(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                SplashScreen._glow.withValues(alpha: strength),
                SplashScreen._glow.withValues(alpha: 0),
              ],
              stops: const [0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}
