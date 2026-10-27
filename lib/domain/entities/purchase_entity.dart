/// Estado de una compra en línea, en el orden del seguimiento que muestra la
/// web.
enum PurchaseStage {
  pendingInvoice,
  invoiced,
  inDelivery,
  delivered,
  cancelled;

  /// Valor de `estado_proceso` en el backend. Uno desconocido se trata como
  /// el primer paso, igual que la web.
  static PurchaseStage fromApi(String? value) => switch (value) {
        'pendiente_facturar' => pendingInvoice,
        'facturado' => invoiced,
        'en_delivery' => inDelivery,
        'entregado' => delivered,
        'cancelado' => cancelled,
        _ => pendingInvoice,
      };

  String get label => switch (this) {
        pendingInvoice => 'Pendiente de facturar',
        invoiced => 'Facturado',
        inDelivery => 'En delivery',
        delivered => 'Entregado',
        cancelled => 'Cancelado',
      };

  String get description => switch (this) {
        pendingInvoice =>
          'Recibimos tu pago. Estamos preparando tu comprobante.',
        invoiced => 'Emitimos tu comprobante y te lo enviamos a tu correo. '
            'Pronto coordinaremos la entrega.',
        inDelivery => 'Tu pedido va en camino a la dirección indicada.',
        delivered => 'Tu pedido fue entregado. ¡Gracias por tu compra!',
        cancelled => 'Esta compra fue cancelada. Si tienes dudas, '
            'comunícate con nosotros.',
      };

  /// Posición en el seguimiento de 4 pasos; -1 si está cancelada.
  int get step => this == cancelled ? -1 : index;
}

class PurchaseItemEntity {
  final int productId;
  final String? code;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? imageUrl;

  const PurchaseItemEntity({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.code,
    this.imageUrl,
  });
}

/// Compra pagada en la tienda en línea (`/pago-en-linea`).
class PurchaseEntity {
  final String code;
  final PurchaseStage stage;
  final DateTime? date;

  /// 's' o 'd'.
  final String? currency;
  final double subtotal;
  final double igv;
  final double discount;
  final double shipping;
  final double total;
  final String? couponCode;
  final String? invoiceNumber;
  final DateTime? invoiceSentAt;
  final String? shippingMethod;
  final String? customerEmail;

  /// "dirección, distrito, provincia, departamento".
  final String? deliveryAddress;
  final List<PurchaseItemEntity> items;

  const PurchaseEntity({
    required this.code,
    required this.stage,
    required this.total,
    this.date,
    this.currency,
    this.subtotal = 0,
    this.igv = 0,
    this.discount = 0,
    this.shipping = 0,
    this.couponCode,
    this.invoiceNumber,
    this.invoiceSentAt,
    this.shippingMethod,
    this.customerEmail,
    this.deliveryAddress,
    this.items = const [],
  });
}

class StoreSaleItemEntity {
  final String? code;
  final String name;
  final double quantity;
  final double price;
  final double subtotal;

  const StoreSaleItemEntity({
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.code,
  });
}

/// Compra hecha en tienda física, leída del ERP (solo cuentas vinculadas).
class StoreSaleEntity {
  final int id;
  final String document;
  final String? date;
  final String? currency;
  final double total;
  final bool cancelled;
  final String? notes;
  final List<StoreSaleItemEntity> items;

  const StoreSaleEntity({
    required this.id,
    required this.document,
    required this.total,
    this.date,
    this.currency,
    this.cancelled = false,
    this.notes,
    this.items = const [],
  });
}

class StorePurchasesResult {
  /// false si la cuenta no está vinculada al ERP: no hay compras que mostrar.
  final bool linked;
  final List<StoreSaleEntity> sales;

  const StorePurchasesResult({required this.linked, required this.sales});
}
