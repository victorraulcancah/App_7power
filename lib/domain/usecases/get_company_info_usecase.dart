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
