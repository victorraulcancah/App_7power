/// Una línea (producto) de la venta, como la imprime el ERP.
class SaleDocumentLine {
  final String code;
  final String name;
  final String? brand;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double total;
  final bool dollars;

  const SaleDocumentLine({
    required this.code,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.brand,
    this.discount = 0,
    this.dollars = false,
  });
}

/// Todo lo que lleva el documento impreso de una venta en el ERP (nota de
/// venta, boleta o factura): empresa, cliente, vendedor, forma de pago y los
/// productos.
class SaleDocumentEntity {
  /// "V001-7289", "B001-0023"...
  final String number;

  /// "Nota de Venta", "Boleta Electrónica" o "Factura Electrónica".
  final String title;

  /// Con boleta o factura el documento desglosa el IGV.
  final bool isVoucher;
  final DateTime? date;
  final String? address;
  final String? cel;
  final String? email;
  final String? web;
  final String? clientDocument;
  final String clientName;
  final String clientAddress;
  final bool inDollars;
  final double exchangeRate;
  final List<String> paymentMethods;
  final String sellerName;
  final String? warehouseName;
  final String? observations;
  final String? comments;
  final List<SaleDocumentLine> lines;

  const SaleDocumentEntity({
    required this.number,
    required this.title,
    required this.clientName,
    required this.lines,
    this.isVoucher = false,
    this.date,
    this.address,
    this.cel,
    this.email,
    this.web,
    this.clientDocument,
    this.clientAddress = '',
    this.inDollars = false,
    this.exchangeRate = 1,
    this.paymentMethods = const [],
    this.sellerName = '-',
    this.warehouseName,
    this.observations,
    this.comments,
  });
}

/// Un movimiento del estado de cuenta: una venta (por producto) o un pago.
class AccountMovement {
  final String id;
  final DateTime? date;

  /// "BOL001-0123", "V001-0099"... o "-" en los pagos.
  final String document;
  final String description;
  final int? quantity;
  final double soles;
  final double dollars;

  /// Los pagos y las ventas anuladas van en rojo, como en el ERP.
  final bool isPayment;
  final bool isVoided;

  /// La venta completa a la que pertenece (solo en las ventas), con lo que
  /// hace falta para imprimir su documento. Todas las líneas de una venta
  /// comparten la misma.
  final SaleDocumentEntity? sale;

  const AccountMovement({
    required this.id,
    required this.document,
    required this.description,
    required this.soles,
    required this.dollars,
    this.date,
    this.quantity,
    this.isPayment = false,
    this.isVoided = false,
    this.sale,
  });

  bool get isRed => isPayment || isVoided;
}

/// Resumen del estado de cuenta: crédito y deuda.
class AccountSummary {
  final double creditLimit;
  final double creditUsed;
  final double creditAvailable;
  final double debtSoles;
  final double debtDollars;
  final double previousDebtSoles;
  final double previousDebtDollars;

  const AccountSummary({
    this.creditLimit = 0,
    this.creditUsed = 0,
    this.creditAvailable = 0,
    this.debtSoles = 0,
    this.debtDollars = 0,
    this.previousDebtSoles = 0,
    this.previousDebtDollars = 0,
  });

  bool get hasPreviousDebt => previousDebtSoles > 0 || previousDebtDollars > 0;
}

/// Una página del estado de cuenta de un rango de fechas.
class AccountStatementPage {
  final AccountSummary summary;
  final List<AccountMovement> movements;

  /// Total de movimientos del rango (de todas las páginas).
  final int total;

  const AccountStatementPage({
    required this.summary,
    required this.movements,
    required this.total,
  });
}
