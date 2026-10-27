class QuoteItemEntity {
  final int productId;
  final String name;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  const QuoteItemEntity({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.imageUrl,
  });
}

class QuotePaymentEntity {
  final String type;
  final String? currency;
  final double amount;

  const QuotePaymentEntity({
    required this.type,
    required this.amount,
    this.currency,
  });
}

/// Cotización que el cliente pidió desde la tienda.
class QuoteEntity {
  final int id;
  final String code;
  final DateTime? date;
  final DateTime? expiresAt;
  final String? currency;
  final double subtotal;
  final double igv;
  final double shipping;
  final double total;

  /// Estado que ve el cliente (el del pedido): "En espera", "En preparación",
  /// "Cancelado"...
  final String status;

  /// Solo mientras el pedido está "En espera" se puede cancelar.
  final bool editable;
  final bool expired;
  final bool canConvert;
  final String? shippingMethod;
  final String? deliveryAddress;
  final String? phone;
  final String? notes;
  final List<QuotePaymentEntity> payments;
  final List<QuoteItemEntity> items;

  const QuoteEntity({
    required this.id,
    required this.code,
    required this.status,
    required this.total,
    this.date,
    this.expiresAt,
    this.currency,
    this.subtotal = 0,
    this.igv = 0,
    this.shipping = 0,
    this.editable = false,
    this.expired = false,
    this.canConvert = false,
    this.shippingMethod,
    this.deliveryAddress,
    this.phone,
    this.notes,
    this.payments = const [],
    this.items = const [],
  });

  /// La web detecta "cancelado" por el texto del estado.
  bool get isCancelled => status.toLowerCase().contains('cancel');

  /// Un vendedor ya la está atendiendo (no está en espera ni cancelada).
  bool get inAttention => !editable && !isCancelled;

  bool get canCancel => editable && !isCancelled;

  /// Etiqueta de `forma_envio` como la muestra la web.
  String? get shippingLabel => switch (shippingMethod) {
        'delivery' => 'Delivery',
        'recojo_tienda' => 'Recojo en tienda',
        'envio_provincia' => 'Envío a provincia',
        final other => other,
      };
}
