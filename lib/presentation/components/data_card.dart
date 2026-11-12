import 'package:flutter/material.dart';

/// Un dato de una [DataCard]: etiqueta a la izquierda y valor a la derecha.
class DataField {
  final String label;
  final String value;
  final int maxLines;
  final Color? color;
  final bool bold;

  const DataField(
    this.label,
    this.value, {
    this.maxLines = 1,
    this.color,
    this.bold = false,
  });
}

/// Tarjeta para mostrar un registro (un movimiento, una compra, una
/// cotización, un reclamo...) en vez de una tabla, que en el celular no cabe.
///
/// De arriba abajo: un ícono y un rótulo (el código o documento) con las
/// etiquetas de estado a la derecha; las filas "dato / valor"; contenido extra
/// opcional ([children]); y un pie destacado (por ejemplo "Total").
class DataCard extends StatelessWidget {
  /// Ícono redondo de la cabecera y su color.
  final IconData? icon;
  final Color? iconColor;

  /// Rótulo en forma de píldora (el código, el documento).
  final String? badge;

  /// Etiquetas de estado u otros widgets a la derecha de la cabecera.
  final Widget? trailing;

  final List<DataField> fields;

  /// Contenido propio debajo de las filas (una respuesta, un aviso...).
  final List<Widget> children;

  /// Pie destacado: etiqueta a la izquierda y valor en grande a la derecha.
  final String? footerLabel;
  final String? footerValue;
  final Color? footerColor;

  final VoidCallback? onTap;

  /// Ancho reservado a las etiquetas, para que los valores queden alineados.
  final double labelWidth;

  const DataCard({
    super.key,
    this.icon,
    this.iconColor,
    this.badge,
    this.trailing,
    this.fields = const [],
    this.children = const [],
    this.footerLabel,
    this.footerValue,
    this.footerColor,
    this.onTap,
    this.labelWidth = 92,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = iconColor ?? theme.colorScheme.primary;
    final hasHeader = icon != null || badge != null || trailing != null;
    final radius = BorderRadius.circular(16);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFE9E9EC)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasHeader)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: fields.isNotEmpty || children.isNotEmpty ? 12 : 0,
                    ),
                    // Ícono y rótulo a la izquierda; las etiquetas, pegadas a la
                    // derecha (con y sin rótulo, a la misma altura).
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: tint.withValues(alpha: 0.10),
                                  foregroundColor: tint,
                                  child: Icon(icon, size: 17),
                                ),
                                const SizedBox(width: 10),
                              ],
                              if (badge != null)
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F0F2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      badge!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          Flexible(child: trailing!),
                        ],
                      ],
                    ),
                  ),
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: labelWidth,
                          child: Text(
                            field.label,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            field.value,
                            maxLines: field.maxLines,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: field.color,
                              fontWeight:
                                  field.bold ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...children,
                if (footerValue != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      Text(
                        footerLabel ?? '',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        footerValue!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: footerColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
