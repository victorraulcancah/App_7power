import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../components/components.dart';
import '../providers/products_provider.dart';
import '../../domain/entities/product_filters.dart';
import '../widgets/product_filters_sheet.dart';
import '../widgets/product_tile.dart';

/// Catálogo de productos de la tienda (pestaña "Tienda").
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.defaultPadding,
            AppConstants.defaultPadding,
            AppConstants.defaultPadding,
            8,
          ),
          child: Row(
            children: [
              Expanded(child: AppSearchField(onSearch: provider.search)),
              const SizedBox(width: 8),
              _FilterButton(provider: provider),
            ],
          ),
        ),
        if (provider.categories.isNotEmpty) _CategoryFilter(provider: provider),
        if (provider.filters.isActive) _ActiveFilters(provider: provider),
        if (provider.status == ProductsStatus.loaded)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
              vertical: 6,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                provider.total == 1 ? '1 producto' : '${provider.total} productos',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ),
        Expanded(child: _body(provider)),
      ],
    );
  }

  Widget _body(ProductsProvider provider) {
    switch (provider.status) {
      case ProductsStatus.initial:
      case ProductsStatus.loading:
        return const LoadingIndicator(message: 'Cargando productos...');
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
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    title: 'Sin productos',
                    message: 'No encontramos productos con ese filtro.',
                  ),
                ])
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
                    return ProductTile(product: products[i]);
                  },
                ),
        );
    }
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
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.defaultPadding),
        children: [
          for (final id in filters.brandIds)
            _chip(
              brandNames[id] ?? 'Marca',
              () => provider.applyFilters(filters.copyWith(
                brandIds: {...filters.brandIds}..remove(id),
              )),
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
            onPressed: provider.clearFilters,
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

class _CategoryFilter extends StatelessWidget {
  final ProductsProvider provider;

  const _CategoryFilter({required this.provider});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
        ),
        children: [
          _chip('Todos', provider.selectedCategoryId == null,
              () => provider.selectCategory(null)),
          for (final c in provider.categories)
            _chip(FormatUtils.titleCase(c.name), provider.selectedCategoryId == c.id,
                () => provider.selectCategory(c.id)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
