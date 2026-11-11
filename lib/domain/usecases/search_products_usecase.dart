import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

/// Las sugerencias del buscador para lo que se va escribiendo.
class SearchProductsUseCase {
  final ProductRepository repository;

  SearchProductsUseCase(this.repository);

  Future<Either<Failure, List<ProductEntity>>> call(
    String query, {
    int? categoryId,
  }) =>
      repository.searchProducts(query, categoryId: categoryId);
}
