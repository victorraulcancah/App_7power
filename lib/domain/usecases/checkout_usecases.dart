import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/cart_item_entity.dart';
import '../entities/checkout_entity.dart';
import '../repositories/checkout_repository.dart';

class GetPaymentTypesUseCase {
  final CheckoutRepository repository;
  GetPaymentTypesUseCase(this.repository);

  Future<Either<Failure, List<PaymentTypeEntity>>> call() =>
      repository.getPaymentTypes();
}

/// Datos auxiliares del checkout que, si fallan, no impiden comprar.
class GetCheckoutExtrasUseCase {
  final CheckoutRepository repository;
  GetCheckoutExtrasUseCase(this.repository);

  Future<bool> testMode() => repository.isGatewayInTestMode();

  Future<double> credit() => repository.getCreditAvailable();

  Future<String?> holderPhone() => repository.getHolderPhone();

  Future<double?> exchangeRate() => repository.getExchangeRate();
}

class ValidateCouponUseCase {
  final CheckoutRepository repository;
  ValidateCouponUseCase(this.repository);

  Future<Either<Failure, CouponEntity>> call(String code, double total) {
    if (code.trim().isEmpty) {
      return Future.value(Either.left(
        const ValidationFailure('Ingresa un código de cupón'),
      ));
    }
    return repository.validateCoupon(code.trim(), total);
  }
}

class VerifyStockUseCase {
  final CheckoutRepository repository;
  VerifyStockUseCase(this.repository);

  Future<Either<Failure, StockCheck>> call(List<CartItemEntity> items) =>
      repository.verifyStock(items);
}

/// Mismas reglas que valida la web antes de cotizar.
String? validateDelivery(DeliveryInfo d, {bool contactRequired = false}) {
  if (d.address.fullAddress.trim().isEmpty) {
    return 'Elige una dirección de entrega';
  }
  if (contactRequired) {
    if (d.recipientName.trim().length < 3) return 'Ingresa tu nombre completo';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(d.email.trim())) {
      return 'Ingresa un correo válido';
    }
    if (!RegExp(r'^[0-9+ ]{7,15}$').hasMatch(d.phone.trim())) {
      return 'Ingresa un teléfono de contacto válido';
    }
    if ((d.notes ?? '').length > 500) {
      return 'Las observaciones no pueden pasar de 500 caracteres';
    }
  }
  return null;
}

class CreateQuotesUseCase {
  final CheckoutRepository repository;
  CreateQuotesUseCase(this.repository);

  Future<Either<Failure, List<CreatedQuote>>> call(QuoteOrder order) {
    if (order.items.isEmpty) {
      return Future.value(Either.left(
        const ValidationFailure('Tu carrito está vacío'),
      ));
    }
    final error = validateDelivery(order.delivery);
    if (error != null) {
      return Future.value(Either.left(ValidationFailure(error)));
    }
    return repository.createQuotes(order);
  }
}

class PayOnlineUseCase {
  final CheckoutRepository repository;
  PayOnlineUseCase(this.repository);

  Future<Either<Failure, PaymentResult>> call(PaymentOrder order) {
    final error = validateDelivery(order.delivery, contactRequired: true);
    if (error != null) {
      return Future.value(Either.left(ValidationFailure(error)));
    }
    final a = order.delivery.address;
    // El servidor exige nombrar departamento, provincia y distrito.
    if (a.department == null || a.province == null || a.district == null) {
      return Future.value(Either.left(const ValidationFailure(
        'Tu dirección no tiene departamento, provincia y distrito. Edítala '
        'y elige la ubicación completa.',
      )));
    }
    return repository.pay(order);
  }
}
