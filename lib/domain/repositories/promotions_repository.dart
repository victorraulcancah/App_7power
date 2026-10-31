import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/promotion_entity.dart';

abstract class PromotionsRepository {
  /// Cupones vigentes y con usos disponibles.
  Future<Either<Failure, List<CouponOffer>>> getActiveCoupons();

  /// El banner de ofertas activo. Sin banner activo devuelve uno vacío.
  Future<Either<Failure, OfferBanner>> getOffers();
}
