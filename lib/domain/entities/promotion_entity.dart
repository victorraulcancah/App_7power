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

  /// Faltan [days] días o menos para que venza (y aún no venció): la web lo marca
  /// "Por vencer".
  bool expiresSoon(DateTime now, {int days = 7}) {
    final end = endsAt;
    if (end == null) return false;
    final left = end.difference(now);
    return !left.isNegative && left <= Duration(days: days);
  }
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

/// Banner promocional de la portada (`GET /banners-promocionales/publicos`):
/// una imagen con el nombre y el precio de una promoción y un botón.
class PromoBanner {
  final int id;
  final String title;

  /// Texto tal como lo escribe la empresa ("S/ 0.01").
  final String? price;
  final String? buttonText;
  final String? imageUrl;

  /// A dónde lleva el botón (ver `AppLink`).
  final String? linkUrl;

  /// Colores "#RRGGBB" que define la empresa para el botón y las insignias.
  final String? buttonColor;
  final String? nameBadgeColor;
  final String? priceBadgeColor;

  const PromoBanner({
    required this.id,
    required this.title,
    this.price,
    this.buttonText,
    this.imageUrl,
    this.linkUrl,
    this.buttonColor,
    this.nameBadgeColor,
    this.priceBadgeColor,
  });
}

/// Venta flash vigente (`GET /banners-flash-sales/activos`): una oferta por
/// tiempo limitado, con cuenta regresiva hasta [endsAt].
class FlashSale {
  final int id;
  final String name;
  final String? imageUrl;
  final DateTime endsAt;
  final String? buttonText;
  final String? linkUrl;
  final String? buttonColor;
  final String? badgeColor;

  const FlashSale({
    required this.id,
    required this.name,
    required this.endsAt,
    this.imageUrl,
    this.buttonText,
    this.linkUrl,
    this.buttonColor,
    this.badgeColor,
  });

  /// Lo que falta para que termine, o [Duration.zero] si ya terminó.
  Duration remaining(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isActive(DateTime now) => endsAt.isAfter(now);
}
