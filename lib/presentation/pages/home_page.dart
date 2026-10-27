import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../components/components.dart';
import '../providers/home_provider.dart';
import '../providers/products_provider.dart';

/// Portada: banners, categorías y productos. No lleva footer: en la app esa
/// función la cumple la barra de navegación inferior.
class HomePage extends StatefulWidget {
  /// Abre la pestaña de tienda, opcionalmente filtrada por categoría.
  final void Function({int? categoryId}) onOpenShop;

  const HomePage({super.key, required this.onOpenShop});

  @override
  State<HomePage> createState() => _HomePageState();
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
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                ),
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(c.name),
                        onPressed: () =>
                            widget.onOpenShop(categoryId: c.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (home.featured.isNotEmpty) ...[
            SectionHeader(
              title: 'Productos',
              onAction: () => widget.onOpenShop(),
            ),
            SizedBox(
              height: 300,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                ),
                itemCount: home.featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = home.featured[i];
                  return SizedBox(
                    width: 170,
                    child: ProductCard(
                      name: p.name,
                      brand: p.brand,
                      imageUrl: p.imageUrl,
                      price: p.price,
                      currency: p.currency,
                      outOfStock: !p.isAvailable,
                    ),
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
