import 'package:flutter/foundation.dart';

import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/usecases/get_brands_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import 'auth_aware_reload.dart';

enum ProductsStatus { initial, loading, loaded, error }

class ProductsProvider extends ChangeNotifier with AuthAwareReload {
  final GetProductsUseCase getProductsUseCase;
  final GetCategoriesUseCase getCategoriesUseCase;
  final GetBrandsUseCase? getBrandsUseCase;

  ProductsProvider({
    required this.getProductsUseCase,
    required this.getCategoriesUseCase,
    this.getBrandsUseCase,
  });

  ProductsStatus _status = ProductsStatus.initial;
  List<ProductEntity> _products = const [];
  List<CategoryEntity> _categories = const [];
  List<BrandEntity> _brands = const [];
  String _query = '';
  int? _categoryId;
  ProductFilters _filters = ProductFilters.none;
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  double? _priceMin;
  double? _priceMax;
  bool _loadingMore = false;
  String _errorMessage = '';

  /// Identifica la última consulta lanzada: si una respuesta llega cuando ya
  /// hay otra más reciente en curso (el usuario siguió escribiendo), se ignora.
  int _requestId = 0;

  ProductsStatus get status => _status;
  List<ProductEntity> get products => _products;
  List<CategoryEntity> get categories => _categories;
  List<BrandEntity> get brands => _brands;
  int? get selectedCategoryId => _categoryId;
  ProductFilters get filters => _filters;
  String get errorMessage => _errorMessage;
  int get total => _total;
  bool get hasMore => _page < _lastPage;
  bool get isLoadingMore => _loadingMore;

  /// Topes del deslizador de precio. Null si el cliente no tiene lista de
  /// precios o no hay rango que elegir.
  double? get priceMin => _priceMin;
  double? get priceMax => _priceMax;
  bool get canFilterByPrice =>
      _priceMin != null && _priceMax != null && _priceMax! > _priceMin!;

  /// Los precios dependen del cliente: al cambiar la sesión se recargan.
  @override
  Future<void> reloadForAuthChange() => loadProducts();

  /// Carga inicial: categorías, marcas y primera página de productos.
  Future<void> init() async {
    await Future.wait([_loadCategories(), _loadBrands(), loadProducts()]);
  }

  Future<void> _loadCategories() async {
    final result = await getCategoriesUseCase();
    result.fold((_) {}, (categories) => _categories = categories);
    notifyListeners();
  }

  /// Las marcas son un extra: si no cargan, el filtro de marcas no se muestra.
  Future<void> _loadBrands() async {
    final useCase = getBrandsUseCase;
    if (useCase == null) return;
    final result = await useCase();
    result.fold((_) {}, (brands) => _brands = brands);
    notifyListeners();
  }

  /// Vuelve a pedir la primera página con los filtros actuales.
  Future<void> loadProducts() async {
    final id = ++_requestId;
    _status = ProductsStatus.loading;
    _loadingMore = false;
    notifyListeners();

    final result = await getProductsUseCase(
      page: 1,
      search: _query,
      categoryId: _categoryId,
      filters: _filters,
    );
    if (id != _requestId) return;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _status = ProductsStatus.error;
      },
      (page) {
        _products = page.items;
        _page = page.currentPage;
        _lastPage = page.lastPage;
        _total = page.total;
        _priceMin = page.priceMin;
        _priceMax = page.priceMax;
        _status = ProductsStatus.loaded;
      },
    );
    notifyListeners();
  }

  /// Agrega la siguiente página al final de la lista.
  Future<void> loadMore() async {
    if (_loadingMore || !hasMore || _status != ProductsStatus.loaded) return;

    final id = _requestId;
    _loadingMore = true;
    notifyListeners();

    final result = await getProductsUseCase(
      page: _page + 1,
      search: _query,
      categoryId: _categoryId,
      filters: _filters,
    );
    if (id != _requestId) return;

    result.fold(
      // Un fallo al paginar no tira la lista ya cargada; se puede reintentar
      // al volver a llegar al final.
      (_) {},
      (page) {
        _products = [..._products, ...page.items];
        _page = page.currentPage;
        _lastPage = page.lastPage;
      },
    );
    _loadingMore = false;
    notifyListeners();
  }

  Future<void> search(String query) {
    if (query == _query) return Future.value();
    _query = query;
    return loadProducts();
  }

  Future<void> selectCategory(int? categoryId) {
    if (categoryId == _categoryId) return Future.value();
    _categoryId = categoryId;
    return loadProducts();
  }

  /// Aplica los filtros de la hoja (marcas, precio y orden).
  Future<void> applyFilters(ProductFilters filters) {
    if (filters == _filters) return Future.value();
    _filters = filters;
    return loadProducts();
  }

  Future<void> clearFilters() => applyFilters(ProductFilters.none);
}
