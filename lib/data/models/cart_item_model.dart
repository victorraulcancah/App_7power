import '../../core/utils/format_utils.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/product_entity.dart';

class CartItemModel extends CartItemEntity {
  const CartItemModel({
    required super.productId,
    required super.name,
    required super.price,
    required super.quantity,
    required super.stock,
    super.imageUrl,
    super.code,
    super.currency,
  });

  /// Elemento de `GET /cart`.
  factory CartItemModel.fromApi(Map<String, dynamic> json) => CartItemModel(
        productId: (json['producto_id'] as num).toInt(),
        name: json['nombre']?.toString() ?? '',
        imageUrl: json['imagen_url']?.toString(),
        code: json['codigo_producto']?.toString(),
        price: FormatUtils.toDouble(json['precio']),
        currency: json['moneda']?.toString(),
        quantity: (json['cantidad'] as num).toInt(),
        stock: (json['stock_disponible'] as num?)?.toInt() ?? 0,
      );

  /// Carrito de invitado: se guarda con los datos del producto porque no hay
  /// servidor que los resuelva.
  factory CartItemModel.fromProduct(ProductEntity product, int quantity) =>
      CartItemModel(
        productId: product.id,
        name: product.name,
        imageUrl: product.imageUrl,
        code: product.code,
        price: product.price,
        currency: product.currency,
        quantity: quantity,
        stock: product.stock,
      );

  factory CartItemModel.fromLocal(Map<String, dynamic> json) => CartItemModel(
        productId: (json['productId'] as num).toInt(),
        name: json['name']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        code: json['code']?.toString(),
        price: FormatUtils.toDouble(json['price']),
        currency: json['currency']?.toString(),
        quantity: (json['quantity'] as num).toInt(),
        stock: (json['stock'] as num?)?.toInt() ?? 0,
      );

  factory CartItemModel.fromEntity(CartItemEntity e) => CartItemModel(
        productId: e.productId,
        name: e.name,
        imageUrl: e.imageUrl,
        code: e.code,
        price: e.price,
        currency: e.currency,
        quantity: e.quantity,
        stock: e.stock,
      );

  Map<String, dynamic> toLocal() => {
        'productId': productId,
        'name': name,
        'imageUrl': imageUrl,
        'code': code,
        'price': price,
        'currency': currency,
        'quantity': quantity,
        'stock': stock,
      };
}
