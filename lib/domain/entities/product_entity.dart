class ProductEntity {
  final int id;
  final String name;
  final String? code;
  final String? description;
  final String? brand;
  final String? category;
  final int? categoryId;
  final String? imageUrl;

  /// Precio según la lista del cliente (o la de visitantes). 0 si el producto
  /// no tiene precio en esa lista.
  final double price;

  /// Código de moneda del backend: 's' (soles) o 'd' (dólares).
  final String? currency;
  final int stock;

  /// false cuando el invitado no tiene ninguna lista de precios: el precio se
  /// oculta ("Precio solo para clientes") y se pide iniciar sesión.
  final bool priceVisible;

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
    this.priceVisible = true,
  });

  bool get isAvailable => stock > 0;

  /// El mismo producto con otro precio/moneda (selector de moneda del detalle).
  ProductEntity copyWith({double? price, String? currency}) => ProductEntity(
        id: id,
        name: name,
        price: price ?? this.price,
        stock: stock,
        code: code,
        description: description,
        brand: brand,
        category: category,
        categoryId: categoryId,
        imageUrl: imageUrl,
        currency: currency ?? this.currency,
        priceVisible: priceVisible,
      );
}
