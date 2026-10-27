import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/cart_item_entity.dart';
import '../entities/checkout_entity.dart';

abstract class CheckoutRepository {
  Future<Either<Failure, List<PaymentTypeEntity>>> getPaymentTypes();

  /// true si la pasarela es de prueba (no cobra de verdad). Si no se puede
  /// consultar se asume que sí, como la web.
  Future<bool> isGatewayInTestMode();

  /// Crédito disponible del cliente; 0 si no tiene la cuenta vinculada.
  Future<double> getCreditAvailable();

  /// Celular del titular de la cuenta, si lo hay.
  Future<String?> getHolderPhone();

  /// Tipo de cambio comercial (solo informativo), o null si no hay.
  Future<double?> getExchangeRate();

  Future<Either<Failure, CouponEntity>> validateCoupon(
    String code,
    double total,
  );

  Future<Either<Failure, StockCheck>> verifyStock(List<CartItemEntity> items);

  Future<Either<Failure, List<CreatedQuote>>> createQuotes(QuoteOrder order);

  Future<Either<Failure, PaymentResult>> pay(PaymentOrder order);
}
