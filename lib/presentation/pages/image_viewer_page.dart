import 'package:flutter/material.dart';

import '../components/product_image.dart';

/// Visor de imágenes a pantalla completa: se desliza entre las fotos del
/// producto y se amplía con dos dedos o con doble toque.
class ImageViewerPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const ImageViewerPage({super.key, required this.images, this.initialIndex = 0});

  static Future<void> open(
    BuildContext context,
    List<String> images, {
    int initialIndex = 0,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageViewerPage(images: images, initialIndex: initialIndex),
      ));

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// Si la foto actual está ampliada, el deslizado de lado mueve la foto y no
  /// cambia de página.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / $total'),
      ),
      body: PageView.builder(
        controller: _pages,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: total,
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = false;
        }),
        itemBuilder: (context, i) => ZoomableImage(
          // Al cambiar de foto se vuelve a empezar sin ampliar.
          key: ValueKey(widget.images[i]),
          url: widget.images[i],
          onZoomChanged: (zoomed) {
            if (i == _index && zoomed != _zoomed) setState(() => _zoomed = zoomed);
          },
        ),
      ),
    );
  }
}

/// Una imagen que se amplía con pellizco o con doble toque (alterna entre el
/// tamaño normal y 2.5 veces).
class ZoomableImage extends StatefulWidget {
  static const double zoomedScale = 2.5;

  final String url;
  final ValueChanged<bool>? onZoomChanged;

  const ZoomableImage({super.key, required this.url, this.onZoomChanged});

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;
  Offset _doubleTapAt = Offset.zero;

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_notify);
    _animation.addListener(() {
      final value = _zoomAnimation?.value;
      if (value != null) _transform.value = value;
    });
  }

  bool _lastZoomed = false;

  void _notify() {
    final zoomed = _isZoomed;
    if (zoomed != _lastZoomed) {
      _lastZoomed = zoomed;
      widget.onZoomChanged?.call(zoomed);
    }
  }

  @override
  void dispose() {
    _transform.removeListener(_notify);
    _transform.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final begin = _transform.value;
    final Matrix4 end;
    if (_isZoomed) {
      end = Matrix4.identity();
    } else {
      // Se amplía alrededor del punto tocado.
      const scale = ZoomableImage.zoomedScale;
      end = Matrix4.identity()
        ..translateByDouble(
          -_doubleTapAt.dx * (scale - 1),
          -_doubleTapAt.dy * (scale - 1),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _zoomAnimation = Matrix4Tween(begin: begin, end: end)
        .animate(CurvedAnimation(parent: _animation, curve: Curves.easeOut));
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: ProductImage(url: widget.url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
