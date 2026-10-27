import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_detail_entity.dart';
import '../repositories/product_repository.dart';

class GetProductDetailUseCase {
  final ProductRepository repository;

  GetProductDetailUseCase(this.repository);

  Future<Either<Failure, ProductDetailEntity>> call(int id) =>
      repository.getProductDetail(id);
}
