import 'package:flutter/foundation.dart';

import '../../domain/entities/promotion_entity.dart';
import '../../domain/usecases/promotions_usecases.dart';
import 'load_status.dart';

/// Cupones activos y banner de ofertas.
class PromotionsProvider extends ChangeNotifier {
  final GetActiveCouponsUseCase getActiveCouponsUseCase;
  final GetOffersUseCase getOffersUseCase;

  PromotionsProvider({
    required this.getActiveCouponsUseCase,
    required this.getOffersUseCase,
  });

  LoadStatus _couponsStatus = LoadStatus.initial;
  List<CouponOffer> _coupons = const [];
  String _couponsError = '';

  LoadStatus _offersStatus = LoadStatus.initial;
  OfferBanner _offers = const OfferBanner();
  String _offersError = '';

  LoadStatus get couponsStatus => _couponsStatus;
  List<CouponOffer> get coupons => _coupons;
  String get couponsError => _couponsError;

  LoadStatus get offersStatus => _offersStatus;
  OfferBanner get offers => _offers;
  String get offersError => _offersError;

  Future<void> loadCoupons() async {
    _couponsStatus = LoadStatus.loading;
    notifyListeners();

    final result = await getActiveCouponsUseCase();
    result.fold(
      (f) {
        _couponsError = f.message;
        _couponsStatus = LoadStatus.error;
      },
      (coupons) {
        _coupons = coupons;
        _couponsStatus = LoadStatus.loaded;
      },
    );
    notifyListeners();
  }

  Future<void> loadOffers() async {
    _offersStatus = LoadStatus.loading;
    notifyListeners();

    final result = await getOffersUseCase();
    result.fold(
      (f) {
        _offersError = f.message;
        _offersStatus = LoadStatus.error;
      },
      (offers) {
        _offers = offers;
        _offersStatus = LoadStatus.loaded;
      },
    );
    notifyListeners();
  }
}
