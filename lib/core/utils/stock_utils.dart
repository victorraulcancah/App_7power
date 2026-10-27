enum StockLevel { high, low, out }

/// Cómo se informa el stock, igual que en la web: por encima de 10 no se
/// revela la cantidad real ("+10 unidades"); de 1 a 10 se muestra el número;
/// en 0 el producto está agotado.
class StockUtils {
  static const int highThreshold = 10;

  static StockLevel level(int stock) {
    if (stock > highThreshold) return StockLevel.high;
    if (stock > 0) return StockLevel.low;
    return StockLevel.out;
  }

  /// "Stock: +10 unidades", "Stock: 4 unidades" o "Agotado".
  static String label(int stock) => switch (level(stock)) {
        StockLevel.high => 'Stock: +$highThreshold unidades',
        StockLevel.low => 'Stock: $stock unidades',
        StockLevel.out => 'Agotado',
      };

  /// "+10 unidades" o "4 unidades" (ficha del producto: "Disponible: ...").
  static String units(int stock) =>
      stock > highThreshold ? '+$highThreshold unidades' : '$stock unidades';
}
