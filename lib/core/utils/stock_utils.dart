enum StockLevel { available, few, last, out }

/// Cómo se informa el stock al cliente (igual que el backend y la web): no se
/// muestra la cantidad en existencia sino un mensaje según el rango, con la
/// unidad de medida del producto ("unidad", "set", "par"...).
///
///   0        → "Agotado"
///   1 a 3    → "¡Últimas 3 unidades!" ("¡Última unidad!", "¡Últimos 3 sets!")
///   4 a 9    → "Quedan 7 sets"
///   10 o más → "Disponible: +10 sets"
class StockUtils {
  /// Hasta cuántas unidades se avisa "¡Últimas N!".
  static const int lastMax = 3;

  /// Hasta cuántas unidades se avisa "Quedan N"; desde ahí, "Disponible: +10".
  static const int fewMax = 9;

  /// Lo que se dice cuando el producto no trae unidad.
  static const String defaultUnit = 'unidad';

  static StockLevel level(int stock) {
    if (stock <= 0) return StockLevel.out;
    if (stock <= lastMax) return StockLevel.last;
    if (stock <= fewMax) return StockLevel.few;
    return StockLevel.available;
  }

  /// El mensaje de stock con la [unit] del producto (la del backend).
  static String label(int stock, {String? unit}) {
    final one = _clean(unit);
    final many = plural(one);
    final feminine = isFeminine(one);

    return switch (level(stock)) {
      StockLevel.out => 'Agotado',
      StockLevel.last => stock == 1
          ? (feminine ? '¡Última $one!' : '¡Último $one!')
          : (feminine ? '¡Últimas $stock $many!' : '¡Últimos $stock $many!'),
      StockLevel.few => 'Quedan $stock $many',
      StockLevel.available => 'Disponible: +${fewMax + 1} $many',
    };
  }

  static String _clean(String? unit) {
    final value = (unit ?? '').trim().toLowerCase();
    return value.isEmpty ? defaultUnit : value;
  }

  /// "unidad" → "unidades", "set" → "sets", "par" → "pares", "caja" → "cajas".
  static String plural(String unit) {
    final word = _clean(unit);
    final last = word[word.length - 1];
    if ('aeiouáéíóú'.contains(last)) return '${word}s';
    if (last == 'z') return '${word.substring(0, word.length - 1)}ces';
    if ('lrndj'.contains(last)) return '${word}es';
    return '${word}s';
  }

  /// "unidad", "caja", "docena" son femeninas; "set", "par", "juego", masculinas.
  static bool isFeminine(String unit) =>
      RegExp(r'(a|ad|ión)$').hasMatch(_clean(unit));
}
