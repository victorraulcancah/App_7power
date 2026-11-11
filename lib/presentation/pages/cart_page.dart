import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';
import 'checkout/checkout_page.dart';
import 'login_page.dart';

/// Ícono del carrito con la cantidad de unidades. Abre [CartPage].
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final units = context.select<CartProvider, int>((c) => c.totalUnits);
    final theme = Theme.of(context);

    // Botón claro sobre el navbar (que es del color de marca): así se ve el
    // carrito aunque el navbar sea negro. La cantidad va en ámbar.
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'Carrito',
        child: Material(
          color: theme.colorScheme.onPrimary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CartPage())),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                // Rebota cada vez que cambia la cantidad (al agregar algo).
                child: Bounce(
                  trigger: units,
                  child: Badge(
                    isLabelVisible: units > 0,
                    label: Text(
                      '$units',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: const Color(0xFFFFC107),
                    child: Icon(
                      Icons.shopping_cart_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
    final active = cart.items;
    final saved = cart.savedItems;

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
      body: cart.isEmpty && saved.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Tu carrito está vacío',
              message: 'Agrega productos desde la tienda.',
              actionLabel: 'Seguir comprando',
              onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
            )
          : Column(
              children: [
                const _EditingQuoteBanner(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    children: [
                      if (active.isEmpty)
                        const _EmptyActiveCart()
                      else
                        for (var i = 0; i < active.length; i++) ...[
                          if (i > 0) const Divider(height: 24),
                          _CartLine(item: active[i], busy: cart.isBusy),
                        ],
                      if (saved.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SavedSection(items: saved, busy: cart.isBusy),
                      ],
                    ],
                  ),
                ),
                // Sin nada en el pedido no hay total ni botones de pago.
                if (active.isNotEmpty) _Summary(cart: cart),
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

/// Mientras se edita una cotización: recuerda que al cotizar de nuevo la
/// reemplaza, y deja desistir.
class _EditingQuoteBanner extends StatelessWidget {
  const _EditingQuoteBanner();

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    if (!checkout.isEditingQuote) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
          vertical: 8,
        ),
        child: Row(
          children: [
            Icon(Icons.edit_note, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Editando la cotización ${checkout.editingQuoteCode}. Al '
                'cotizar, la nueva la reemplaza.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: checkout.stopEditingQuote,
              child: const Text('Dejar de editar'),
            ),
          ],
        ),
      ),
    );
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

    /// Corre la acción y avisa si falló. Devuelve true si salió bien.
    Future<bool> run(Future<String?> Function() action) async {
      final error = await action();
      if (error != null && context.mounted) AppSnackbar.error(context, error);
      return error == null;
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium),
                  ),
                  // Los 3 puntos: guardar para después o eliminar.
                  _LineMenu(
                    enabled: !busy,
                    onSave: () async {
                      final ok = await run(() => cart.saveForLater(item.productId));
                      if (ok && context.mounted) {
                        AppSnackbar.success(context, 'Guardado para después');
                      }
                    },
                    onRemove: () => run(() => cart.remove(item.productId)),
                  ),
                ],
              ),
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
              // En pantallas angostas el total baja a la línea de abajo.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Opacity(
                    opacity: busy ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: busy,
                      child: QuantitySelector(
                        value: item.quantity,
                        // Unidad de medida: los productos se venden por unidad.
                        unit: 'un',
                        // Como la web: tope en el stock (o 1 si no hay dato).
                        max: item.stock > 0 ? item.stock : 1,
                        onChanged: (v) =>
                            run(() => cart.setQuantity(item.productId, v)),
                      ),
                    ),
                  ),
                  if (showPrice)
                    Text(
                      FormatUtils.money(item.subtotal, currency: item.currency),
                      style: theme.textTheme.titleSmall,
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

/// Los 3 puntos de cada producto del carrito.
class _LineMenu extends StatelessWidget {
  final bool enabled;
  final VoidCallback onSave;
  final VoidCallback onRemove;

  const _LineMenu({
    required this.enabled,
    required this.onSave,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;

    return SizedBox(
      width: 36,
      height: 32,
      child: PopupMenuButton<_LineAction>(
        tooltip: 'Más opciones',
        enabled: enabled,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert),
        onSelected: (action) =>
            action == _LineAction.save ? onSave() : onRemove(),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: _LineAction.save,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bookmark_border),
              title: Text('Guardar para después'),
            ),
          ),
          PopupMenuItem(
            value: _LineAction.remove,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: error),
              title: Text('Eliminar', style: TextStyle(color: error)),
            ),
          ),
        ],
      ),
    );
  }
}

enum _LineAction { save, remove }

/// Cuando todo lo del carrito se guardó para después.
class _EmptyActiveCart extends StatelessWidget {
  const _EmptyActiveCart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('Tu carrito está vacío', style: theme.textTheme.titleMedium),
          Text(
            'Lo que guardaste para después está aquí abajo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

/// "Guardados para después (N)": no cuentan en el pedido hasta volver al carrito.
class _SavedSection extends StatelessWidget {
  final List<CartItemEntity> items;
  final bool busy;

  const _SavedSection({required this.items, required this.busy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.read<CartProvider>();
    final loggedIn = context.watch<AuthProvider>().isAuthenticated;

    Future<bool> run(Future<String?> Function() action) async {
      final error = await action();
      if (error != null && context.mounted) AppSnackbar.error(context, error);
      return error == null;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guardados para después (${items.length})',
            style: theme.textTheme.titleMedium,
          ),
          for (final item in items) ...[
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImage(
                  url: item.imageUrl,
                  width: 64,
                  height: 64,
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
                      const SizedBox(height: 4),
                      if (loggedIn || item.hasPrice)
                        PriceText(price: item.price, currency: item.currency)
                      else
                        const LockedPrice(),
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: busy
                                ? null
                                : () async {
                                    final ok = await run(
                                        () => cart.moveToCart(item.productId));
                                    if (ok && context.mounted) {
                                      AppSnackbar.success(
                                          context, 'Producto movido al carrito');
                                    }
                                  },
                            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                            label: const Text('Mover al carrito'),
                          ),
                          IconButton(
                            tooltip: 'Quitar de guardados',
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
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final CartProvider cart;

  const _Summary({required this.cart});

  void _start(BuildContext context, bool loggedIn, CheckoutMode mode) {
    if (!loggedIn) {
      AppSnackbar.info(context, 'Inicia sesión para continuar con tu compra.');
      LoginPage.open(context);
      return;
    }
    CheckoutPage.open(context, mode);
  }

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
              // Los dos botones se ven también como invitado: al tocarlos se
              // pide iniciar sesión, así el flujo de compra se conoce antes de
              // tener cuenta (igual que la web).
              AppButton(
                label: 'Pagar',
                icon: Icons.credit_card,
                onPressed: () => _start(context, loggedIn, CheckoutMode.pay),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Cotizar',
                icon: Icons.description_outlined,
                variant: AppButtonVariant.outline,
                onPressed: () => _start(context, loggedIn, CheckoutMode.quote),
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
