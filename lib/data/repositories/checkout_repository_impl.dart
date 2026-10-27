import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/checkout_entity.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../datasources/checkout_remote_datasource.dart';

class CheckoutRepositoryImpl implements CheckoutRepository {
  final CheckoutRemoteDataSource remote;

  CheckoutRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<PaymentTypeEntity>>> getPaymentTypes() =>
      guardRequest(remote.getPaymentTypes);

  /// Los datos auxiliares no deben impedir comprar: si fallan se usa un valor
  /// por defecto.
  @override
  Future<bool> isGatewayInTestMode() async {
    try {
      return await remote.isGatewayInTestMode();
    } catch (_) {
      return true;
    }
  }

  @override
  Future<double> getCreditAvailable() async {
    try {
      return await remote.getCreditAvailable();
    } catch (_) {
      // Sin dato confiable no se ofrece crédito.
      return 0;
    }
  }

  @override
  Future<String?> getHolderPhone() async {
    try {
      return await remote.getHolderPhone();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<double?> getExchangeRate() async {
    try {
      return await remote.getExchangeRate();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Either<Failure, CouponEntity>> validateCoupon(
    String code,
    double total,
  ) =>
      guardRequest(() => remote.validateCoupon(code, total));

  @override
  Future<Either<Failure, StockCheck>> verifyStock(
    List<CartItemEntity> items,
  ) =>
      guardRequest(() => remote.verifyStock(items));

  @override
  Future<Either<Failure, List<CreatedQuote>>> createQuotes(QuoteOrder order) =>
      guardRequest(() => remote.createQuotes(order));

  @override
  Future<Either<Failure, PaymentResult>> pay(PaymentOrder order) =>
      guardRequest(() => remote.pay(order));
}
