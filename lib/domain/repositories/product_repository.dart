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

  /// Las marcas con productos; con [categoryId], solo las de esa categoría.
  Future<Either<Failure, List<BrandEntity>>> getBrands({int? categoryId});

  Future<Either<Failure, ProductDetailEntity>> getProductDetail(int id);

  /// Lo guardado de la última vez (null si aún no hay), para armar la portada
  /// al instante mientras llega lo nuevo.
  Future<List<CategoryEntity>?> getCachedCategories();

  Future<List<BrandEntity>?> getCachedBrands();

  /// Los productos de la portada tal como los vio este mismo cliente.
  Future<ProductsPageEntity?> getCachedHomeProducts({required int limit});
}
