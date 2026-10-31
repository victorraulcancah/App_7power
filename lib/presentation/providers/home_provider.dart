import 'package:flutter/foundation.dart';

import '../../domain/entities/banner_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/get_banners_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import 'auth_aware_reload.dart';

enum HomeStatus { initial, loading, loaded }

/// Portada: banners y "Recomendado para ti" (productos, filtrables por
/// categoría).
class HomeProvider extends ChangeNotifier with AuthAwareReload {
  /// Productos que se muestran en "Recomendado para ti"; "Ver más" lleva a la
  /// tienda con la misma categoría.
  static const int recommendedCount = 8;

  final GetBannersUseCase getBannersUseCase;
  final GetProductsUseCase getProductsUseCase;

  HomeProvider({
    required this.getBannersUseCase,
    required this.getProductsUseCase,
  });

  HomeStatus _status = HomeStatus.initial;
  List<BannerEntity> _banners = const [];
  List<ProductEntity> _recommended = const [];
  int? _categoryId;
  bool _loadingRecommended = false;

  /// Identifica la última consulta de recomendados: si el cliente cambia de
  /// categoría mientras carga otra, la respuesta vieja se ignora.
  int _requestId = 0;

  HomeStatus get status => _status;
  List<BannerEntity> get banners => _banners;
  List<ProductEntity> get recommended => _recommended;

  /// Categoría elegida en "Recomendado para ti" (null = Todo).
  int? get recommendedCategoryId => _categoryId;
  bool get isLoadingRecommended => _loadingRecommended;

  /// Los precios dependen del cliente: al cambiar la sesión se recargan.
  @override
  Future<void> reloadForAuthChange() => load();

  Future<void> load() async {
    _status = HomeStatus.loading;
    notifyListeners();

    // Cada bloque es independiente: si uno falla, el otro se muestra igual.
    await Future.wait([
      getBannersUseCase().then(
        (r) => r.fold((_) {}, (banners) => _banners = banners),
      ),
      _fetchRecommended(),
    ]);

    _status = HomeStatus.loaded;
    notifyListeners();
  }

  /// Cambia la categoría de "Recomendado para ti" (null = Todo).
  Future<void> selectRecommendedCategory(int? categoryId) async {
    if (categoryId == _categoryId) return;
    _categoryId = categoryId;
    _loadingRecommended = true;
    notifyListeners();

    await _fetchRecommended();

    _loadingRecommended = false;
    notifyListeners();
  }

  Future<void> _fetchRecommended() async {
    final id = ++_requestId;
    final result = await getProductsUseCase(
      limit: recommendedCount,
      categoryId: _categoryId,
    );
    if (id != _requestId) return;
    // Si falla se deja lo que había (o nada): la portada sigue usable.
    result.fold((_) {}, (page) => _recommended = page.items);
  }
}
