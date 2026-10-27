import '../../core/utils/format_utils.dart';
import '../../domain/entities/product_entity.dart';

/// Producto tal como lo devuelve `GET /productos-publicos`.
class ProductModel extends ProductEntity {
  const ProductModel({
    required super.id,
    required super.name,
    required super.price,
    required super.stock,
    super.code,
    super.description,
    super.brand,
    super.category,
    super.categoryId,
    super.imageUrl,
    super.currency,
    super.priceVisible,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final image = json['imagen_principal']?.toString();

    return ProductModel(
      id: (json['id'] as num).toInt(),
      name: json['nombre']?.toString() ?? '',
      code: json['codigo_producto']?.toString(),
      description: json['descripcion']?.toString(),
      brand: json['marca']?.toString(),
      category: json['categoria']?.toString(),
      categoryId: (json['categoria_id'] as num?)?.toInt(),
      // Sin imagen el backend devuelve una ruta relativa ("/placeholder-...")
      // que no existe en el servidor de la API: se descarta.
      imageUrl: (image != null && image.startsWith('http')) ? image : null,
      // `precio` llega null cuando el invitado no tiene lista de precios.
      price: FormatUtils.toDouble(json['precio']),
      currency: json['moneda']?.toString(),
      stock: FormatUtils.toDouble(json['stock']).toInt(),
      // Solo un `false` explícito oculta el precio (igual que la web).
      priceVisible: json['precio_visible'] != false,
    );
  }

  /// Producto dentro de un favorito (`GET /favoritos`): `precio` y `moneda`
  /// ya vienen resueltos para el cliente; el precio base (`precio_venta`) es
  /// siempre 0 y no se usa.
  factory ProductModel.fromFavoriteJson(Map<String, dynamic> json) {
    final image = json['imagen_url']?.toString();

    return ProductModel(
      id: (json['id'] as num).toInt(),
      name: json['nombre']?.toString() ?? '',
      code: json['codigo_producto']?.toString(),
      imageUrl: (image != null && image.startsWith('http')) ? image : null,
      price: FormatUtils.toDouble(json['precio']),
      currency: json['moneda']?.toString(),
      stock: FormatUtils.toDouble(json['stock']).toInt(),
      priceVisible: json['precio_visible'] != false,
    );
  }

  /// Producto del detalle (`GET /productos-publicos/{id}`): la forma es otra
  /// (relaciones anidadas, `precio_venta` ya resuelto para el cliente).
  factory ProductModel.fromDetailJson(Map<String, dynamic> json) {
    final image = json['imagen_url']?.toString();

    return ProductModel(
      id: (json['id'] as num).toInt(),
      name: json['nombre']?.toString() ?? '',
      code: json['codigo_producto']?.toString(),
      description: json['descripcion']?.toString(),
      brand: (json['marca'] as Map<String, dynamic>?)?['nombre']?.toString(),
      category:
          (json['categoria'] as Map<String, dynamic>?)?['nombre']?.toString(),
      categoryId: (json['categoria_id'] as num?)?.toInt(),
      imageUrl: (image != null && image.startsWith('http')) ? image : null,
      price: FormatUtils.toDouble(json['precio_venta']),
      currency: json['moneda']?.toString(),
      stock: FormatUtils.toDouble(json['stock']).toInt(),
      priceVisible: json['precio_visible'] != false,
    );
  }
}
