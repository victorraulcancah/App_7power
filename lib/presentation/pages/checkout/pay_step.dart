import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/checkout_entity.dart';
import '../../components/components.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import 'checkout_form.dart';
import 'checkout_result_page.dart';

/// Tarjeta que acepta la pasarela de prueba.
const approvedTestCard = '4111111111111111';

/// Token que espera el backend para la pasarela simulada.
String tokenForCard(String digits) =>
    digits == approvedTestCard ? 'tok_test_aprobado' : 'tok_test_rechazado';

String brandForCard(String digits) => switch (digits.isEmpty ? '' : digits[0]) {
      '4' => 'Visa',
      '5' => 'Mastercard',
      _ => 'Tarjeta',
    };

/// Paso 2 de "Pagar": resumen, cupón y datos de la tarjeta.
///
/// La pasarela del backend es SIMULADA: no cobra. Del formulario de tarjeta
/// solo salen el token, la marca y los 4 últimos dígitos; el número completo,
/// el vencimiento y el CVV nunca se envían ni se guardan.
class PayStep extends StatefulWidget {
  final CheckoutForm form;

  const PayStep({super.key, required this.form});

  @override
  State<PayStep> createState() => _PayStepState();
}

class _PayStepState extends State<PayStep> {
  final _formKey = GlobalKey<FormState>();
  final _holder = TextEditingController();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _coupon = TextEditingController();

  String? _currency;
  bool _applyingCoupon = false;
  bool _paying = false;

  @override
  void dispose() {
    _holder.dispose();
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon(double solesTotal) async {
    final checkout = context.read<CheckoutProvider>();
    setState(() => _applyingCoupon = true);
    final error = await checkout.applyCoupon(_coupon.text, solesTotal);
    if (!mounted) return;
    setState(() => _applyingCoupon = false);
    if (error != null) AppSnackbar.error(context, error);
  }

  Future<void> _pay(CartCurrencySummary summary, bool mixed) async {
    if (!_formKey.currentState!.validate()) return;
    final delivery = widget.form.toDelivery();
    if (delivery == null) return;

    final checkout = context.read<CheckoutProvider>();
    final cart = context.read<CartProvider>();
    final digits = _number.text.replaceAll(' ', '');
    final coupon = summary.currency == 's' ? checkout.coupon : null;
    final displayed = coupon?.totalWithDiscount ?? summary.total;

    setState(() => _paying = true);
    final result = await checkout.pay(PaymentOrder(
      delivery: delivery,
      currency: mixed ? summary.currency : null,
      couponCode: coupon?.code,
      card: CardPayment(
        token: tokenForCard(digits),
        brand: brandForCard(digits),
        last4: digits.substring(digits.length - 4),
      ),
    ));
    if (!mounted) return;
    setState(() => _paying = false);

    await result.fold(
      (failure) async => AppSnackbar.error(context, failure.message),
      (payment) async {
        if (payment.approved) {
          // El servidor ya quitó del carrito lo que cobró.
          await cart.load();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => PaymentSuccessPage(
              result: payment,
              displayedTotal: displayed,
            ),
          ));
        } else {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.error_outline, size: 40),
              title: const Text('Pago rechazado'),
              content: Text(payment.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Intentar con otra tarjeta'),
                ),
              ],
            ),
          );
          _number.clear();
          _expiry.clear();
          _cvv.clear();
        }
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

    final mixed = summaries.length > 1;
    final selected = summaries.firstWhere(
      (s) => s.currency == (_currency ?? summaries.first.currency),
      orElse: () => summaries.first,
    );
    // El cupón solo vale en soles.
    final coupon = selected.currency == 's' ? checkout.coupon : null;
    final total = coupon?.totalWithDiscount ?? selected.total;
    String money(double v) =>
        FormatUtils.money(v, currency: selected.currency);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          if (checkout.testMode)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Modo de prueba: no se realiza ningún cobro. Usa la '
                        'tarjeta 4111 1111 1111 1111 para una compra '
                        'aprobada o 4000 0000 0000 0002 para una rechazada.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (mixed) ...[
            const SizedBox(height: 16),
            Text('Pagar ahora en', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final s in summaries)
                  ButtonSegment(
                    value: s.currency,
                    label: Text(s.currency == 'd' ? 'Dólares' : 'Soles'),
                  ),
              ],
              selected: {selected.currency},
              onSelectionChanged: (s) => setState(() => _currency = s.first),
            ),
            const SizedBox(height: 4),
            Text(
              'Los productos en la otra moneda se quedan en tu carrito para '
              'pagarlos después.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 16),
          Text('Resumen', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in cart.items.where((i) =>
              FormatUtils.normalizeCurrency(i.currency) == selected.currency))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${item.quantity} x ${item.name}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(money(item.subtotal)),
                ],
              ),
            ),
          const Divider(height: 24),
          _Row('Subtotal', money(selected.total)),
          if (coupon != null)
            _Row('Descuento (${coupon.code})', '- ${money(coupon.discount)}'),
          const _Row('Envío', 'Por coordinar'),
          const SizedBox(height: 4),
          _Row('Total', money(total), bold: true),
          if (selected.currency == 's') ...[
            const SizedBox(height: 16),
            if (coupon == null)
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Cupón de descuento',
                      controller: _coupon,
                      prefixIcon: Icons.local_offer_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'Aplicar',
                    expanded: false,
                    isLoading: _applyingCoupon,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _applyCoupon(selected.total),
                  ),
                ],
              )
            else
              InputChip(
                avatar: const Icon(Icons.local_offer, size: 18),
                label: Text('Cupón ${coupon.code} aplicado'),
                onDeleted: checkout.removeCoupon,
              ),
          ],
          const SizedBox(height: 24),
          Text('Tarjeta', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Titular de la tarjeta',
            controller: _holder,
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v ?? '').trim().length < 3 ? 'Ingresa el nombre del titular' : null,
          ),
          const SizedBox(height: 12),
          _CardField(
            label: 'Número de tarjeta',
            controller: _number,
            icon: Icons.credit_card,
            formatter: _GroupFormatter(groupSize: 4, separator: ' ', maxDigits: 19),
            validator: (v) {
              final digits = (v ?? '').replaceAll(' ', '');
              return digits.length < 12 ? 'Ingresa el número de la tarjeta' : null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardField(
                  label: 'Vencimiento (MM/AA)',
                  controller: _expiry,
                  icon: Icons.event_outlined,
                  formatter: _GroupFormatter(groupSize: 2, separator: '/', maxDigits: 4),
                  validator: _validateExpiry,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CardField(
                  label: 'CVV',
                  controller: _cvv,
                  icon: Icons.lock_outline,
                  obscure: true,
                  formatter: LengthLimitingTextInputFormatter(4),
                  validator: (v) => RegExp(r'^[0-9]{3,4}$').hasMatch(v ?? '')
                      ? null
                      : 'CVV no válido',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Solo se envían la marca y los últimos 4 dígitos. El número '
            'completo y el CVV nunca salen de tu teléfono.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Pagar ${money(total)}',
            icon: Icons.lock_outline,
            isLoading: _paying || checkout.isBusy,
            onPressed: () => _pay(selected, mixed),
          ),
        ],
      ),
    );
  }

  /// MM/AA válido y no vencido (el mes en curso todavía sirve).
  static String? _validateExpiry(String? v) {
    final value = v ?? '';
    if (!RegExp(r'^(0[1-9]|1[0-2])/[0-9]{2}$').hasMatch(value)) {
      return 'Usa el formato MM/AA';
    }
    final month = int.parse(value.substring(0, 2));
    final year = 2000 + int.parse(value.substring(3));
    final now = DateTime.now();
    final expired = year < now.year || (year == now.year && month < now.month);
    return expired ? 'La tarjeta está vencida' : null;
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ]),
    );
  }
}

class _CardField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputFormatter formatter;
  final String? Function(String?) validator;
  final bool obscure;

  const _CardField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.formatter,
    required this.validator,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: obscure,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/ ]')), formatter],
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
      ),
    );
  }
}

/// Agrupa los dígitos ("4111 1111 ..." o "12/28") y limita su cantidad.
class _GroupFormatter extends TextInputFormatter {
  final int groupSize;
  final String separator;
  final int maxDigits;

  _GroupFormatter({
    required this.groupSize,
    required this.separator,
    required this.maxDigits,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % groupSize == 0) buffer.write(separator);
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
