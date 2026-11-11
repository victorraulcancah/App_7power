import 'package:flutter/material.dart';

/// Selector de cantidad con botones − / +. Para carrito y detalle de producto.
class QuantitySelector extends StatelessWidget {
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  /// Unidad de medida que se escribe junto al número ("5 un"). Sin ella, solo
  /// el número.
  final String? unit;

  /// Barra a todo lo ancho (como el carrito de las tiendas grandes): fondo gris
  /// con el − y el + en los extremos y la cantidad en una caja blanca al centro.
  final bool wide;

  const QuantitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.unit,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > min;
    final canIncrease = max == null || value < max!;
    final label = unit == null ? '$value' : '$value $unit';

    if (wide) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        height: 46,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: canDecrease ? () => onChanged(value - 1) : null,
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: canIncrease ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove),
            onPressed: canDecrease ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: unit == null ? 32 : 56,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add),
            onPressed: canIncrease ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
