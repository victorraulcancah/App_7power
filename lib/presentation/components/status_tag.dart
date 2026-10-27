import 'package:flutter/material.dart';

enum StatusTagType { success, warning, error, info, neutral }

/// Etiqueta de estado (pedido, pago, stock...).
class StatusTag extends StatelessWidget {
  final String label;
  final StatusTagType type;

  const StatusTag({
    super.key,
    required this.label,
    this.type = StatusTagType.neutral,
  });

  Color _color(BuildContext context) => switch (type) {
        StatusTagType.success => Colors.green,
        StatusTagType.warning => Colors.orange,
        StatusTagType.error => Theme.of(context).colorScheme.error,
        StatusTagType.info => Colors.blue,
        StatusTagType.neutral => Theme.of(context).colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
