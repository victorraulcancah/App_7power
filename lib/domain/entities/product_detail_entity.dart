import 'product_entity.dart';

/// Precio del producto en una de las monedas que le corresponden al cliente.
class CurrencyOption {
  /// 's' (soles) o 'd' (dólares).
  final String currency;
  final double price;

  const CurrencyOption({required this.currency, required this.price});
}

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

  /// Más de una opción => la ficha muestra el selector S/ - US$.
  final List<CurrencyOption> currencyOptions;

  const ProductDetailEntity({
    required this.product,
    this.images = const [],
    this.longDescription,
    this.specifications,
    this.technicalFeatures,
    this.warranty,
    this.related = const [],
    this.currencyOptions = const [],
  });

  /// Secciones de texto que tienen contenido, en el orden en que se muestran.
  Map<String, String> get sections => {
        'Descripción': ?longDescription,
        'Especificaciones': ?specifications,
        'Características técnicas': ?technicalFeatures,
        'Garantía': ?warranty,
      };
}
