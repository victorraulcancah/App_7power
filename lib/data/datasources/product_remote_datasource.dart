import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/entities/products_page_entity.dart';
import '../models/category_model.dart';
import '../models/product_detail_model.dart';
import '../models/product_model.dart';

abstract class ProductRemoteDataSource {
  Future<ProductsPageEntity> getProducts({
    required int page,
    String? search,
    int? categoryId,
    int? limit,
    ProductFilters filters = ProductFilters.none,
  });

  Future<List<CategoryModel>> getCategories();

  Future<List<BrandEntity>> getBrands();

  Future<ProductDetailModel> getProductDetail(int id);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final ApiClient client;

  ProductRemoteDataSourceImpl(this.client);

  @override
  Future<ProductsPageEntity> getProducts({
    required int page,
    String? search,
    int? categoryId,
    int? limit,
    ProductFilters filters = ProductFilters.none,
  }) async {
    final response = await client.get(
      ApiConstants.productosEndpoint,
      queryParameters: {
        // El backend solo respeta `per_page` cuando NO se manda `page`.
        if (limit != null) 'per_page': '$limit' else 'page': '$page',
        'search': ?search,
        if (categoryId != null) 'categoria': '$categoryId',
        // Varias marcas van como ids separados por comas.
        if (filters.brandIds.isNotEmpty)
          'brandIds': (filters.brandIds.toList()..sort()).join(','),
        if (filters.minPrice != null) 'minPrice': _number(filters.minPrice!),
        if (filters.maxPrice != null) 'maxPrice': _number(filters.maxPrice!),
        'sortBy': ?filters.sort.apiValue,
      },
    );

    final body = _decode(response.bodyBytes) as Map<String, dynamic>;
    final pagination = body['pagination'] as Map<String, dynamic>;

    return ProductsPageEntity(
      items: (body['productos'] as List)
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(),
      currentPage: (pagination['current_page'] as num).toInt(),
      lastPage: (pagination['last_page'] as num).toInt(),
      total: (pagination['total'] as num).toInt(),
      priceMin: (body['precio_min'] as num?)?.toDouble(),
      priceMax: (body['precio_max'] as num?)?.toDouble(),
    );
  }

  /// 120.0 -> "120", 99.5 -> "99.5" (sin ceros de más en la URL).
  String _number(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Future<List<BrandEntity>> getBrands() async {
    final response = await client.get(ApiConstants.marcasEndpoint);
    return (_decode(response.bodyBytes) as List)
        .cast<Map<String, dynamic>>()
        .map((b) => BrandEntity(
              id: (b['id'] as num).toInt(),
              name: b['nombre']?.toString() ?? '',
              productsCount: (b['productos_count'] as num?)?.toInt() ?? 0,
            ))
        // Una marca sin productos no sirve como filtro.
        .where((b) => b.productsCount > 0)
        .toList();
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await client.get(ApiConstants.categoriasEndpoint);
    return (_decode(response.bodyBytes) as List)
        .cast<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList();
  }

  @override
  Future<ProductDetailModel> getProductDetail(int id) async {
    final response = await client.get(
      ApiConstants.productoDetalleEndpoint.replaceFirst('{id}', '$id'),
    );
    return ProductDetailModel.fromJson(
      _decode(response.bodyBytes) as Map<String, dynamic>,
    );
  }

  /// El backend no declara charset: se decodifica como UTF-8 a mano para
  /// que no se rompan las tildes y la ñ.
  dynamic _decode(List<int> bytes) => jsonDecode(utf8.decode(bytes));
}
