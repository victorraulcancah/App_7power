import 'package:flutter/material.dart';

import '../../core/utils/stock_utils.dart';

/// Stock con el formato de la web: verde "+10 unidades", ámbar con la cantidad
/// de 1 a 10, rojo "Agotado".
class StockLabel extends StatelessWidget {
  final int stock;
  final TextStyle? style;

  const StockLabel({super.key, required this.stock, this.style});

  @override
  Widget build(BuildContext context) {
    final color = switch (StockUtils.level(stock)) {
      StockLevel.high => Colors.green.shade700,
      StockLevel.low => Colors.orange.shade800,
      StockLevel.out => Theme.of(context).colorScheme.error,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inventory_2_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            StockUtils.label(stock),
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
