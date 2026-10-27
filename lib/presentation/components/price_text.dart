import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';

/// Precio formateado, con precio anterior tachado opcional. Si el producto no
/// tiene precio (0 o null) muestra [noPriceLabel].
class PriceText extends StatelessWidget {
  final double? price;
  final double? oldPrice;
  final String? currency;
  final String noPriceLabel;
  final TextStyle? style;

  const PriceText({
    super.key,
    required this.price,
    this.oldPrice,
    this.currency,
    this.noPriceLabel = 'Consultar precio',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = style ??
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        );

    if (price == null || price! <= 0) {
      return Text(
        noPriceLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(FormatUtils.money(price!, currency: currency), style: base),
        if (oldPrice != null && oldPrice! > price!)
          Text(
            FormatUtils.money(oldPrice!, currency: currency),
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
  }
}
