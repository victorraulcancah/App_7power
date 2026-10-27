import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/banner_entity.dart';
import '../repositories/store_repository.dart';

class GetBannersUseCase {
  final StoreRepository repository;

  GetBannersUseCase(this.repository);

  Future<Either<Failure, List<BannerEntity>>> call() => repository.getBanners();
}
