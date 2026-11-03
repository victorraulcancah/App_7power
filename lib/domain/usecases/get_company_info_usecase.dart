import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/company_info_entity.dart';
import '../repositories/store_repository.dart';

class GetCompanyInfoUseCase {
  final StoreRepository repository;

  GetCompanyInfoUseCase(this.repository);

  Future<Either<Failure, CompanyInfoEntity>> call() =>
      repository.getCompanyInfo();
}

/// Lo último que se guardó de la empresa, sin ir a la red.
class GetCachedCompanyInfoUseCase {
  final StoreRepository repository;

  GetCachedCompanyInfoUseCase(this.repository);

  Future<CompanyInfoEntity?> call() => repository.getCachedCompanyInfo();
}
