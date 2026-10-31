import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/promotion_entity.dart';
import '../../domain/repositories/promotions_repository.dart';
import '../datasources/promotions_remote_datasource.dart';

class PromotionsRepositoryImpl implements PromotionsRepository {
  final PromotionsRemoteDataSource remote;

  PromotionsRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<CouponOffer>>> getActiveCoupons() =>
      guardRequest(remote.getActiveCoupons);

  @override
  Future<Either<Failure, OfferBanner>> getOffers() =>
      guardRequest(remote.getOffers);
}
