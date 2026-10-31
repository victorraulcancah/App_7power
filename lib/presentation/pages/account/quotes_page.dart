import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/product_entity.dart';
import '../../../domain/entities/quote_entity.dart';
import '../../components/components.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../providers/load_status.dart';
import '../../providers/quotes_provider.dart';
import '../cart_page.dart';

StatusTagType _tagType(QuoteEntity q) {
  if (q.isCancelled) return StatusTagType.error;
  if (q.inAttention) return StatusTagType.info;
  return StatusTagType.warning;
}

/// "Mis cotizaciones": las que el cliente pidió desde la tienda.
class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuotesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final quotes = context.watch<QuotesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis cotizaciones')),
      body: switch (quotes.status) {
        LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
        LoadStatus.error => ErrorState(
            message: quotes.errorMessage,
            onRetry: quotes.load,
          ),
        LoadStatus.loaded => quotes.items.isEmpty
            ? const EmptyState(
                icon: Icons.description_outlined,
                title: 'Aún no tienes cotizaciones',
                message: 'Las que pidas desde el carrito aparecerán aquí.',
              )
            : RefreshIndicator(
                onRefresh: quotes.load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: quotes.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final q = quotes.items[i];
                    return Card(
                      child: ListTile(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuoteDetailPage(quote: q),
                          ),
                        ),
                        title: Text('Cotización ${q.code}'),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (q.date != null)
                                Text(FormatUtils.date(q.date!)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: [
                                  StatusTag(label: q.status, type: _tagType(q)),
                                  if (q.inAttention)
                                    const StatusTag(label: 'En atención'),
                                  if (q.expired && !q.isCancelled)
                                    const StatusTag(
                                      label: 'Vencida',
                                      type: StatusTagType.error,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: Text(
                          FormatUtils.money(q.total, currency: q.currency),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    );
                  },
                ),
              ),
      },
    );
  }
}

/// Detalle de una cotización, con la opción de cancelarla mientras esté "En
/// espera".
class QuoteDetailPage extends StatelessWidget {
  final QuoteEntity quote;

  const QuoteDetailPage({super.key, required this.quote});

  Future<void> _cancel(BuildContext context) async {
    final quotes = context.read<QuotesProvider>();
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cotización'),
        content: Text('¿Cancelar la cotización ${quote.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await quotes.cancel(quote);
    if (!context.mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      AppSnackbar.success(context, 'La cotización quedó cancelada.');
      navigator.pop();
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// "Comprar": pide convertir la cotización en compra.
  Future<void> _buy(BuildContext context) async {
    final quotes = context.read<QuotesProvider>();
    final navigator = Navigator.of(context);

    final ok = await _confirm(
      context,
      title: '¿Convertir a compra?',
      message: '¿Deseas convertir la cotización ${quote.code} en una compra?',
      confirm: 'Sí, convertir',
    );
    if (!ok || !context.mounted) return;

    final result = await quotes.convertToPurchase(quote);
    if (!context.mounted) return;
    if (result.error != null) {
      AppSnackbar.error(context, result.error!);
    } else {
      AppSnackbar.success(context, result.message!);
      navigator.pop();
    }
  }

  /// "Editar": los productos vuelven al carrito y se rehace el pedido por el
  /// checkout; al confirmarlo, la nueva cotización reemplaza a esta.
  Future<void> _edit(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final checkout = context.read<CheckoutProvider>();
    final navigator = Navigator.of(context);

    final ok = await _confirm(
      context,
      title: '¿Editar esta cotización?',
      message: 'Los productos de ${quote.code} vuelven a tu carrito para que '
          'rehagas el pedido. Se reemplaza lo que tengas ahora en el carrito y, '
          'al confirmar, esta cotización queda reemplazada por la nueva.',
      confirm: 'Sí, editar',
    );
    if (!ok || !context.mounted) return;

    String? error = await cart.clear();
    for (final item in quote.items) {
      final failure = await cart.add(
        ProductEntity(
          id: item.productId,
          name: item.name,
          price: item.unitPrice,
          // El stock real lo valida el servidor al agregar.
          stock: item.quantity,
          imageUrl: item.imageUrl,
        ),
        quantity: item.quantity,
      );
      error ??= failure;
    }
    if (!context.mounted) return;

    checkout.startEditingQuote(id: quote.id, code: quote.code);
    if (error != null) {
      AppSnackbar.error(
        context,
        'Algunos productos no se pudieron agregar. Revisa tu carrito antes '
        'de continuar.',
      );
    }
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => const CartPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = quote;
    String money(double v) => FormatUtils.money(v, currency: q.currency);

    return Scaffold(
      appBar: AppBar(title: Text('Cotización ${q.code}')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusTag(label: q.status, type: _tagType(q)),
              if (q.inAttention) const StatusTag(label: 'En atención'),
              if (q.date != null) Text(FormatUtils.date(q.date!)),
            ],
          ),
          if (q.expiresAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Válida hasta ${FormatUtils.date(q.expiresAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (q.inAttention)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Un vendedor ya está atendiendo tu pedido, por eso no se puede '
                'cancelar desde aquí.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const Divider(height: 32),
          Text('Productos', style: theme.textTheme.titleSmall),
          for (final item in q.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProductImage(
                url: item.imageUrl,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(6),
              ),
              title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${item.quantity} x ${money(item.unitPrice)}'),
              trailing: Text(money(item.subtotal)),
            ),
          const Divider(height: 32),
          if (q.shippingLabel != null || q.deliveryAddress != null) ...[
            Text('Envío', style: theme.textTheme.titleSmall),
            if (q.shippingLabel != null) Text(q.shippingLabel!),
            if (q.deliveryAddress != null) Text(q.deliveryAddress!),
            if (q.phone != null) Text('Teléfono: ${q.phone}'),
            const Divider(height: 32),
          ],
          if (q.payments.isNotEmpty) ...[
            Text('Pago', style: theme.textTheme.titleSmall),
            for (final p in q.payments)
              Text('${p.type} - ${FormatUtils.money(p.amount, currency: p.currency)}'),
            const Divider(height: 32),
          ],
          if (q.notes != null) ...[
            Text('Observaciones', style: theme.textTheme.titleSmall),
            Text(q.notes!),
            const Divider(height: 32),
          ],
          _Line('Subtotal', money(q.subtotal)),
          if (q.igv > 0) _Line('IGV', money(q.igv)),
          if (q.shipping > 0) _Line('Envío', money(q.shipping)),
          _Line('Total', money(q.total), bold: true),
          if (q.canConvert && !q.isCancelled) ...[
            const SizedBox(height: 24),
            AppButton(
              label: 'Comprar',
              icon: Icons.shopping_bag_outlined,
              onPressed: () => _buy(context),
            ),
          ],
          if (q.canCancel && q.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Editar cotización',
              icon: Icons.edit_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => _edit(context),
            ),
          ],
          if (q.canCancel) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Cancelar cotización',
              icon: Icons.cancel_outlined,
              variant: AppButtonVariant.outline,
              onPressed: () => _cancel(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Line(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}
