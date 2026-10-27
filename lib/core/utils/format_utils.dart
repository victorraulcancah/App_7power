import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class FormatUtils {
  // Perú usa coma de miles y punto decimal; el locale es_PE de intl no.
  static final NumberFormat _money =
      NumberFormat.currency(locale: 'en_US', symbol: 'S/ ', decimalDigits: 2);

  /// 1234.5 -> "S/ 1,234.50"
  static String money(num amount) => _money.format(amount);

  /// Acepta números o strings (el backend a veces devuelve decimales como string).
  static double toDouble(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static String date(DateTime date) =>
      DateFormat(AppConstants.dateFormat).format(date);

  static String dateTime(DateTime date) =>
      DateFormat(AppConstants.dateTimeFormat).format(date);
}
