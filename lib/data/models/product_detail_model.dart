import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../domain/entities/product_detail_entity.dart';
import 'product_model.dart';

/// Respuesta de `GET /productos-publicos/{id}`.
class ProductDetailModel extends ProductDetailEntity {
  const ProductDetailModel({
    required super.product,
    super.images,
    super.longDescription,
    super.specifications,
    super.technicalFeatures,
    super.warranty,
    super.related,
  });

  factory ProductDetailModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['producto'] as Map<String, dynamic>;
    final details = json['detalles'] as Map<String, dynamic>?;
    // El precio y la moneda resueltos para este cliente vienen en la raíz.
    final product = ProductModel.fromDetailJson({
      ...productJson,
      'moneda': json['moneda'] ?? productJson['moneda'],
    });

    String? text(String key) {
      final value = details?[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return ProductDetailModel(
      product: product,
      images: [
        if (product.imageUrl != null) product.imageUrl!,
        ..._galleryImages(details?['imagenes']),
      ],
      longDescription: text('descripcion_detallada'),
      specifications: text('especificaciones'),
      technicalFeatures: text('caracteristicas_tecnicas'),
      warranty: text('garantia'),
      related: ((json['productos_relacionados'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromDetailJson)
          .toList(),
    );
  }

  /// `imagenes` llega como texto JSON ('["a.png","b.png"]') o como lista.
  static List<String> _galleryImages(dynamic raw) {
    try {
      final list = raw is String ? jsonDecode(raw) : raw;
      if (list is! List) return const [];
      return [
        for (final name in list)
          '${ApiConstants.storageUrl}/productos/detalles/$name',
      ];
    } catch (_) {
      return const [];
    }
  }
}
