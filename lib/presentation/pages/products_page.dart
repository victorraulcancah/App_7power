import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../components/components.dart';
import '../providers/products_provider.dart';
import 'product_detail_page.dart';

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
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: AppSearchField(onSearch: provider.search),
        ),
        if (provider.categories.isNotEmpty) _CategoryFilter(provider: provider),
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
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length + (provider.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= products.length) {
                      return const LoadingIndicator();
                    }
                    final p = products[i];
                    return ProductCard(
                      name: p.name,
                      brand: p.brand,
                      imageUrl: p.imageUrl,
                      price: p.price,
                      currency: p.currency,
                      outOfStock: !p.isAvailable,
                      onTap: () => ProductDetailPage.open(context, p),
                      onAddToCart: () => CartActions.add(context, p),
                    );
                  },
                ),
        );
    }
  }
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
            _chip(c.name, provider.selectedCategoryId == c.id,
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
