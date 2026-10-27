import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/checkout_entity.dart';
import '../../components/components.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import 'checkout_form.dart';
import 'checkout_result_page.dart';

/// Paso 2 de "Cotizar": cómo se pagará cada moneda del carrito.
///
/// El servidor exige que lo pagado en cada moneda sea exactamente su total, así
/// que el botón solo se habilita cuando los montos cuadran.
class QuoteStep extends StatefulWidget {
  final CheckoutForm form;

  const QuoteStep({super.key, required this.form});

  @override
  State<QuoteStep> createState() => _QuoteStepState();
}

class _QuoteStepState extends State<QuoteStep> {
  bool _creating = false;

  Future<void> _create(Map<String, double> totals) async {
    final delivery = widget.form.toDelivery();
    if (delivery == null) return;

    final checkout = context.read<CheckoutProvider>();
    final cart = context.read<CartProvider>();

    setState(() => _creating = true);
    final result = await checkout.createQuotes(QuoteOrder(
      items: cart.items,
      delivery: delivery,
      payments: checkout.plan.effectiveLines,
    ));
    if (!mounted) return;
    setState(() => _creating = false);

    await result.fold(
      (failure) async => AppSnackbar.error(context, failure.message),
      (quotes) async {
        // La cotización no toca el carrito del servidor: lo vacía el cliente.
        await cart.clear();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => QuotesCreatedPage(quotes: quotes),
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartProvider>();
    final checkout = context.watch<CheckoutProvider>();
    final summaries = cart.summaries;

    if (summaries.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Tu carrito está vacío',
      );
    }

    final totals = {for (final s in summaries) s.currency: s.total};
    final plan = checkout.plan;
    final balanced = plan.isBalanced(totals);
    final hasUsd = totals.containsKey('d');

    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        Text('Forma de pago', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Elige cómo pagarás cada moneda. Los montos deben sumar el total.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        if (hasUsd)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tipo de cambio referencial: 1 USD = S/ '
              '${(checkout.exchangeRate ?? 3.70).toStringAsFixed(3)}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final s in summaries)
          _CurrencyBlock(summary: s, checkout: checkout),
        const SizedBox(height: 16),
        AppButton(
          label: 'Generar cotización',
          icon: Icons.description_outlined,
          isLoading: _creating || checkout.isBusy,
          onPressed: balanced ? () => _create(totals) : null,
        ),
        if (!balanced)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Completa los montos de pago para continuar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _CurrencyBlock extends StatelessWidget {
  final CartCurrencySummary summary;
  final CheckoutProvider checkout;

  const _CurrencyBlock({required this.summary, required this.checkout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = checkout.plan;
    final currency = summary.currency;
    final remaining = plan.remaining(currency, summary.total);
    String money(double v) => FormatUtils.money(v, currency: currency);

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(currency == 'd' ? 'Dólares' : 'Soles',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(money(summary.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in checkout.offeredPaymentTypes)
                  FilterChip(
                    label: Text(type.name),
                    selected: plan.has(type.code, currency),
                    onSelected: (_) =>
                        checkout.togglePayment(type, currency, summary.total),
                  ),
              ],
            ),
            for (final type in checkout.offeredPaymentTypes)
              if (plan.has(type.code, currency))
                _AmountRow(
                  key: ValueKey('${type.code}-$currency'),
                  type: type,
                  currency: currency,
                  total: summary.total,
                  checkout: checkout,
                ),
            const SizedBox(height: 8),
            _Balance(remaining: remaining, money: money),
          ],
        ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  final double remaining;
  final String Function(double) money;

  const _Balance({required this.remaining, required this.money});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balanced = remaining.abs() < 0.01;
    final label = balanced
        ? 'Monto completo'
        : (remaining > 0
            ? 'Falta ${money(remaining)}'
            : 'Sobra ${money(-remaining)}');

    return Row(
      children: [
        Icon(
          balanced ? Icons.check_circle : Icons.info_outline,
          size: 18,
          color: balanced ? Colors.green.shade700 : theme.colorScheme.error,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: balanced ? Colors.green.shade700 : theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Monto de una forma de pago. Se limita a lo que falta por cubrir (y, para el
/// crédito, a lo que le quede disponible).
class _AmountRow extends StatefulWidget {
  final PaymentTypeEntity type;
  final String currency;
  final double total;
  final CheckoutProvider checkout;

  const _AmountRow({
    super.key,
    required this.type,
    required this.currency,
    required this.total,
    required this.checkout,
  });

  @override
  State<_AmountRow> createState() => _AmountRowState();
}

class _AmountRowState extends State<_AmountRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.checkout.plan
        .amountOf(widget.type.code, widget.currency)
        .toStringAsFixed(2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.checkout.plan;
    final max = plan.maxFor(widget.type.code, widget.currency, widget.total);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Monto con ${widget.type.name}',
          helperText: widget.type.isCredit
              ? 'Crédito disponible: ${FormatUtils.money(widget.checkout.creditAvailable)}'
              : 'Máximo ${FormatUtils.money(max, currency: widget.currency)}',
          prefixText: widget.currency == 'd' ? 'US\$ ' : 'S/ ',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
        ),
        onChanged: (text) => widget.checkout.setPaymentAmount(
          widget.type.code,
          widget.currency,
          widget.total,
          double.tryParse(text.replaceAll(',', '.')) ?? 0,
        ),
      ),
    );
  }
}
