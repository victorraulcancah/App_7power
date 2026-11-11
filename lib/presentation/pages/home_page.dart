import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_filters.dart';
import '../components/components.dart';
import '../providers/home_provider.dart';
import '../providers/products_provider.dart';
import '../providers/promotions_provider.dart';
import '../utils/app_link.dart';
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
        BrandCarousel(brands: brands, onTap: onOpenBrand),
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
          const ProductGridSkeleton(count: 4, shrinkWrap: true)
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
            // Cada tarjeta entra un poco después de la anterior. La clave
            // incluye la categoría: al cambiarla, las nuevas vuelven a entrar.
            itemBuilder: (context, i) => FadeSlideIn(
              key: ValueKey('rec-${selected ?? 'all'}-${products[i].id}'),
              delay: Duration(milliseconds: 60 * i),
              child: ProductTile(product: products[i]),
            ),
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
      // Ventas flash y banners promocionales: un extra que no frena la portada.
      context.read<PromotionsProvider>().loadHomePromotions();
    });
  }

  /// Abre el destino de un botón de banner o venta flash.
  void _open(String? url) =>
      AppLink.open(context, url, onOpenShop: () => widget.onOpenShop());

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final categories = context.watch<ProductsProvider>().categories;
    final promotions = context.watch<PromotionsProvider>();

    if (home.status != HomeStatus.loaded) {
      return const HomeSkeleton();
    }

    return RefreshIndicator(
      onRefresh: home.load,
      child: ListView(
        children: [
          // El buscador ya no va aquí: está en la barra superior.
          const SizedBox(height: 12),
          BannerCarousel(
            banners: home.banners,
            // Los banners apuntan a páginas de la web: la tienda, un producto,
            // ofertas o cupones se abren en el app; lo demás, en el navegador.
            onTap: (b) {
              if (b.linkUrl != null) _open(b.linkUrl);
            },
          ),
          // Cada sección entra una tras otra, con un leve desvanecido.
          if (promotions.flashSales.isNotEmpty)
            FadeSlideIn(
              child: FlashSalesSection(
                sales: promotions.flashSales,
                onOpen: (sale) => _open(sale.linkUrl),
              ),
            ),
          if (categories.isNotEmpty)
            FadeSlideIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Categorías',
                    onAction: () => widget.onOpenShop(),
                  ),
                  CategoryCarousel(
                    categories: categories,
                    onTap: (c) => widget.onOpenShop(categoryId: c.id),
                  ),
                ],
              ),
            ),
          if (promotions.promoBanners.isNotEmpty)
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: PromoBannersSection(
                banners: promotions.promoBanners,
                onOpen: (banner) => _open(banner.linkUrl),
              ),
            ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: _Recommended(
              categories: categories,
              onOpenShop: widget.onOpenShop,
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 240),
            child: _ShopByBrand(onOpenBrand: widget.onOpenBrand),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
