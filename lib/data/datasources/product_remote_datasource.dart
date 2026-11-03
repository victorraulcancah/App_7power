import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/response_cache.dart';
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

  /// Lo guardado de la última vez (null si no hay): el app lo muestra al abrir
  /// mientras llega lo nuevo.
  Future<List<CategoryModel>?> getCachedCategories();

  Future<List<BrandEntity>?> getCachedBrands();

  /// Los primeros [limit] productos de la portada, tal como los vio este mismo
  /// cliente (o invitado) la última vez.
  Future<ProductsPageEntity?> getCachedHomeProducts({required int limit});
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  static const _categoriesKey = 'categories';
  static const _brandsKey = 'brands';

  final ApiClient client;
  final ResponseCache? cache;

  ProductRemoteDataSourceImpl(this.client, {this.cache});

  static const _homePrefix = 'home_products_';

  /// Los precios dependen del cliente: lo guardado lleva en la clave a quien lo
  /// pidió (invitado o cliente con sesión), y solo se vuelve a mostrar a él.
  String _homeKey(int limit, String? token) =>
      '$_homePrefix${limit}_${ResponseCache.ownerFor(token)}';

  /// La lista corta de la portada ("Recomendado para ti" en Todo): sin
  /// búsqueda, categoría ni filtros.
  bool _isHomeList(int? limit, String? search, int? categoryId,
          ProductFilters filters) =>
      limit != null &&
      categoryId == null &&
      (search == null || search.isEmpty) &&
      filters == ProductFilters.none;

  @override
  Future<ProductsPageEntity> getProducts({
    required int page,
    String? search,
    int? categoryId,
    int? limit,
    ProductFilters filters = ProductFilters.none,
  }) async {
    // El dueño es quien pidió: la sesión puede cambiar mientras llega la respuesta.
    final token = client.authToken;
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

    final text = utf8.decode(response.bodyBytes);
    final result = _parseProducts(text);
    if (_isHomeList(limit, search, categoryId, filters)) {
      final key = _homeKey(limit!, token);
      await cache?.write(key, text);
      // Cada inicio de sesión es un dueño nuevo: se borran los de sesiones
      // anteriores y se conserva lo del invitado y lo de esta sesión. (Un
      // invitado no borra nada: al abrir el app, antes de restaurar la sesión,
      // también se pide como invitado.)
      if (token != null) {
        await cache?.prune(_homePrefix, keep: {key, _homeKey(limit, null)});
      }
    }
    return result;
  }

  @override
  Future<ProductsPageEntity?> getCachedHomeProducts({required int limit}) async {
    final text = await cache?.read(_homeKey(limit, client.authToken));
    if (text == null) return null;
    try {
      return _parseProducts(text);
    } catch (_) {
      return null;
    }
  }

  ProductsPageEntity _parseProducts(String text) {
    final body = jsonDecode(text) as Map<String, dynamic>;
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
    final text = utf8.decode(response.bodyBytes);
    final brands = _parseBrands(text);
    await cache?.write(_brandsKey, text);
    return brands;
  }

  @override
  Future<List<BrandEntity>?> getCachedBrands() async {
    final text = await cache?.read(_brandsKey);
    if (text == null) return null;
    try {
      return _parseBrands(text);
    } catch (_) {
      return null;
    }
  }

  List<BrandEntity> _parseBrands(String text) => (jsonDecode(text) as List)
      .cast<Map<String, dynamic>>()
      .map((b) => BrandEntity(
            id: (b['id'] as num).toInt(),
            name: b['nombre']?.toString() ?? '',
            productsCount: (b['productos_count'] as num?)?.toInt() ?? 0,
            imageUrl: (b['imagen_url']?.toString().isEmpty ?? true)
                ? null
                : b['imagen_url'].toString(),
            inShowcase: b['mostrar_en_vitrina'] == true,
            showcaseOrder: (b['orden_vitrina'] as num?)?.toInt() ?? 0,
          ))
      // Una marca sin productos no sirve como filtro.
      .where((b) => b.productsCount > 0)
      .toList();

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await client.get(ApiConstants.categoriasEndpoint);
    final text = utf8.decode(response.bodyBytes);
    final categories = _parseCategories(text);
    await cache?.write(_categoriesKey, text);
    return categories;
  }

  @override
  Future<List<CategoryModel>?> getCachedCategories() async {
    final text = await cache?.read(_categoriesKey);
    if (text == null) return null;
    try {
      return _parseCategories(text);
    } catch (_) {
      return null;
    }
  }

  List<CategoryModel> _parseCategories(String text) => (jsonDecode(text) as List)
      .cast<Map<String, dynamic>>()
      .map(CategoryModel.fromJson)
      .toList();

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
