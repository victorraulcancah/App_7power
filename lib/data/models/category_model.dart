import '../../domain/entities/category_entity.dart';

/// Categoría tal como la devuelve `GET /categorias/publicas`.
class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.name,
    super.imageUrl,
    super.productsCount,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final image = json['imagen_url']?.toString();

    return CategoryModel(
      id: (json['id'] as num).toInt(),
      name: json['nombre']?.toString() ?? '',
      imageUrl: (image != null && image.startsWith('http')) ? image : null,
      productsCount: (json['productos_count'] as num?)?.toInt() ?? 0,
    );
  }
}
