import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/category_entity.dart';
import '../entities/product_detail_entity.dart';
import '../entities/product_filters.dart';
import '../entities/products_page_entity.dart';

abstract class ProductRepository {
  /// Con [limit] devuelve solo los primeros [limit] productos (sin paginar):
  /// sirve para las listas cortas de la portada.
  Future<Either<Failure, ProductsPageEntity>> getProducts({
    int page = 1,
    String? search,
    int? categoryId,
    int? limit,
    ProductFilters filters = ProductFilters.none,
  });

  Future<Either<Failure, List<CategoryEntity>>> getCategories();

  Future<Either<Failure, List<BrandEntity>>> getBrands();

  Future<Either<Failure, ProductDetailEntity>> getProductDetail(int id);
}
