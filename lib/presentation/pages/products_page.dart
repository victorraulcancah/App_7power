import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../components/components.dart';
import '../providers/products_provider.dart';
import '../../domain/entities/product_filters.dart';
import '../widgets/product_filters_sheet.dart';
import '../widgets/product_tile.dart';
import 'cart_page.dart';

/// Catálogo de productos de la tienda (pestaña "Tienda").
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  /// Cuántas tarjetas entran con animación al cargar la lista.
  static const int _animatedTiles = 12;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsProvider>().init();
    });
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) {
      context.read<ProductsProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();

    // Sin barra superior: la pantalla empieza por el buscador, el filtro y el
    // carrito, por debajo de la hora y la batería del teléfono.
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.defaultPadding,
              12,
              6,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    onSearch: provider.search,
                    initialValue: provider.query,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(provider: provider),
                const SizedBox(width: 2),
                const CartButton(plain: true),
              ],
            ),
          ),
          if (provider.categories.isNotEmpty)
            _CategoryFilter(provider: provider),
          if (provider.filters.isActive || provider.query.isNotEmpty)
            _ActiveFilters(provider: provider),
          if (provider.status == ProductsStatus.loaded)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
                vertical: 6,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  provider.total == 1
                      ? '1 producto'
                      : '${provider.total} productos',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
          Expanded(child: _body(provider)),
        ],
      ),
    );
  }

  Widget _body(ProductsProvider provider) {
    switch (provider.status) {
      case ProductsStatus.initial:
      case ProductsStatus.loading:
        return const ProductGridSkeleton(count: 8);
      case ProductsStatus.error:
        return ErrorState(
          message: provider.errorMessage,
          onRetry: provider.loadProducts,
        );
      case ProductsStatus.loaded:
        final products = provider.products;
        return RefreshIndicator(
          onRefresh: provider.loadProducts,
          child: products.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    _NoResults(provider: provider),
                  ],
                )
              : GridView.builder(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length + (provider.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= products.length) {
                      return const LoadingIndicator();
                    }
                    final tile = ProductTile(product: products[i]);
                    // Solo las primeras entran con animación: las que llegan al
                    // paginar o al volver atrás aparecen sin más.
                    if (i >= _animatedTiles) return tile;
                    return FadeSlideIn(
                      key: ValueKey(products[i].id),
                      delay: Duration(milliseconds: 45 * (i % 8)),
                      child: tile,
                    );
                  },
                ),
        );
    }
  }
}

/// Sin resultados: dice qué combinación se pidió y deja quitarla con un toque,
/// en vez de dejar un callejón sin salida.
class _NoResults extends StatelessWidget {
  final ProductsProvider provider;

  const _NoResults({required this.provider});

  @override
  Widget build(BuildContext context) {
    final filters = provider.filters;
    final category = provider.selectedCategoryName;
    final brandNames = [
      for (final b in provider.brands)
        if (filters.brandIds.contains(b.id)) b.name,
    ];

    final parts = <String>[
      if (brandNames.isNotEmpty) brandNames.join(' o '),
      if (category != null) FormatUtils.titleCase(category),
      if (filters.hasPriceRange) 'ese rango de precio',
      if (provider.query.isNotEmpty) '"${provider.query}"',
    ];

    final canClearFilters = filters.isActive;
    final canClearSearch = provider.query.isNotEmpty;
    final canClearCategory = provider.selectedCategoryId != null;

    return Column(
      children: [
        EmptyState(
          title: 'Sin productos',
          message: parts.length > 1
              ? 'No hay productos con la combinación: ${parts.join(' + ')}.'
              : parts.length == 1
              ? 'No encontramos productos con ${parts.single}.'
              : 'No encontramos productos con ese filtro.',
          actionLabel: canClearFilters
              ? 'Quitar filtros'
              : canClearSearch
              ? 'Quitar la búsqueda'
              : (canClearCategory ? 'Ver todas las categorías' : null),
          onAction: canClearFilters
              ? provider.clearFilters
              : canClearSearch
              ? provider.clearSearch
              : (canClearCategory ? () => provider.selectCategory(null) : null),
        ),
        // Con filtros y categoría a la vez, también se puede soltar solo la
        // categoría.
        if (canClearFilters && canClearCategory)
          TextButton(
            onPressed: () => provider.selectCategory(null),
            child: const Text('Ver todas las categorías'),
          ),
      ],
    );
  }
}

/// Botón de filtros con la cantidad de filtros activos.
class _FilterButton extends StatelessWidget {
  final ProductsProvider provider;

  const _FilterButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final count = provider.filters.activeCount;
    final theme = Theme.of(context);

    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      child: IconButton.filledTonal(
        tooltip: 'Filtros',
        onPressed: () => showProductFilters(context, provider),
        style: IconButton.styleFrom(
          minimumSize: const Size(52, 52),
          backgroundColor: count > 0
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: count > 0
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ),
        icon: const Icon(Icons.tune),
      ),
    );
  }
}

/// Los filtros en uso, cada uno con su "x" para quitarlo.
class _ActiveFilters extends StatelessWidget {
  final ProductsProvider provider;

  const _ActiveFilters({required this.provider});

  @override
  Widget build(BuildContext context) {
    final filters = provider.filters;
    final brandNames = {for (final b in provider.brands) b.id: b.name};
    final currency = provider.products.firstOrNull?.currency;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
        ),
        children: [
          // La búsqueda también es un filtro: se ve y se quita desde aquí.
          if (provider.query.isNotEmpty)
            _chip('"${provider.query}"', provider.clearSearch),
          for (final id in filters.brandIds)
            _chip(
              brandNames[id] ?? 'Marca',
              () => provider.applyFilters(
                filters.copyWith(brandIds: {...filters.brandIds}..remove(id)),
              ),
            ),
          if (filters.hasPriceRange)
            _chip(
              '${FormatUtils.money(filters.minPrice ?? 0, currency: currency)}'
              ' – ${FormatUtils.money(filters.maxPrice ?? 0, currency: currency)}',
              () => provider.applyFilters(filters.copyWith(clearPrice: true)),
            ),
          if (filters.sort != ProductSort.relevance)
            _chip(
              filters.sort.label,
              () => provider.applyFilters(
                filters.copyWith(sort: ProductSort.relevance),
              ),
            ),
          TextButton(
            onPressed: provider.clearAll,
            child: const Text('Limpiar todo'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InputChip(label: Text(label), onDeleted: onDeleted),
  );
}

class _CategoryFilter extends StatefulWidget {
  final ProductsProvider provider;

  const _CategoryFilter({required this.provider});

  @override
  State<_CategoryFilter> createState() => _CategoryFilterState();
}

class _CategoryFilterState extends State<_CategoryFilter> {
  /// Una llave por chip, para llevar el elegido a la vista: con más de treinta
  /// categorías, el elegido (por ejemplo, venido de la portada) quedaba fuera
  /// de la pantalla y no se sabía por qué la lista salía filtrada.
  final Map<int?, GlobalKey> _keys = {};

  GlobalKey _keyFor(int? id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(_CategoryFilter old) {
    super.didUpdateWidget(old);
    if (old.provider.selectedCategoryId != widget.provider.selectedCategoryId ||
        old.provider.categories.length != widget.provider.categories.length) {
      _revealSelected();
    }
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keyFor(widget.provider.selectedCategoryId)
          .currentContext;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
        ),
        children: [
          _chip(
            null,
            'Todos',
            provider.selectedCategoryId == null,
            () => provider.selectCategory(null),
          ),
          for (final c in provider.categories)
            _chip(
              c.id,
              FormatUtils.titleCase(c.name),
              provider.selectedCategoryId == c.id,
              () => provider.selectCategory(c.id),
            ),
        ],
      ),
    );
  }

  Widget _chip(int? id, String label, bool selected, VoidCallback onTap) =>
      Padding(
        key: _keyFor(id),
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
