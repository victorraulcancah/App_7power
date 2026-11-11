import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/product_entity.dart';
import '../providers/product_search_provider.dart';
import 'product_image.dart';

/// Un producto de una compra, como en la web: su foto, la marca, el nombre y el
/// código, y a la derecha las unidades y lo que costó. Lo usan el detalle de las
/// compras en línea y el de las compras en tienda.
///
/// Si la compra no trae la foto o la marca (las compras en tienda vienen del
/// ERP, que solo conoce el código), se completan buscando el producto en el
/// catálogo por su código.
class PurchaseItemTile extends StatefulWidget {
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
  State<PurchaseItemTile> createState() => _PurchaseItemTileState();
}

class _PurchaseItemTileState extends State<PurchaseItemTile> {
  Future<ProductEntity?>? _lookup;

  @override
  void initState() {
    super.initState();
    final missing = widget.brand == null || widget.imageUrl == null;
    final code = widget.code;
    if (!missing || code == null) return;

    // Sin el buscador disponible (una prueba aislada) se muestra lo que hay.
    try {
      _lookup = context.read<ProductSearchProvider>().lookupByCode(code);
    } catch (_) {
      _lookup = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = _lookup;
    if (lookup == null) return _content(context, widget.brand, widget.imageUrl);

    return FutureBuilder<ProductEntity?>(
      future: lookup,
      builder: (context, snapshot) {
        final found = snapshot.data;
        return _content(
          context,
          widget.brand ?? found?.brand,
          widget.imageUrl ?? found?.imageUrl,
        );
      },
    );
  }

  Widget _content(BuildContext context, String? brand, String? imageUrl) {
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
                // La marca encima del nombre, en mayúsculas y con más cuerpo
                // que antes para que se note.
                if (brand != null)
                  Text(
                    brand.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                Text(
                  widget.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (widget.code != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.code!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(widget.quantity,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const SizedBox(height: 2),
              Text(
                widget.total,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (widget.unitPrice != null)
                Text(
                  '${widget.unitPrice} c/u',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
