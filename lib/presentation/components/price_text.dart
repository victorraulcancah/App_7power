import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';

/// Precio formateado, con precio anterior tachado opcional. Un precio 0 se
/// muestra como "S/ 0.00", igual que la web; lo que se oculta a los invitados
/// sin lista de precios es responsabilidad de [LockedPrice].
class PriceText extends StatelessWidget {
  final double price;
  final double? oldPrice;
  final String? currency;
  final TextStyle? style;

  const PriceText({
    super.key,
    required this.price,
    this.oldPrice,
    this.currency,
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

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(FormatUtils.money(price, currency: currency), style: base),
        if (oldPrice != null && oldPrice! > price)
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

/// "Precio solo para clientes": lo que ve un invitado cuando el backend oculta
/// el precio (`precio_visible: false`).
class LockedPrice extends StatelessWidget {
  final TextStyle? style;

  const LockedPrice({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Precio solo para clientes',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style ??
                theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ],
    );
  }
}
