import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/product_entity.dart';
import '../../components/components.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../cart_page.dart';
import '../product_detail_page.dart';

/// "Favoritos": los productos que el cliente guardó con el corazón. Se marcan
/// los que se quieren (cada uno con su cantidad) y un solo botón, abajo, los
/// agrega todos al carrito.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  /// Los productos marcados para agregar.
  final Set<int> _selected = {};

  /// La cantidad elegida de cada producto (1 si no se tocó).
  final Map<int, int> _quantities = {};

  bool _adding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().load();
    });
  }

  /// Solo se puede agregar lo que tiene precio visible y stock.
  static bool _buyable(ProductEntity p) => p.priceVisible && p.isAvailable;

  int _quantityOf(ProductEntity p) =>
      (_quantities[p.id] ?? 1).clamp(1, p.stock < 1 ? 1 : p.stock);

  void _toggleAll(List<ProductEntity> items, bool value) {
    setState(() {
      _selected.clear();
      if (value) _selected.addAll(items.where(_buyable).map((p) => p.id));
    });
  }

  Future<void> _addSelected(List<ProductEntity> items) async {
    // Lo marcado que todavía es favorito y se puede comprar.
    final chosen = [
      for (final p in items)
        if (_selected.contains(p.id) && _buyable(p)) p,
    ];
    if (chosen.isEmpty) {
      AppSnackbar.info(context, 'Marca los productos que quieres agregar.');
      return;
    }

    setState(() => _adding = true);
    final cart = context.read<CartProvider>();
    String? firstError;
    var added = 0;
    for (final p in chosen) {
      final error = await cart.add(p, quantity: _quantityOf(p));
      if (error == null) {
        added++;
        _selected.remove(p.id);
        _quantities.remove(p.id);
      } else {
        firstError ??= '${p.name}: $error';
      }
    }
    if (!mounted) return;
    setState(() => _adding = false);

    if (firstError != null) {
      AppSnackbar.error(
        context,
        added == 0 ? firstError : 'Se agregaron $added; $firstError',
      );
    } else {
      AppSnackbar.success(
        context,
        added == 1 ? 'Agregado al carrito' : '$added productos agregados al carrito',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final items = favorites.items;
    // Si un favorito se quitó, su marca ya no cuenta.
    _selected.removeWhere((id) => !items.any((p) => p.id == id));
    final buyable = items.where(_buyable).toList();
    final allSelected =
        buyable.isNotEmpty && buyable.every((p) => _selected.contains(p.id));

    final loaded =
        favorites.status == FavoritesStatus.loaded && items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(items.isEmpty ? 'Favoritos' : 'Favoritos (${items.length})'),
        actions: const [CartButton()],
      ),
      body: switch (favorites.status) {
        FavoritesStatus.initial ||
        FavoritesStatus.loading =>
          const LoadingIndicator(),
        FavoritesStatus.error => ErrorState(
            message: favorites.errorMessage,
            onRetry: favorites.load,
          ),
        FavoritesStatus.loaded => items.isEmpty
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
                  // La fila de "Seleccionar todos" + los productos.
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return _SelectAllRow(
                        value: allSelected,
                        enabled: buyable.isNotEmpty,
                        count: _selected.length,
                        onChanged: (v) => _toggleAll(items, v),
                      );
                    }
                    final p = items[i - 1];
                    return _FavoriteRow(
                      product: p,
                      selected: _selected.contains(p.id),
                      quantity: _quantityOf(p),
                      onSelected: (v) => setState(() {
                        v ? _selected.add(p.id) : _selected.remove(p.id);
                      }),
                      onQuantity: (q) => setState(() => _quantities[p.id] = q),
                    );
                  },
                ),
              ),
      },
      // Un solo botón para agregar todo lo marcado. Va como barra inferior de la
      // pantalla: así los avisos flotantes salen por encima y no lo tapan.
      bottomNavigationBar: loaded
          ? Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  child: AppButton(
                    label: _selected.isEmpty
                        ? 'Agregar al carrito'
                        : 'Agregar al carrito (${_selected.length})',
                    icon: Icons.add_shopping_cart,
                    isLoading: _adding,
                    onPressed: () => _addSelected(items),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// "Seleccionar todos": marca o desmarca todos los favoritos que se pueden
/// agregar.
class _SelectAllRow extends StatelessWidget {
  final bool value;
  final bool enabled;
  final int count;
  final ValueChanged<bool> onChanged;

  const _SelectAllRow({
    required this.value,
    required this.enabled,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
          ),
          Expanded(
            child: Text('Seleccionar todos', style: theme.textTheme.titleSmall),
          ),
          if (count > 0)
            Text(
              count == 1 ? '1 marcado' : '$count marcados',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  final ProductEntity product;
  final bool selected;
  final int quantity;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int> onQuantity;

  const _FavoriteRow({
    required this.product,
    required this.selected,
    required this.quantity,
    required this.onSelected,
    required this.onQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canBuy = product.priceVisible && product.isAvailable;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ProductDetailPage.open(context, product),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Marcar para agregar; sin stock o sin precio no se puede.
                  Checkbox(
                    value: selected && canBuy,
                    onChanged: canBuy ? (v) => onSelected(v ?? false) : null,
                  ),
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
                        StockLabel(stock: product.stock, unit: product.unit),
                        const SizedBox(height: 4),
                        if (product.priceVisible)
                          PriceText(price: product.price, currency: product.currency)
                        else
                          const LockedPrice(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // La cantidad a la izquierda y el corazón (quitar) a la derecha.
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    if (canBuy)
                      QuantitySelector(
                        wide: true,
                        width: 128,
                        value: quantity,
                        max: product.stock,
                        onChanged: onQuantity,
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Quitar de favoritos',
                      icon: const Icon(Icons.favorite),
                      color: theme.colorScheme.error,
                      onPressed: () => _remove(context),
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
        title: const Text('Quitar de favoritos'),
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
