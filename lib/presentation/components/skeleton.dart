import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Hace brillar a su hijo con una franja de luz que lo recorre, el efecto de las
/// pantallas "esqueleto" mientras carga el contenido. El hijo debe dibujarse en
/// un color opaco (ver [SkeletonBox]): el brillo se pinta encima.
class Shimmer extends StatefulWidget {
  /// Las pruebas lo apagan (`test/flutter_test_config.dart`): una animación sin
  /// fin impide que `pumpAndSettle` termine.
  static bool animate = true;

  static const Color base = Color(0xFFE9E9ED);
  static const Color highlight = Color(0xFFF8F8FA);

  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = Shimmer.animate && !MediaQuery.disableAnimationsOf(context);
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Shimmer.base, Shimmer.highlight, Shimmer.base],
          stops: const [0.3, 0.5, 0.7],
          transform: _SlideTransform(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

/// Desplaza el degradado de izquierda a derecha según [progress] (0 a 1).
class _SlideTransform extends GradientTransform {
  final double progress;

  const _SlideTransform(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}

/// Un bloque gris para marcar donde irá un texto o una imagen.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Opaco: el brillo de [Shimmer] se pinta sobre este color.
        color: Shimmer.base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// El hueco de una tarjeta de producto mientras carga: imagen y tres líneas.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Sin fondo ni borde: el brillo pinta todo lo opaco, y una tarjeta blanca
    // se vería gris. Solo van los bloques (imagen y líneas de texto).
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SkeletonBox(
            width: double.infinity,
            radius: AppConstants.defaultBorderRadius,
          ),
        ),
        SizedBox(height: 12),
        SkeletonBox(width: 60, height: 10),
        SizedBox(height: 8),
        SkeletonBox(width: double.infinity, height: 12),
        SizedBox(height: 6),
        SkeletonBox(width: 110, height: 12),
        SizedBox(height: 10),
        SkeletonBox(width: 80, height: 16),
        SizedBox(height: 4),
      ],
    );
  }
}

/// Cuadrícula de [count] tarjetas de producto vacías, con el mismo formato que
/// la tienda, para llenar el espacio mientras llegan los productos.
class ProductGridSkeleton extends StatelessWidget {
  final int count;

  /// Dentro de otra lista (sin scroll propio).
  final bool shrinkWrap;

  const ProductGridSkeleton({super.key, this.count = 6, this.shrinkWrap = false});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 0.56,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: count,
        itemBuilder: (context, _) => const ProductCardSkeleton(),
      ),
    );
  }
}

/// La portada vacía mientras carga: buscador, banner, categorías y productos.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const pad = AppConstants.defaultPadding;

    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: double.infinity, height: 52, radius: 28),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 2.2,
              child: const SkeletonBox(width: double.infinity, radius: 16),
            ),
            const SizedBox(height: 22),
            const SkeletonBox(width: 130, height: 16),
            const SizedBox(height: 12),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) =>
                    const SkeletonBox(width: 96, height: 104, radius: 20),
              ),
            ),
            const SizedBox(height: 22),
            const SkeletonBox(width: 170, height: 16),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: Row(
                children: const [
                  Expanded(child: ProductCardSkeleton()),
                  SizedBox(width: 12),
                  Expanded(child: ProductCardSkeleton()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
