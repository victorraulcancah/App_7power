import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'price_text.dart';
import 'product_image.dart';

/// Tarjeta de producto para grillas y listas. No conoce la entidad de dominio:
/// recibe datos primitivos para poder reutilizarse en catálogo, favoritos,
/// carrito, etc.
class ProductCard extends StatelessWidget {
  final String name;
  final String? brand;
  final String? imageUrl;
  final double? price;
  final double? oldPrice;
  final String? currency;
  final bool outOfStock;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.brand,
    this.imageUrl,
    this.oldPrice,
    this.currency,
    this.outOfStock = false,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppConstants.defaultBorderRadius);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(url: imageUrl),
                  if (outOfStock)
                    Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: Text(
                        'Agotado',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: PriceText(
                          price: price,
                          oldPrice: oldPrice,
                          currency: currency,
                        ),
                      ),
                      if (onAddToCart != null)
                        IconButton.filled(
                          visualDensity: VisualDensity.compact,
                          onPressed: outOfStock ? null : onAddToCart,
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
