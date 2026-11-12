enum StockLevel { available, few, last, out }

/// Cómo se informa el stock al cliente (igual que el backend y la web): no se
/// muestra la cantidad en existencia sino un mensaje según el rango.
///
///   0        → "Agotado"
///   1 a 3    → "¡Últimas N unidades!" (o "¡Última unidad!")
///   4 a 9    → "Quedan N unidades"
///   10 o más → "Disponible"
class StockUtils {
  /// Hasta cuántas unidades se avisa "¡Últimas N unidades!".
  static const int lastMax = 3;

  /// Hasta cuántas unidades se avisa "Quedan N unidades"; desde ahí, "Disponible".
  static const int fewMax = 9;

  static StockLevel level(int stock) {
    if (stock <= 0) return StockLevel.out;
    if (stock <= lastMax) return StockLevel.last;
    if (stock <= fewMax) return StockLevel.few;
    return StockLevel.available;
  }

  static String label(int stock) => switch (level(stock)) {
        StockLevel.out => 'Agotado',
        StockLevel.last => stock == 1 ? '¡Última unidad!' : '¡Últimas $stock unidades!',
        StockLevel.few => 'Quedan $stock unidades',
        StockLevel.available => 'Disponible',
      };
}
