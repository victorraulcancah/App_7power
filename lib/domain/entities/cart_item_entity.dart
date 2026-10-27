class CartItemEntity {
  final int productId;
  final String name;
  final String? imageUrl;
  final String? code;

  /// 0 si el producto no tiene precio para este cliente.
  final double price;

  /// 's' (soles) o 'd' (dólares).
  final String? currency;
  final int quantity;

  /// Stock disponible al momento de agregarlo; limita la cantidad.
  final int stock;

  const CartItemEntity({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.stock,
    this.imageUrl,
    this.code,
    this.currency,
  });

  bool get hasPrice => price > 0;
  double get subtotal => price * quantity;

  CartItemEntity copyWith({int? quantity}) => CartItemEntity(
        productId: productId,
        name: name,
        price: price,
        quantity: quantity ?? this.quantity,
        stock: stock,
        imageUrl: imageUrl,
        code: code,
        currency: currency,
      );
}
