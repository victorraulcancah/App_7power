import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_filters.dart';
import '../components/components.dart';
import '../providers/home_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_tile.dart';
import 'brands_page.dart';

/// Portada: banners, categorías y productos. No lleva footer: en la app esa
/// función la cumple la barra de navegación inferior.
class HomePage extends StatefulWidget {
  /// Abre la pestaña de tienda, opcionalmente filtrada por categoría.
  final void Function({int? categoryId}) onOpenShop;

  /// Abre la pestaña de tienda con esa marca filtrada.
  final ValueChanged<BrandEntity> onOpenBrand;

  const HomePage({
    super.key,
    required this.onOpenShop,
    required this.onOpenBrand,
  });

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

/// "Comprar por marcas": los logos de las marcas (primero las de la vitrina);
/// al tocar uno se abre la tienda con esa marca.
class _ShopByBrand extends StatelessWidget {
  static const int maxBrands = 12;

  final ValueChanged<BrandEntity> onOpenBrand;

  const _ShopByBrand({required this.onOpenBrand});

  @override
  Widget build(BuildContext context) {
    final all = BrandsPage.sorted(context.watch<ProductsProvider>().brands);
    if (all.isEmpty) return const SizedBox.shrink();

    final brands = all.take(maxBrands).toList();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Comprar por marcas',
          actionLabel: 'Ver todas',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BrandsPage(onSelected: onOpenBrand),
          )),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
            ),
            itemCount: brands.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final brand = brands[i];
              return InkWell(
                key: Key('home-brand-${brand.id}'),
                onTap: () => onOpenBrand(brand),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 76,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE6E6E9)),
                        ),
                        child: brand.imageUrl == null
                            ? Center(
                                child: Text(
                                  brand.name,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium,
                                ),
                              )
                            : ProductImage(
                                url: brand.imageUrl,
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        brand.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// "Recomendado para ti": pestañas por categoría ("Todo" y cada una) y una
/// cuadrícula de productos, como en la web.
class _Recommended extends StatelessWidget {
  final List<CategoryEntity> categories;
  final void Function({int? categoryId}) onOpenShop;

  const _Recommended({required this.categories, required this.onOpenShop});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final selected = home.recommendedCategoryId;
    final products = home.recommended;

    // Sin productos y sin categorías elegidas no hay nada que recomendar.
    if (products.isEmpty && selected == null && !home.isLoadingRecommended) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recomendado para ti',
          onAction: () => onOpenShop(categoryId: selected),
        ),
        if (categories.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
              ),
              itemCount: categories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final category = i == 0 ? null : categories[i - 1];
                return ChoiceChip(
                  key: Key('recommended-${category?.id ?? 'all'}'),
                  label: Text(
                    category == null
                        ? 'Todo'
                        : FormatUtils.titleCase(category.name),
                  ),
                  selected: selected == category?.id,
                  // La elegida se rellena con el color de la marca (ver el
                  // tema de los chips); sin borde para que no se vea doble.
                  side: selected == category?.id ? BorderSide.none : null,
                  onSelected: (_) =>
                      home.selectRecommendedCategory(category?.id),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        if (home.isLoadingRecommended)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No hay productos en esta categoría.')),
          )
        else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            itemCount: products.length,
            itemBuilder: (context, i) => ProductTile(product: products[i]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.defaultPadding,
              16,
              AppConstants.defaultPadding,
              0,
            ),
            child: OutlinedButton(
              onPressed: () => onOpenShop(categoryId: selected),
              child: const Text('Ver más productos'),
            ),
          ),
        ],
      ],
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
          _Recommended(
            categories: categories,
            onOpenShop: widget.onOpenShop,
          ),
          _ShopByBrand(onOpenBrand: widget.onOpenBrand),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
