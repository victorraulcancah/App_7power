import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/category_entity.dart';
import '../entities/products_page_entity.dart';

abstract class ProductRepository {
  Future<Either<Failure, ProductsPageEntity>> getProducts({
    int page = 1,
    String? search,
    int? categoryId,
  });

  Future<Either<Failure, List<CategoryEntity>>> getCategories();
}
