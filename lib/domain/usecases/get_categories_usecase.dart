import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/category_entity.dart';
import '../repositories/product_repository.dart';

class GetCategoriesUseCase {
  final ProductRepository repository;

  GetCategoriesUseCase(this.repository);

  Future<Either<Failure, List<CategoryEntity>>> call() =>
      repository.getCategories();
}
