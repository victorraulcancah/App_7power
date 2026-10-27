class BannerEntity {
  final int id;
  final String? title;
  final String? subtitle;
  final String? buttonText;

  /// Ruta de la tienda web a la que apunta ("/shop", ...).
  final String? linkUrl;
  final String imageUrl;

  const BannerEntity({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.buttonText,
    this.linkUrl,
  });
}
