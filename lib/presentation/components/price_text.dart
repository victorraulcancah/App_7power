import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';

/// Precio formateado en soles, con precio anterior tachado opcional.
class PriceText extends StatelessWidget {
  final double price;
  final double? oldPrice;
  final TextStyle? style;

  const PriceText({super.key, required this.price, this.oldPrice, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ??
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(FormatUtils.money(price), style: base),
        if (oldPrice != null && oldPrice! > price)
          Text(
            FormatUtils.money(oldPrice!),
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
  }
}
