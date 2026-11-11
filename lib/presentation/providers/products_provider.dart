import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/usecases/get_brands_usecase.dart';
import '../../domain/usecases/get_cached_home_usecases.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import 'auth_aware_reload.dart';

enum ProductsStatus { initial, loading, loaded, error }

class ProductsProvider extends ChangeNotifier with AuthAwareReload {
  final GetProductsUseCase getProductsUseCase;
  final GetCategoriesUseCase getCategoriesUseCase;
  final GetBrandsUseCase? getBrandsUseCase;

  /// Lo guardado de la última vez: las categorías y marcas se muestran al
  /// instante mientras llegan las actualizadas. Opcionales.
  final GetCachedCategoriesUseCase? getCachedCategoriesUseCase;
  final GetCachedBrandsUseCase? getCachedBrandsUseCase;

  ProductsProvider({
    required this.getProductsUseCase,
    required this.getCategoriesUseCase,
    this.getBrandsUseCase,
    this.getCachedCategoriesUseCase,
    this.getCachedBrandsUseCase,
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

  /// Marcas con productos en la categoría elegida (null = no hay categoría o
  /// todavía no llegan).
  List<BrandEntity>? _categoryBrands;

  /// Las marcas que ofrece la hoja de filtros: las de la categoría elegida, o
  /// todas si no hay categoría.
  List<BrandEntity> get availableBrands {
    final base = _categoryId == null ? _brands : (_categoryBrands ?? _brands);
    final scoped = _searchBrandCounts;
    if (scoped == null) return base;
    // Con una búsqueda activa, solo las marcas que tienen resultados en ella
    // (y con la cantidad de esa búsqueda): elegir otra daría "Sin productos".
    return [
      for (final b in base)
        if (scoped.containsKey(b.name.toLowerCase()))
          BrandEntity(
            id: b.id,
            name: b.name,
            productsCount: scoped[b.name.toLowerCase()]!,
            imageUrl: b.imageUrl,
            inShowcase: b.inShowcase,
            showcaseOrder: b.showcaseOrder,
          ),
    ];
  }

  /// Marcas (en minúsculas) con la cantidad de productos que tienen en la
  /// búsqueda actual; null si no hay búsqueda o todavía no llega.
  Map<String, int>? _searchBrandCounts;
  int _searchScopeId = 0;

  Future<void> _loadSearchBrands() async {
    final scope = ++_searchScopeId;
    _searchBrandCounts = null;
    if (_query.isEmpty) return;

    final result = await getProductsUseCase(
      search: _query,
      categoryId: _categoryId,
      limit: 500,
    );
    // Si mientras tanto cambió la búsqueda o la categoría, ya no sirve.
    if (scope != _searchScopeId) return;
    result.fold((_) {}, (page) {
      final counts = <String, int>{};
      for (final p in page.items) {
        final brand = p.brand?.trim().toLowerCase();
        if (brand == null || brand.isEmpty) continue;
        counts[brand] = (counts[brand] ?? 0) + 1;
      }
      _searchBrandCounts = counts;
      notifyListeners();
    });
  }

  int? get selectedCategoryId => _categoryId;

  /// Nombre de la categoría elegida (para decir qué se está filtrando).
  String? get selectedCategoryName {
    for (final c in _categories) {
      if (c.id == _categoryId) return c.name;
    }
    return null;
  }

  /// Texto buscado (lo que muestra el buscador de la tienda).
  String get query => _query;
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
    final cached = await getCachedCategoriesUseCase?.call();
    if (cached != null && cached.isNotEmpty && _categories.isEmpty) {
      _categories = cached;
      notifyListeners();
    }

    final result = await getCategoriesUseCase();
    result.fold((_) {}, (categories) => _categories = categories);
    _categoriesLoaded = true;
    notifyListeners();
  }

  bool _categoriesLoaded = false;

  /// Ya se pidieron las categorías al servidor (con o sin éxito): permite
  /// distinguir "todavía cargando" de "no hay".
  bool get categoriesLoaded => _categoriesLoaded;

  /// Vuelve a pedir las categorías (el "Reintentar" de la pestaña Categorías).
  Future<void> reloadCategories() {
    _categoriesLoaded = false;
    notifyListeners();
    return _loadCategories();
  }

  /// Las marcas son un extra: si no cargan, el filtro de marcas no se muestra.
  Future<void> _loadBrands() async {
    final useCase = getBrandsUseCase;
    if (useCase == null) return;

    final cached = await getCachedBrandsUseCase?.call();
    if (cached != null && cached.isNotEmpty && _brands.isEmpty) {
      _brands = cached;
      notifyListeners();
    }

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
    unawaited(_loadSearchBrands());
    return loadProducts();
  }

  /// Búsqueda desde el inicio: en todo el catálogo, sin la categoría ni los
  /// filtros que hubiera de antes (una sola consulta).
  Future<void> searchEverywhere(String query, {int? categoryId}) {
    _query = query.trim();
    // Con la categoría elegida en el buscador se busca solo en ella.
    _categoryId = categoryId;
    _categoryBrands = null;
    _filters = ProductFilters.none;
    final loading = loadProducts();
    unawaited(_loadSearchBrands());
    if (categoryId != null) unawaited(_loadCategoryBrands(categoryId));
    return loading;
  }

  Future<void> selectCategory(int? categoryId) {
    if (categoryId == _categoryId) return Future.value();
    _categoryId = categoryId;
    _categoryBrands = null;
    final loading = loadProducts();
    unawaited(_loadSearchBrands());
    if (categoryId != null) unawaited(_loadCategoryBrands(categoryId));
    return loading;
  }

  /// Las marcas que tienen productos en [categoryId], para que la hoja de
  /// filtros no ofrezca una combinación que no da resultados. Si no se puede
  /// pedir, se siguen mostrando todas.
  Future<void> _loadCategoryBrands(int categoryId) async {
    final useCase = getBrandsUseCase;
    if (useCase == null) return;

    final result = await useCase(categoryId: categoryId);
    // Si mientras tanto se cambió de categoría, esta respuesta ya no sirve.
    if (categoryId != _categoryId) return;
    result.fold((_) {}, (brands) {
      _categoryBrands = brands;
      notifyListeners();
    });
  }

  /// Aplica los filtros de la hoja (marcas, precio y orden).
  Future<void> applyFilters(ProductFilters filters) {
    if (filters == _filters) return Future.value();
    _filters = filters;
    return loadProducts();
  }

  Future<void> clearFilters() => applyFilters(ProductFilters.none);

  /// Quita todo lo que esté puesto: la búsqueda, la categoría y los filtros.
  Future<void> clearAll() {
    _query = '';
    _categoryId = null;
    _categoryBrands = null;
    _filters = ProductFilters.none;
    unawaited(_loadSearchBrands());
    return loadProducts();
  }

  /// Quita solo el texto buscado.
  Future<void> clearSearch() => search('');
}
