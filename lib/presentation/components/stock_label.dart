import 'package:flutter/material.dart';

import '../../core/utils/stock_utils.dart';

/// El stock como lo muestra el cliente: "Agotado", "¡Últimas 3 unidades!" (rojo),
/// "Quedan 7 sets" (marrón) o "Disponible: +10 sets" (verde), con la unidad de
/// medida del producto.
class StockLabel extends StatelessWidget {
  final int stock;

  /// Unidad de medida del producto (la del backend); sin ella, "unidad".
  final String? unit;
  final TextStyle? style;

  const StockLabel({super.key, required this.stock, this.unit, this.style});

  /// Los colores del mensaje.
  static Color colorOf(BuildContext context, StockLevel level) => switch (level) {
        StockLevel.available => const Color(0xFF166534),
        StockLevel.few => const Color(0xFF92400E),
        StockLevel.last => const Color(0xFF9B1C1C),
        StockLevel.out => Theme.of(context).colorScheme.onSurface,
      };

  @override
  Widget build(BuildContext context) {
    final level = StockUtils.level(stock);
    final color = colorOf(context, level);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            StockUtils.label(stock, unit: unit),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (style ?? Theme.of(context).textTheme.labelSmall)
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
