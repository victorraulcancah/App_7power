import 'package:flutter/material.dart';

/// Selector de cantidad con botones − / +. Para carrito y detalle de producto.
class QuantitySelector extends StatelessWidget {
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  const QuantitySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    final canDecrease = value > min;
    final canIncrease = max == null || value < max!;

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
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
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
