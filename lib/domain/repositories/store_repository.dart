import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/banner_entity.dart';
import '../entities/company_info_entity.dart';

/// Información general de la tienda: empresa y banners de portada.
abstract class StoreRepository {
  Future<Either<Failure, CompanyInfoEntity>> getCompanyInfo();

  Future<Either<Failure, List<BannerEntity>>> getBanners();
}
