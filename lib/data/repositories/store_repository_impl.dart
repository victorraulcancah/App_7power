import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/banner_entity.dart';
import '../../domain/entities/company_info_entity.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_local_datasource.dart';
import '../datasources/store_remote_datasource.dart';

class StoreRepositoryImpl implements StoreRepository {
  final StoreRemoteDataSource remoteDataSource;
  final StoreLocalDataSource? localDataSource;

  StoreRepositoryImpl(this.remoteDataSource, {this.localDataSource});

  @override
  Future<Either<Failure, CompanyInfoEntity>> getCompanyInfo() =>
      guardRequest(() async {
        final company = await remoteDataSource.getCompanyInfo();
        // Se guarda para que el próximo arranque ya tenga color y logo.
        await localDataSource?.writeCompany(company);
        return company;
      });

  @override
  Future<CompanyInfoEntity?> getCachedCompanyInfo() async =>
      localDataSource?.readCompany();

  @override
  Future<Either<Failure, List<BannerEntity>>> getBanners() =>
      guardRequest(remoteDataSource.getBanners);
}
