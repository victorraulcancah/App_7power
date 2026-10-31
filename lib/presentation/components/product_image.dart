import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen de red con indicador de carga y placeholder si falla o no hay URL.
///
/// Se guarda en disco: las imágenes del catálogo pesan cientos de KB y sin
/// esto se descargaban de nuevo cada vez que se abría la app. Además se
/// decodifica al tamaño con que se dibuja, no al de la imagen original.
class ProductImage extends StatelessWidget {
  /// Guardar las imágenes en disco. Las pruebas lo apagan (`test/flutter_test_config.dart`):
  /// no tienen los plugins de almacenamiento que necesita la caché.
  static bool diskCache = true;

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProductImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.outline,
      ),
    );

    final spinner = SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );

    final Widget image = (url == null || url!.isEmpty)
        ? placeholder
        : !diskCache
            ? Image.network(
                url!,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : spinner,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final drawnWidth = width ??
                      (constraints.hasBoundedWidth ? constraints.maxWidth : null);
                  final pixelRatio = MediaQuery.devicePixelRatioOf(context);

                  return CachedNetworkImage(
                    imageUrl: url!,
                    width: width,
                    height: height,
                    fit: fit,
                    memCacheWidth: drawnWidth == null || !drawnWidth.isFinite
                        ? null
                        : (drawnWidth * pixelRatio).round(),
                    fadeInDuration: const Duration(milliseconds: 150),
                    errorWidget: (_, _, _) => placeholder,
                    progressIndicatorBuilder: (_, _, _) => spinner,
                  );
                },
              );

    return borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
