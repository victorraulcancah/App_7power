import 'package:flutter/material.dart';

import '../../domain/entities/product_filters.dart';
import 'auto_scroll_row.dart';
import 'product_image.dart';

/// Marcas de la portada en una fila que avanza sola y sin fin, un poco más
/// lenta que la de categorías (ver [AutoScrollRow]).
class BrandCarousel extends StatelessWidget {
  static const double height = 150;

  final List<BrandEntity> brands;
  final ValueChanged<BrandEntity> onTap;

  const BrandCarousel({super.key, required this.brands, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AutoScrollRow(
      height: height,
      speed: 20,
      itemCount: brands.length,
      itemBuilder: (context, i, looped) => BrandCard(
        // La clave solo va en la primera pasada: en las repeticiones habría dos
        // tarjetas con la misma.
        key: looped ? null : Key('home-brand-${brands[i].id}'),
        brand: brands[i],
        onTap: () => onTap(brands[i]),
      ),
    );
  }
}

/// Tarjeta de una marca: el logo sobre fondo blanco y, debajo, el nombre y
/// cuántos productos tiene, todo dentro de la misma tarjeta con borde y sombra
/// en rojo suave. Se achica un poco al presionarla.
class BrandCard extends StatefulWidget {
  static const double width = 112;

  final BrandEntity brand;
  final VoidCallback onTap;

  const BrandCard({super.key, required this.brand, required this.onTap});

  @override
  State<BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<BrandCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final brand = widget.brand;
    final radius = BorderRadius.circular(18);

    return AnimatedScale(
      scale: _pressed ? 0.95 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        width: BrandCard.width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: primary.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // El toque (y su onda) queda dentro de la tarjeta, no en un rectángulo
        // suelto alrededor del texto.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: Center(
                      // Sin logo: la inicial en un círculo (el nombre ya va abajo).
                      child: brand.imageUrl == null
                          ? CircleAvatar(
                              radius: 26,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              foregroundColor: primary,
                              child: Text(
                                brand.name.isEmpty
                                    ? '?'
                                    : brand.name.substring(0, 1).toUpperCase(),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ProductImage(url: brand.imageUrl, fit: BoxFit.contain),
                    ),
                  ),
                ),
                // Franja de abajo con el nombre y la cantidad de productos.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        brand.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF26262B),
                        ),
                      ),
                      Text(
                        brand.productsCount == 1
                            ? '1 producto'
                            : '${brand.productsCount} productos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
