import '../constants/api_constants.dart';

/// Direcciones de imágenes del backend.
class ImageUrl {
  /// Anchos que sirve el backend (`GET /api/img/{ancho}/{ruta}`); debe coincidir
  /// con `ImagenReducidaController::ANCHOS`.
  static const List<int> widths = [160, 320, 480, 720, 1080];

  /// La versión reducida de [url] para dibujarla a [logicalWidth] píxeles
  /// lógicos, o null si no se puede reducir (otra procedencia, o sin ancho).
  ///
  /// Las fotos originales pesan 1-2 MB; en un celular se dibujan a unos
  /// cientos de píxeles, así que se pide la que alcanza para la densidad de la
  /// pantalla.
  static String? resized(String url, double? logicalWidth, double pixelRatio) {
    const prefix = '${ApiConstants.storageUrl}/';
    if (!url.startsWith(prefix) ||
        logicalWidth == null ||
        !logicalWidth.isFinite ||
        logicalWidth <= 0) {
      return null;
    }

    final needed = logicalWidth * pixelRatio;
    final width = widths.firstWhere((w) => w >= needed, orElse: () => widths.last);
    return '${ApiConstants.baseUrl}/img/$width/${url.substring(prefix.length)}';
  }
}
