import 'checkout_entity.dart';

/// Cómo se reparte el pago de una cotización entre las formas de pago, por
/// moneda. El servidor exige que lo pagado en cada moneda sea EXACTAMENTE el
/// total de esa moneda, y que el crédito usado no pase del disponible.
class PaymentPlan {
  /// Crédito disponible del cliente (solo se ofrece si es 1 o más).
  final double creditAvailable;

  final List<PaymentLine> _lines = [];

  PaymentPlan({this.creditAvailable = 0});

  List<PaymentLine> get lines => List.unmodifiable(_lines);

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  bool get creditOffered => creditAvailable >= 1;

  bool has(String type, String currency) =>
      _lines.any((l) => l.type == type && l.currency == currency);

  double amountOf(String type, String currency) => _lines
      .where((l) => l.type == type && l.currency == currency)
      .fold(0.0, (s, l) => s + l.amount);

  double paid(String currency) => round2(
        _lines.where((l) => l.currency == currency).fold(0.0, (s, l) => s + l.amount),
      );

  /// Lo que falta pagar en [currency] (negativo si se pasó).
  double remaining(String currency, double total) =>
      round2(total - paid(currency));

  double get _creditUsed => _lines
      .where((l) => PaymentTypeEntity.isCreditCode(l.type))
      .fold(0.0, (s, l) => s + l.amount);

  /// Mayor monto que puede llevar la línea ([type], [currency]): lo que falta
  /// por cubrir más lo que ya tiene, y para el crédito, además, lo que quede
  /// del disponible.
  double maxFor(String type, String currency, double total) {
    final own = amountOf(type, currency);
    var max = remaining(currency, total) + own;
    if (PaymentTypeEntity.isCreditCode(type)) {
      final creditLeft = creditAvailable - (_creditUsed - own);
      if (creditLeft < max) max = creditLeft;
    }
    return round2(max < 0 ? 0 : max);
  }

  /// Agrega la forma de pago con el monto que falta (o la quita si ya estaba).
  void toggle(PaymentTypeEntity type, String currency, double total) {
    if (has(type.code, currency)) {
      _lines.removeWhere((l) => l.type == type.code && l.currency == currency);
      return;
    }
    _lines.add(PaymentLine(
      type: type.code,
      currency: currency,
      amount: maxFor(type.code, currency, total),
    ));
  }

  /// Fija el monto de una línea, limitado a [maxFor].
  void setAmount(String type, String currency, double total, double amount) {
    final index =
        _lines.indexWhere((l) => l.type == type && l.currency == currency);
    if (index < 0) return;
    final max = maxFor(type, currency, total);
    final value = round2(amount.clamp(0, max).toDouble());
    _lines[index] = _lines[index].copyWith(amount: value);
  }

  /// Las líneas con monto 0 no se envían.
  List<PaymentLine> get effectiveLines =>
      _lines.where((l) => l.amount >= 0.01).toList();

  /// true si en cada moneda lo pagado coincide con el total (a un centavo).
  bool isBalanced(Map<String, double> totals) {
    if (totals.isEmpty) return false;
    for (final entry in totals.entries) {
      final paidAmount = round2(effectiveLines
          .where((l) => l.currency == entry.key)
          .fold(0.0, (s, l) => s + l.amount));
      if ((paidAmount - round2(entry.value)).abs() >= 0.01) return false;
    }
    return true;
  }

  /// Quita las líneas de monedas que ya no están en el carrito.
  void keepOnly(Iterable<String> currencies) =>
      _lines.removeWhere((l) => !currencies.contains(l.currency));
}
