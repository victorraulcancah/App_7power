/// Cupón activo (`GET /cupones/activos`): se escribe su código en el checkout.
class CouponOffer {
  final int id;
  final String code;
  final String title;
  final String? description;

  /// true: [value] es un porcentaje; false: un monto fijo en soles.
  final bool isPercentage;
  final double value;
  final double? minPurchase;
  final DateTime? endsAt;
  final bool firstPurchaseOnly;

  const CouponOffer({
    required this.id,
    required this.code,
    required this.title,
    required this.isPercentage,
    required this.value,
    this.description,
    this.minPurchase,
    this.endsAt,
    this.firstPurchaseOnly = false,
  });
}

/// Producto del banner de ofertas, con su descuento.
class OfferProduct {
  final int id;
  final String name;
  final double price;
  final double discountPrice;
  final double discountPercent;
  final String? imageUrl;
  final int stock;
  final String? currency;
  final String? brand;

  const OfferProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.discountPrice,
    required this.discountPercent,
    this.imageUrl,
    this.stock = 0,
    this.currency,
    this.brand,
  });
}

/// Banner de ofertas activo (`GET /banners-ofertas/activo`).
class OfferBanner {
  final String? imageUrl;
  final List<OfferProduct> products;

  const OfferBanner({this.imageUrl, this.products = const []});

  /// Sin banner ni productos: no hay nada que mostrar.
  bool get isEmpty => imageUrl == null && products.isEmpty;
}
