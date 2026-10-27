import 'address_entity.dart';
import 'cart_item_entity.dart';
import 'purchase_entity.dart';

/// Forma de pago que el cliente puede elegir al cotizar (`/tipos-pago/activos`).
class PaymentTypeEntity {
  final int id;
  final String name;

  /// Identificador que se envía al servidor al cotizar.
  final String code;
  final String? description;

  const PaymentTypeEntity({
    required this.id,
    required this.name,
    required this.code,
    this.description,
  });

  /// El crédito autorizado lo valida el servidor contra el crédito del
  /// cliente; acepta estos códigos sin distinguir mayúsculas.
  bool get isCredit => isCreditCode(code);

  static bool isCreditCode(String code) {
    final c = code.toLowerCase();
    return c == 'credito_autorizado' || c == 'credito' || c == 'crédito';
  }
}

/// Parte de lo que se paga con una forma de pago, en una moneda.
class PaymentLine {
  final String type;

  /// 's' o 'd'.
  final String currency;
  final double amount;

  const PaymentLine({
    required this.type,
    required this.currency,
    required this.amount,
  });

  PaymentLine copyWith({double? amount}) => PaymentLine(
        type: type,
        currency: currency,
        amount: amount ?? this.amount,
      );
}

/// Datos de entrega y contacto de un pedido.
class DeliveryInfo {
  final String recipientName;
  final String email;
  final String phone;
  final String? documentNumber;
  final String? notes;
  final AddressEntity address;

  const DeliveryInfo({
    required this.recipientName,
    required this.email,
    required this.phone,
    required this.address,
    this.documentNumber,
    this.notes,
  });

  /// Como la web: delivery en Lima (departamento 15) y envío a provincia en el
  /// resto. El costo no se calcula en la app: lo confirma la tienda.
  String get shippingMethod =>
      address.departmentCode == '15' ? 'delivery' : 'envio_provincia';

  String get shippingLabel =>
      shippingMethod == 'delivery' ? 'Delivery' : 'Envío a provincia';
}

/// Pedido de cotización.
class QuoteOrder {
  final List<CartItemEntity> items;
  final DeliveryInfo delivery;
  final List<PaymentLine> payments;

  const QuoteOrder({
    required this.items,
    required this.delivery,
    required this.payments,
  });
}

/// Lo único de la tarjeta que se manda al servidor: nunca el número ni el CVV.
class CardPayment {
  /// `tok_test_aprobado` o `tok_test_rechazado` con la pasarela simulada.
  final String token;
  final String brand;
  final String last4;

  const CardPayment({
    required this.token,
    required this.brand,
    required this.last4,
  });
}

/// Pedido de pago en línea. El servidor toma el carrito del cliente.
class PaymentOrder {
  final DeliveryInfo delivery;
  final CardPayment card;

  /// Solo hace falta si el carrito mezcla soles y dólares.
  final String? currency;
  final String? couponCode;

  const PaymentOrder({
    required this.delivery,
    required this.card,
    this.currency,
    this.couponCode,
  });
}

class CouponEntity {
  final String code;
  final String? title;
  final double discount;
  final double totalWithDiscount;

  const CouponEntity({
    required this.code,
    required this.discount,
    required this.totalWithDiscount,
    this.title,
  });
}

class StockShortage {
  final int productId;
  final String name;
  final int requested;
  final int available;

  const StockShortage({
    required this.productId,
    required this.name,
    required this.requested,
    required this.available,
  });
}

class StockCheck {
  final bool hasStock;
  final List<StockShortage> shortages;

  const StockCheck({required this.hasStock, this.shortages = const []});
}

/// Una cotización creada (se crea una por moneda).
class CreatedQuote {
  final String code;
  final String? orderCode;
  final String? currency;
  final double total;

  const CreatedQuote({
    required this.code,
    required this.total,
    this.orderCode,
    this.currency,
  });
}

/// Respuesta del pago. Tanto un pago aprobado como uno rechazado llegan como
/// respuesta correcta del servidor.
class PaymentResult {
  final bool approved;
  final String message;
  final PurchaseEntity? purchase;

  /// Datos de la tarjeta para el comprobante en pantalla.
  final String? cardBrand;
  final String? cardLast4;
  final String? reference;
  final bool simulated;

  const PaymentResult({
    required this.approved,
    required this.message,
    this.purchase,
    this.cardBrand,
    this.cardLast4,
    this.reference,
    this.simulated = false,
  });
}
