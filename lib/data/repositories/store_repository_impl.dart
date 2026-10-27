import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/banner_entity.dart';
import '../../domain/entities/company_info_entity.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_remote_datasource.dart';

class StoreRepositoryImpl implements StoreRepository {
  final StoreRemoteDataSource remoteDataSource;

  StoreRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, CompanyInfoEntity>> getCompanyInfo() =>
      guardRequest(remoteDataSource.getCompanyInfo);

  @override
  Future<Either<Failure, List<BannerEntity>>> getBanners() =>
      guardRequest(remoteDataSource.getBanners);
}
