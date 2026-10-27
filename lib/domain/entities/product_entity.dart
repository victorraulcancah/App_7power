class ProductEntity {
  final int id;
  final String name;
  final String? code;
  final String? description;
  final String? brand;
  final String? category;
  final int? categoryId;
  final String? imageUrl;

  /// 0 cuando el producto no tiene precio en las listas del cliente.
  final double price;

  /// Código de moneda del backend: 's' (soles) o 'd' (dólares).
  final String? currency;
  final int stock;

  const ProductEntity({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.code,
    this.description,
    this.brand,
    this.category,
    this.categoryId,
    this.imageUrl,
    this.currency,
  });

  bool get hasPrice => price > 0;
  bool get isAvailable => stock > 0;
}
