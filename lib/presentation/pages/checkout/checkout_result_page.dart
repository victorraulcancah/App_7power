import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/checkout_entity.dart';
import '../../components/components.dart';
import '../account/purchases_page.dart';
import '../account/quotes_page.dart';
import '../main_shell.dart';

const int _homeTab = 0;
const int _shopTab = 1;

void _backToShop(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.isFirst);

/// Vuelve a la pantalla principal y deja en la pestaña pedida.
void _goToTab(BuildContext context, int tab) {
  MainShell.requestTab(tab);
  _backToShop(context);
}

/// Compra pagada, con la misma pantalla de la web: ¡Compra realizada!, el
/// recibo (compra, operación, método de pago y total), los productos, la
/// entrega y, si la pasarela es de prueba, el aviso.
class PaymentSuccessPage extends StatelessWidget {
  final PaymentResult result;

  /// Total que se le mostró al cliente antes de pagar, para avisarle si lo
  /// cobrado es distinto (el servidor recalcula con precios y stock vigentes).
  final double displayedTotal;

  /// A quién se agradece y a dónde llega la confirmación (los de la entrega).
  final String? customerName;
  final String? customerEmail;

  const PaymentSuccessPage({
    super.key,
    required this.result,
    required this.displayedTotal,
    this.customerName,
    this.customerEmail,
  });

  /// "Entrega a domicilio", como lo dice la web, según la forma de envío.
  static String deliveryTitle(String? method) => switch (method) {
        'envio_provincia' => 'Envío a provincia',
        'recojo_tienda' => 'Recojo en tienda',
        _ => 'Entrega a domicilio',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = result.purchase;
    String money(double v) => FormatUtils.money(v, currency: p?.currency);
    final changed = p != null && (p.total - displayedTotal).abs() >= 0.01;
    final email = p?.customerEmail ?? customerEmail;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final name = customerName?.trim() ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToTab(context, _homeTab);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Compra realizada'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            const SizedBox(height: 8),
            Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFF22B573),
                child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Compra realizada!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              name.isEmpty
                  ? 'Gracias. Recibimos tu pago.'
                  : 'Gracias, $name. Recibimos tu pago.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: muted),
            ),
            if (email != null && email.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Te enviamos la confirmación a '),
                    TextSpan(
                      text: email,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: '.'),
                  ]),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                ),
              ),
            if (changed)
              Padding(
                padding: const EdgeInsets.only(top: 16),
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
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6E8EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Field('N° de compra', p.code)),
                        Expanded(
                          child: _Field(
                            'N° de operación',
                            result.reference ?? '-',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Field(
                            'Método de pago',
                            result.cardLast4 == null
                                ? '-'
                                : '${result.cardBrand ?? 'Tarjeta'} terminada '
                                    'en ${result.cardLast4}',
                          ),
                        ),
                        Expanded(child: _Field('Total pagado', money(p.total))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final item in p.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProductImage(
                              url: item.imageUrl,
                              width: 48,
                              height: 48,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.quantity} × ${money(item.unitPrice)}',
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: muted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              money(item.subtotal),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (p.discount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              p.couponCode == null
                                  ? 'Descuento'
                                  : 'Descuento (${p.couponCode})',
                              style: theme.textTheme.bodySmall,
                            ),
                            const Spacer(),
                            Text(
                              '- ${money(p.discount)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                    Text(
                      deliveryTitle(p.shippingMethod),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (p.deliveryAddress != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.deliveryAddress!,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'El costo y la fecha del envío te los confirmaremos por '
                      'teléfono o WhatsApp.',
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
            if (result.simulated)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7DC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF3DE96)),
                ),
                child: const Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'Compra de prueba: ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: 'se hizo con la pasarela en modo de prueba, sin '
                          'cobro real.',
                    ),
                  ]),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5C4A00)),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _goToTab(context, _shopTab),
                    child: const Text('Seguir comprando'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _goToTab(context, _homeTab),
                    child: const Text('Ir al inicio'),
                  ),
                ),
              ],
            ),
            if (p != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PurchasesPage()),
                  ),
                  child: const Text('Ver mis compras'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un dato del recibo: etiqueta chica y valor en negrita.
class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
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
