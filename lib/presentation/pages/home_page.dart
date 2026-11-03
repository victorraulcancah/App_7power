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

  /// Abre la tienda con los resultados de lo que se buscó.
  final ValueChanged<String> onSearch;

  const HomePage({
    super.key,
    required this.onOpenShop,
    required this.onOpenBrand,
    required this.onSearch,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Buscador de la portada, como el de la web: al enviar el texto se abre la
/// tienda con los resultados (no busca mientras se escribe).
class _HomeSearch extends StatefulWidget {
  final ValueChanged<String> onSearch;

  const _HomeSearch({required this.onSearch});

  @override
  State<_HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends State<_HomeSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    // Queda vacío para la próxima vez que se vuelva al inicio.
    _controller.clear();
    widget.onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.defaultPadding,
        AppConstants.defaultPadding,
        AppConstants.defaultPadding,
        12,
      ),
      child: SearchBox(
        child: TextField(
          key: const Key('home-search'),
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          decoration: SearchBox.decoration(
            context,
            hint: 'Buscar productos, marcas o códigos',
            suffix: SearchSubmitButton(onPressed: _submit),
          ),
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
          _HomeSearch(onSearch: widget.onSearch),
          BannerCarousel(
            banners: home.banners,
            // Los banners apuntan a rutas de la web; por ahora solo se
            // entiende "/shop".
            onTap: (b) {
              if (b.linkUrl?.startsWith('/shop') ?? false) widget.onOpenShop();
            },
          ),
          // Cada sección entra una tras otra, con un leve desvanecido.
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
