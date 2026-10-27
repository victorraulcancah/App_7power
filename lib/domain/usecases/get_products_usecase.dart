import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_filters.dart';
import '../entities/products_page_entity.dart';
import '../repositories/product_repository.dart';

class GetProductsUseCase {
  final ProductRepository repository;

  GetProductsUseCase(this.repository);

  Future<Either<Failure, ProductsPageEntity>> call({
    int page = 1,
    String? search,
    int? categoryId,
    int? limit,
    ProductFilters filters = ProductFilters.none,
  }) =>
      repository.getProducts(
        page: page,
        search: (search == null || search.isEmpty) ? null : search,
        categoryId: categoryId,
        limit: limit,
        filters: filters,
      );
}
