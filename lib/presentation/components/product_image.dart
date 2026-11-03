import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/image_url.dart';

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

  /// Qué mostrar si no hay imagen o no carga (por defecto, un ícono gris). Los
  /// logos usan su nombre en texto.
  final Widget? fallback;

  /// Sin spinner mientras carga: para logos chicos que no deben saltar.
  final bool showSpinner;

  const ProductImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
    this.showSpinner = true,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = fallback ??
        Container(
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
      child: showSpinner
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
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
                  // Con ancho "infinito" (a todo el ancho) se usa el que da el
                  // padre, para decodificar a ese tamaño.
                  final drawnWidth = (width != null && width!.isFinite)
                      ? width
                      : (constraints.hasBoundedWidth ? constraints.maxWidth : null);
                  final pixelRatio = MediaQuery.devicePixelRatioOf(context);
                  final memCacheWidth = drawnWidth == null || !drawnWidth.isFinite
                      ? null
                      : (drawnWidth * pixelRatio).round();

                  CachedNetworkImage network(String imageUrl, WidgetBuilder? onError) =>
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: width,
                        height: height,
                        fit: fit,
                        memCacheWidth: memCacheWidth,
                        fadeInDuration: const Duration(milliseconds: 150),
                        errorWidget: (context, _, _) =>
                            onError == null ? placeholder : onError(context),
                        progressIndicatorBuilder: (_, _, _) => spinner,
                      );

                  // Se pide la versión reducida; si el backend aún no la ofrece
                  // (o falla), se usa la original en lugar de dejar un hueco.
                  final resized = ImageUrl.resized(url!, drawnWidth, pixelRatio);
                  return resized == null
                      ? network(url!, null)
                      : network(resized, (_) => network(url!, null));
                },
              );

    return borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
