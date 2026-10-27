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

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  void initState() {
    super.initState();
    // Al abrir el carrito se refrescan precios y stock (la web hace lo mismo
    // con el carrito de invitado: su copia local puede estar desactualizada).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().load();
    });
  }

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
    final loggedIn = context.watch<AuthProvider>().isAuthenticated;

    // Igual que la web: el invitado solo ve el precio si es mayor que 0;
    // con sesión se muestra siempre.
    final showPrice = loggedIn || item.hasPrice;

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
              if (item.code != null)
                Text('Código: ${item.code}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 2),
              StockLabel(stock: item.stock),
              const SizedBox(height: 4),
              if (showPrice)
                PriceText(price: item.price, currency: item.currency)
              else
                const LockedPrice(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Opacity(
                    opacity: busy ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: busy,
                      child: QuantitySelector(
                        value: item.quantity,
                        // Como la web: tope en el stock (o 1 si no hay dato).
                        max: item.stock > 0 ? item.stock : 1,
                        onChanged: (v) =>
                            run(() => cart.setQuantity(item.productId, v)),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (showPrice)
                    Text(
                      FormatUtils.money(item.subtotal, currency: item.currency),
                      style: theme.textTheme.titleSmall,
                    ),
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
    final loggedIn = context.watch<AuthProvider>().isAuthenticated;
    final summaries = cart.summaries;

    // Totales: cliente con sesión, o invitado cuyos productos tienen todos
    // precio público. Si no, se pide iniciar sesión.
    final showTotals = loggedIn || cart.allItemsPriced;

    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!showTotals)
                _LockedSummary(onLogin: () => LoginPage.open(context))
              else ...[
                for (final s in summaries)
                  Row(
                    children: [
                      Text('Subtotal (${s.units} items)',
                          style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(FormatUtils.money(s.total, currency: s.currency)),
                    ],
                  ),
                const Divider(),
                for (final s in summaries)
                  Row(
                    children: [
                      Text(
                        // Con varias monedas se indica a cuál corresponde.
                        summaries.length > 1
                            ? 'Total ${s.currency == 'd' ? 'US\$' : 'S/'}'
                            : 'Total',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        FormatUtils.money(s.total, currency: s.currency),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 12),
              AppButton(
                label: loggedIn ? 'Pagar' : 'Inicia sesión para pagar',
                icon: loggedIn ? Icons.credit_card : Icons.login,
                onPressed: () {
                  if (!loggedIn) {
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

class _LockedSummary extends StatelessWidget {
  final VoidCallback onLogin;

  const _LockedSummary({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: theme.colorScheme.error),
          const SizedBox(height: 4),
          Text('Precios solo para clientes',
              style: theme.textTheme.titleSmall),
          Text(
            'Inicia sesión para ver el subtotal y total de tu pedido.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
