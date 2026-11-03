import '../entities/banner_entity.dart';
import '../entities/category_entity.dart';
import '../entities/product_filters.dart';
import '../entities/products_page_entity.dart';
import '../repositories/product_repository.dart';
import '../repositories/store_repository.dart';

// Lo que se guardó en el equipo la última vez, para mostrar la portada al
// instante. Devuelven null si todavía no hay nada guardado.

class GetCachedBannersUseCase {
  final StoreRepository repository;

  GetCachedBannersUseCase(this.repository);

  Future<List<BannerEntity>?> call() => repository.getCachedBanners();
}

class GetCachedCategoriesUseCase {
  final ProductRepository repository;

  GetCachedCategoriesUseCase(this.repository);

  Future<List<CategoryEntity>?> call() => repository.getCachedCategories();
}

class GetCachedBrandsUseCase {
  final ProductRepository repository;

  GetCachedBrandsUseCase(this.repository);

  Future<List<BrandEntity>?> call() => repository.getCachedBrands();
}

class GetCachedHomeProductsUseCase {
  final ProductRepository repository;

  GetCachedHomeProductsUseCase(this.repository);

  Future<ProductsPageEntity?> call({required int limit}) =>
      repository.getCachedHomeProducts(limit: limit);
}
