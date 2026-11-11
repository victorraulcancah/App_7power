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

  /// "Guardado para después": sigue en la cuenta pero no cuenta en el pedido
  /// ni en el total.
  final bool savedForLater;

  const CartItemEntity({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.stock,
    this.imageUrl,
    this.code,
    this.currency,
    this.savedForLater = false,
  });

  bool get hasPrice => price > 0;
  double get subtotal => price * quantity;

  CartItemEntity copyWith({int? quantity, bool? savedForLater}) => CartItemEntity(
        productId: productId,
        name: name,
        price: price,
        quantity: quantity ?? this.quantity,
        stock: stock,
        imageUrl: imageUrl,
        code: code,
        currency: currency,
        savedForLater: savedForLater ?? this.savedForLater,
      );
}
