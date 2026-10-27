import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/checkout_entity.dart';
import '../../components/components.dart';
import '../account/purchases_page.dart';
import '../account/quotes_page.dart';

void _backToShop(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.isFirst);

/// Compra pagada. Muestra lo que el servidor registró.
class PaymentSuccessPage extends StatelessWidget {
  final PaymentResult result;

  /// Total que se le mostró al cliente antes de pagar, para avisarle si lo
  /// cobrado es distinto (el servidor recalcula con precios y stock vigentes).
  final double displayedTotal;

  const PaymentSuccessPage({
    super.key,
    required this.result,
    required this.displayedTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = result.purchase;
    String money(double v) => FormatUtils.money(v, currency: p?.currency);
    final changed = p != null && (p.total - displayedTotal).abs() >= 0.01;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToShop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compra realizada'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
            const SizedBox(height: 8),
            Text('¡Compra realizada!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(result.message,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if (result.simulated)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Compra de prueba: no se realizó ningún cobro real.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (changed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'El total de tu compra (${money(p.total)}) es distinto al '
                      'que viste (${money(displayedTotal)}) porque los precios '
                      'se actualizaron. Revisa el detalle.',
                    ),
                  ),
                ),
              ),
            if (p != null) ...[
              const Divider(height: 32),
              _Info('N° de compra', p.code),
              if (result.reference != null)
                _Info('N° de operación', result.reference!),
              if (result.cardLast4 != null)
                _Info('Tarjeta',
                    '${result.cardBrand ?? 'Tarjeta'} •••• ${result.cardLast4}'),
              if (p.deliveryAddress != null)
                _Info('Entrega', p.deliveryAddress!),
              const Divider(height: 32),
              for (final item in p.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text('${item.quantity} x ${item.name}',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    Text(money(item.subtotal)),
                  ]),
                ),
              const Divider(height: 24),
              if (p.discount > 0)
                _Info(
                  p.couponCode == null
                      ? 'Descuento'
                      : 'Descuento (${p.couponCode})',
                  '- ${money(p.discount)}',
                ),
              _Info('Total', money(p.total), bold: true),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Ver mis compras',
              icon: Icons.receipt_long_outlined,
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PurchasesPage()),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Seguir comprando',
              variant: AppButtonVariant.outline,
              onPressed: () => _backToShop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cotizaciones creadas (una por moneda).
class QuotesCreatedPage extends StatelessWidget {
  final List<CreatedQuote> quotes;

  const QuotesCreatedPage({super.key, required this.quotes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToShop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cotización generada'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            Icon(Icons.description, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              quotes.length > 1
                  ? 'Se generaron ${quotes.length} cotizaciones, una por moneda'
                  : 'Cotización generada',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Un asesor se comunicará contigo para coordinar el pago y la '
              'entrega.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            for (final q in quotes)
              Card(
                child: ListTile(
                  title: Text('Cotización ${q.code}'),
                  subtitle: q.orderCode == null ? null : Text('Pedido ${q.orderCode}'),
                  trailing: Text(
                    FormatUtils.money(q.total, currency: q.currency),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Ver mis cotizaciones',
              icon: Icons.description_outlined,
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const QuotesPage()),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Seguir comprando',
              variant: AppButtonVariant.outline,
              onPressed: () => _backToShop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Info(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: style),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}
