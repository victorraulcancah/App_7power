import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/category_entity.dart';
import '../components/components.dart';
import '../providers/home_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_tile.dart';

/// Portada: banners, categorías y productos. No lleva footer: en la app esa
/// función la cumple la barra de navegación inferior.
class HomePage extends StatefulWidget {
  /// Abre la pestaña de tienda, opcionalmente filtrada por categoría.
  final void Function({int? categoryId}) onOpenShop;

  const HomePage({super.key, required this.onOpenShop});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Categoría con su imagen en un círculo y el nombre debajo.
class _CategoryBubble extends StatelessWidget {
  final CategoryEntity category;
  final VoidCallback onTap;

  const _CategoryBubble({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border.all(color: const Color(0xFFE6E6E9)),
              ),
              child: category.imageUrl == null
                  ? Icon(Icons.category_outlined,
                      color: theme.colorScheme.outline)
                  : ProductImage(url: category.imageUrl),
            ),
            const SizedBox(height: 6),
            Text(
              FormatUtils.titleCase(category.name),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final categories = context.watch<ProductsProvider>().categories;

    if (home.status != HomeStatus.loaded) {
      return const LoadingIndicator();
    }

    return RefreshIndicator(
      onRefresh: home.load,
      child: ListView(
        children: [
          BannerCarousel(
            banners: home.banners,
            // Los banners apuntan a rutas de la web; por ahora solo se
            // entiende "/shop".
            onTap: (b) {
              if (b.linkUrl?.startsWith('/shop') ?? false) widget.onOpenShop();
            },
          ),
          if (categories.isNotEmpty) ...[
            const SectionHeader(title: 'Categorías'),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _CategoryBubble(
                  category: categories[i],
                  onTap: () => widget.onOpenShop(categoryId: categories[i].id),
                ),
              ),
            ),
          ],
          if (home.featured.isNotEmpty) ...[
            SectionHeader(
              title: 'Productos',
              onAction: () => widget.onOpenShop(),
            ),
            SizedBox(
              height: 330,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                ),
                itemCount: home.featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  return SizedBox(
                    width: 170,
                    child: ProductTile(product: home.featured[i]),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
