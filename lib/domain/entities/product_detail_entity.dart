import 'product_entity.dart';

/// Ficha completa de un producto.
class ProductDetailEntity {
  final ProductEntity product;

  /// Imagen principal primero, luego las de la galería.
  final List<String> images;
  final String? longDescription;
  final String? specifications;
  final String? technicalFeatures;
  final String? warranty;
  final List<ProductEntity> related;

  const ProductDetailEntity({
    required this.product,
    this.images = const [],
    this.longDescription,
    this.specifications,
    this.technicalFeatures,
    this.warranty,
    this.related = const [],
  });

  /// Secciones de texto que tienen contenido, en el orden en que se muestran.
  Map<String, String> get sections => {
        'Descripción': ?longDescription,
        'Especificaciones': ?specifications,
        'Características técnicas': ?technicalFeatures,
        'Garantía': ?warranty,
      };
}
