import 'package:flutter/material.dart';

import 'product_image.dart';

/// Un producto de una compra, como en la web: su foto, la marca, el nombre y el
/// código, y a la derecha las unidades y lo que costó. Lo usan el detalle de las
/// compras en línea y el de las compras en tienda.
class PurchaseItemTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? brand;
  final String? code;

  /// "3 un.", ya formateado.
  final String quantity;

  /// Precio de una unidad, ya formateado ("S/ 50.00"). Se muestra solo si hay
  /// más de una unidad (con una, el total de la línea ya es el precio).
  final String? unitPrice;

  /// Lo que costó la línea, ya formateado.
  final String total;

  const PurchaseItemTile({
    super.key,
    required this.name,
    required this.quantity,
    required this.total,
    this.imageUrl,
    this.brand,
    this.code,
    this.unitPrice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // La foto en un recuadro con borde, para que se vea igual aunque cada
          // producto tenga una proporción distinta.
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE6E6E9)),
            ),
            child: ProductImage(
              url: imageUrl,
              width: 64,
              height: 64,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (brand != null)
                  Text(
                    brand!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                Text(
                  name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (code != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Código: $code',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(quantity, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const SizedBox(height: 2),
              Text(
                total,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (unitPrice != null)
                Text(
                  '$unitPrice c/u',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
