import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/product_entity.dart';
import '../../components/components.dart';
import '../../providers/favorites_provider.dart';
import '../cart_page.dart';
import '../product_detail_page.dart';

/// "Mis listas": los productos que el cliente guardó como favoritos.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis listas'), actions: const [CartButton()]),
      body: switch (favorites.status) {
        FavoritesStatus.initial ||
        FavoritesStatus.loading =>
          const LoadingIndicator(),
        FavoritesStatus.error => ErrorState(
            message: favorites.errorMessage,
            onRetry: favorites.load,
          ),
        FavoritesStatus.loaded => favorites.items.isEmpty
            ? EmptyState(
                icon: Icons.favorite_border,
                title: 'Aún no tienes favoritos',
                message: 'Toca el corazón en un producto para guardarlo aquí.',
                actionLabel: 'Ver la tienda',
                onAction: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              )
            : RefreshIndicator(
                onRefresh: favorites.load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: favorites.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _FavoriteRow(product: favorites.items[i]),
                ),
              ),
      },
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  final ProductEntity product;

  const _FavoriteRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canBuy = product.priceVisible && product.isAvailable;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ProductDetailPage.open(context, product),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImage(
                url: product.imageUrl,
                width: 84,
                height: 84,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    StockLabel(stock: product.stock),
                    const SizedBox(height: 4),
                    if (product.priceVisible)
                      PriceText(price: product.price, currency: product.currency)
                    else
                      const LockedPrice(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: canBuy ? 'Agregar' : 'Sin stock',
                            icon: Icons.add_shopping_cart,
                            variant: AppButtonVariant.secondary,
                            onPressed: canBuy
                                ? () => CartActions.add(context, product)
                                : null,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar de mis listas',
                          icon: const Icon(Icons.favorite),
                          color: theme.colorScheme.error,
                          onPressed: () => _remove(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final favorites = context.read<FavoritesProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar de mis listas'),
        content: Text('¿Quitar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await favorites.remove(product);
    if (error != null && context.mounted) AppSnackbar.error(context, error);
  }
}
