import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'price_text.dart';
import 'product_image.dart';
import 'stock_label.dart';

/// Tarjeta de producto para grillas y listas. No conoce la entidad de dominio:
/// recibe datos primitivos para poder reutilizarse en catálogo, favoritos,
/// carrito, etc. Necesita una altura acotada (celda de grilla, `SizedBox`).
///
/// Sigue las reglas de la web: el stock se muestra con sus umbrales; si el
/// precio no es visible (invitado sin lista) se pide iniciar sesión y no hay
/// botón de carrito; sin stock el botón queda deshabilitado.
class ProductCard extends StatelessWidget {
  final String name;
  final String? brand;
  final String? imageUrl;
  final double price;
  final double? oldPrice;
  final String? currency;
  final int stock;
  final bool priceVisible;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.stock,
    this.brand,
    this.imageUrl,
    this.oldPrice,
    this.currency,
    this.priceVisible = true,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppConstants.defaultBorderRadius);
    final available = stock > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La imagen ocupa lo que sobre: así la tarjeta no desborda sea cual
            // sea la altura que le dé la grilla o la lista.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(url: imageUrl),
                  if (!available)
                    Container(color: Colors.white.withValues(alpha: 0.55)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (brand != null)
                    Text(
                      brand!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  StockLabel(stock: stock),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: priceVisible
                            ? PriceText(
                                price: price,
                                oldPrice: oldPrice,
                                currency: currency,
                              )
                            : const LockedPrice(),
                      ),
                      if (priceVisible && onAddToCart != null)
                        IconButton.filled(
                          visualDensity: VisualDensity.compact,
                          onPressed: available ? onAddToCart : null,
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
