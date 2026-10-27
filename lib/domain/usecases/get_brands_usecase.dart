import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_filters.dart';
import '../repositories/product_repository.dart';

class GetBrandsUseCase {
  final ProductRepository repository;

  GetBrandsUseCase(this.repository);

  Future<Either<Failure, List<BrandEntity>>> call() => repository.getBrands();
}
