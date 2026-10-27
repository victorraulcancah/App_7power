import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'login_page.dart';

/// Ícono del carrito con la cantidad de unidades. Abre [CartPage].
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final units = context.select<CartProvider, int>((c) => c.totalUnits);

    return IconButton(
      tooltip: 'Carrito',
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CartPage())),
      icon: Badge(
        isLabelVisible: units > 0,
        label: Text('$units'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi carrito'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              tooltip: 'Vaciar carrito',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context),
            ),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Tu carrito está vacío',
              message: 'Agrega productos desde la tienda.',
              actionLabel: 'Seguir comprando',
              onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 24),
                    itemBuilder: (context, i) =>
                        _CartLine(item: cart.items[i], busy: cart.isBusy),
                  ),
                ),
                _Summary(cart: cart),
              ],
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: const Text('Se quitarán todos los productos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cart.clear();
  }
}

class _CartLine extends StatelessWidget {
  final CartItemEntity item;
  final bool busy;

  const _CartLine({required this.item, required this.busy});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final theme = Theme.of(context);

    Future<void> run(Future<String?> Function() action) async {
      final error = await action();
      if (error != null && context.mounted) AppSnackbar.error(context, error);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductImage(
          url: item.imageUrl,
          width: 72,
          height: 72,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              PriceText(price: item.price, currency: item.currency),
              const SizedBox(height: 8),
              Row(
                children: [
                  Opacity(
                    opacity: busy ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: busy,
                      child: QuantitySelector(
                        value: item.quantity,
                        max: item.stock > 0 ? item.stock : item.quantity,
                        onChanged: (v) =>
                            run(() => cart.setQuantity(item.productId, v)),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Quitar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: busy
                        ? null
                        : () => run(() => cart.remove(item.productId)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final CartProvider cart;

  const _Summary({required this.cart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final totals = cart.totalsByCurrency;

    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in totals.entries)
                Row(
                  children: [
                    Text('Total', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      FormatUtils.money(entry.value, currency: entry.key),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              if (cart.hasItemsWithoutPrice)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Hay productos sin precio: no están incluidos en el total.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              const SizedBox(height: 12),
              AppButton(
                label: auth.isAuthenticated
                    ? 'Finalizar compra'
                    : 'Inicia sesión para comprar',
                icon: auth.isAuthenticated ? Icons.lock_outline : Icons.login,
                onPressed: () {
                  if (!auth.isAuthenticated) {
                    LoginPage.open(context);
                    return;
                  }
                  AppSnackbar.info(
                    context,
                    'El pago estará disponible muy pronto.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
