import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'motion.dart';
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

  /// Código del producto ("Código: DRV2"), como en la ficha y el carrito.
  final String? code;
  final String? imageUrl;
  final double price;
  final double? oldPrice;
  final String? currency;
  final int stock;
  final bool priceVisible;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  /// Acción sobre la esquina de la imagen (el corazón de favoritos).
  final Widget? topAction;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.stock,
    this.brand,
    this.code,
    this.imageUrl,
    this.oldPrice,
    this.currency,
    this.priceVisible = true,
    this.onTap,
    this.onAddToCart,
    this.topAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppConstants.defaultBorderRadius);
    final available = stock > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      // Borde en rojo suave, como la tarjeta de la web.
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
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
                  // La foto completa dentro de su cuadro (sin recortarla), sobre
                  // blanco, como en los catálogos de las tiendas grandes.
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: ProductImage(url: imageUrl, fit: BoxFit.contain),
                  ),
                  if (!available)
                    Container(color: Colors.white.withValues(alpha: 0.55)),
                  if (topAction != null)
                    Positioned(top: 4, right: 4, child: topAction!),
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
                  if (code != null && code!.isNotEmpty)
                    Text(
                      code!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
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
                        _AddToCartButton(
                          onPressed: available ? onAddToCart : null,
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

/// Rojo suave con ícono rojo: el "Agregar al carrito" de la web. Rebota cada vez
/// que se toca, para confirmar que respondió.
class _AddToCartButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _AddToCartButton({required this.onPressed});

  @override
  State<_AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<_AddToCartButton> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onPressed = widget.onPressed;

    return Bounce(
      trigger: _taps,
      peak: 1.35,
      child: IconButton.filled(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.primary,
          disabledBackgroundColor: colors.surfaceContainerHighest,
        ),
        onPressed: onPressed == null
            ? null
            : () {
                setState(() => _taps++);
                onPressed();
              },
        icon: const Icon(Icons.add_shopping_cart, size: 18),
      ),
    );
  }
}
