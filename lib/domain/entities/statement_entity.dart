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
