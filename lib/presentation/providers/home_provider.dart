import 'package:flutter/foundation.dart';

import '../../domain/entities/banner_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/get_banners_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';

enum HomeStatus { initial, loading, loaded }

/// Portada: banners y una lista corta de productos.
class HomeProvider extends ChangeNotifier {
  static const int featuredCount = 10;

  final GetBannersUseCase getBannersUseCase;
  final GetProductsUseCase getProductsUseCase;

  HomeProvider({
    required this.getBannersUseCase,
    required this.getProductsUseCase,
  });

  HomeStatus _status = HomeStatus.initial;
  List<BannerEntity> _banners = const [];
  List<ProductEntity> _featured = const [];

  HomeStatus get status => _status;
  List<BannerEntity> get banners => _banners;
  List<ProductEntity> get featured => _featured;

  Future<void> load() async {
    _status = HomeStatus.loading;
    notifyListeners();

    // Cada bloque es independiente: si uno falla, el otro se muestra igual.
    await Future.wait([
      getBannersUseCase().then(
        (r) => r.fold((_) {}, (banners) => _banners = banners),
      ),
      getProductsUseCase(limit: featuredCount).then(
        (r) => r.fold((_) {}, (page) => _featured = page.items),
      ),
    ]);

    _status = HomeStatus.loaded;
    notifyListeners();
  }
}
