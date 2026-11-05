import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/promotion_entity.dart';
import '../repositories/promotions_repository.dart';

class GetActiveCouponsUseCase {
  final PromotionsRepository repository;
  GetActiveCouponsUseCase(this.repository);

  Future<Either<Failure, List<CouponOffer>>> call() =>
      repository.getActiveCoupons();
}

class GetOffersUseCase {
  final PromotionsRepository repository;
  GetOffersUseCase(this.repository);

  Future<Either<Failure, OfferBanner>> call() => repository.getOffers();
}

class GetPromoBannersUseCase {
  final PromotionsRepository repository;
  GetPromoBannersUseCase(this.repository);

  Future<Either<Failure, List<PromoBanner>>> call() =>
      repository.getPromoBanners();
}

class GetFlashSalesUseCase {
  final PromotionsRepository repository;
  GetFlashSalesUseCase(this.repository);

  Future<Either<Failure, List<FlashSale>>> call() => repository.getFlashSales();
}
