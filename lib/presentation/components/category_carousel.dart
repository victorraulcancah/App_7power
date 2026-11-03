import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../domain/entities/category_entity.dart';
import 'auto_scroll_row.dart';
import 'product_image.dart';

/// Categorías de la portada en un carril que avanza solo y sin fin. Se detiene
/// al tocarlo o arrastrarlo (ver [AutoScrollRow]).
class CategoryCarousel extends StatelessWidget {
  static const double height = 132;

  final List<CategoryEntity> categories;
  final ValueChanged<CategoryEntity> onTap;

  const CategoryCarousel({
    super.key,
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AutoScrollRow(
      height: height,
      itemCount: categories.length,
      itemBuilder: (context, i, _) => CategoryCard(
        category: categories[i],
        onTap: () => onTap(categories[i]),
      ),
    );
  }
}

/// Tarjeta de una categoría: fondo en degradado rojo suave, su imagen en un
/// círculo con borde blanco y el nombre. Se achica un poco al presionarla.
class CategoryCard extends StatefulWidget {
  static const double width = 96;

  final CategoryEntity category;
  final VoidCallback onTap;

  const CategoryCard({super.key, required this.category, required this.onTap});

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final category = widget.category;

    return AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        width: CategoryCard.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.primaryContainer, Colors.white],
          ),
          border: Border.all(color: primary.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: category.imageUrl == null
                        ? Icon(Icons.category_outlined, color: primary)
                        : ProductImage(url: category.imageUrl),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: Text(
                        FormatUtils.titleCase(category.name),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF26262B),
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
