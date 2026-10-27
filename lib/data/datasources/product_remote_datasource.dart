import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/products_page_entity.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

abstract class ProductRemoteDataSource {
  Future<ProductsPageEntity> getProducts({
    required int page,
    String? search,
    int? categoryId,
  });

  Future<List<CategoryModel>> getCategories();
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final ApiClient client;

  ProductRemoteDataSourceImpl(this.client);

  @override
  Future<ProductsPageEntity> getProducts({
    required int page,
    String? search,
    int? categoryId,
  }) async {
    final response = await client.get(
      ApiConstants.productosEndpoint,
      queryParameters: {
        'page': '$page',
        'search': ?search,
        if (categoryId != null) 'categoria': '$categoryId',
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
    );
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await client.get(ApiConstants.categoriasEndpoint);
    return (_decode(response.bodyBytes) as List)
        .cast<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList();
  }

  /// El backend no declara charset: se decodifica como UTF-8 a mano para
  /// que no se rompan las tildes y la ñ.
  dynamic _decode(List<int> bytes) => jsonDecode(utf8.decode(bytes));
}
