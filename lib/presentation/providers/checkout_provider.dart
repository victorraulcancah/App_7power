import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/checkout_entity.dart';
import '../../domain/entities/payment_plan.dart';
import '../../domain/usecases/checkout_usecases.dart';
import 'load_status.dart';

/// Estado del checkout (pagar o cotizar). Se reinicia cada vez que se abre.
class CheckoutProvider extends ChangeNotifier {
  final GetPaymentTypesUseCase getPaymentTypesUseCase;
  final GetCheckoutExtrasUseCase extras;
  final ValidateCouponUseCase validateCouponUseCase;
  final VerifyStockUseCase verifyStockUseCase;
  final CreateQuotesUseCase createQuotesUseCase;
  final PayOnlineUseCase payOnlineUseCase;

  CheckoutProvider({
    required this.getPaymentTypesUseCase,
    required this.extras,
    required this.validateCouponUseCase,
    required this.verifyStockUseCase,
    required this.createQuotesUseCase,
    required this.payOnlineUseCase,
  });

  LoadStatus _status = LoadStatus.initial;
  String _errorMessage = '';
  List<PaymentTypeEntity> _paymentTypes = const [];
  double _credit = 0;
  bool _testMode = true;
  double? _exchangeRate;
  String? _holderPhone;
  PaymentPlan _plan = PaymentPlan();
  CouponEntity? _coupon;
  bool _busy = false;

  LoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<PaymentTypeEntity> get paymentTypes => _paymentTypes;
  double get creditAvailable => _credit;
  bool get testMode => _testMode;
  double? get exchangeRate => _exchangeRate;
  String? get holderPhone => _holderPhone;
  PaymentPlan get plan => _plan;
  CouponEntity? get coupon => _coupon;
  bool get isBusy => _busy;

  /// Formas de pago que se ofrecen: el crédito solo si el cliente tiene.
  List<PaymentTypeEntity> get offeredPaymentTypes => _paymentTypes
      .where((t) => !t.isCredit || _plan.creditOffered)
      .toList();

  /// Carga lo que necesita el checkout. [forQuote] pide también las formas de
  /// pago, que solo se usan al cotizar.
  Future<void> open({required bool forQuote}) async {
    _status = LoadStatus.loading;
    _coupon = null;
    _plan = PaymentPlan();
    notifyListeners();

    final results = await Future.wait<Object?>([
      forQuote ? getPaymentTypesUseCase() : Future.value(null),
      extras.credit(),
      extras.testMode(),
      extras.exchangeRate(),
      extras.holderPhone(),
    ]);

    _credit = results[1] as double;
    _testMode = results[2] as bool;
    _exchangeRate = results[3] as double?;
    _holderPhone = results[4] as String?;
    _plan = PaymentPlan(creditAvailable: _credit);

    var failed = false;
    if (forQuote) {
      (results[0]! as Either<Failure, List<PaymentTypeEntity>>).fold(
        (f) {
          failed = true;
          _errorMessage = f.message;
        },
        (types) {
          _paymentTypes = types;
          if (types.isEmpty) {
            failed = true;
            _errorMessage = 'No hay formas de pago disponibles por ahora.';
          }
        },
      );
    }

    _status = failed ? LoadStatus.error : LoadStatus.loaded;
    notifyListeners();
  }

  void togglePayment(PaymentTypeEntity type, String currency, double total) {
    _plan.toggle(type, currency, total);
    notifyListeners();
  }

  void setPaymentAmount(
    String type,
    String currency,
    double total,
    double amount,
  ) {
    _plan.setAmount(type, currency, total, amount);
    notifyListeners();
  }

  /// Devuelve null si se aplicó, o el motivo por el que no.
  Future<String?> applyCoupon(String code, double solesTotal) async {
    final result = await validateCouponUseCase(code, solesTotal);
    return result.fold((f) => f.message, (coupon) {
      _coupon = coupon;
      notifyListeners();
      return null;
    });
  }

  void removeCoupon() {
    _coupon = null;
    notifyListeners();
  }

  Future<Either<Failure, StockCheck>> verifyStock(List<CartItemEntity> items) =>
      _busyWhile(() => verifyStockUseCase(items));

  Future<Either<Failure, List<CreatedQuote>>> createQuotes(QuoteOrder order) =>
      _busyWhile(() => createQuotesUseCase(order));

  Future<Either<Failure, PaymentResult>> pay(PaymentOrder order) =>
      _busyWhile(() => payOnlineUseCase(order));

  Future<T> _busyWhile<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
