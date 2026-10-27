import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/address_entity.dart';
import '../../../domain/entities/checkout_entity.dart';
import '../../components/components.dart';
import '../../providers/addresses_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../providers/load_status.dart';
import '../account/address_form_page.dart';
import 'checkout_form.dart';
import 'pay_step.dart';
import 'quote_step.dart';

export 'checkout_form.dart' show CheckoutMode;

/// Checkout en dos pasos: Entrega y Pago. "Pagar" cobra con la pasarela (hoy
/// de prueba) y "Cotizar" genera una cotización que se coordina con la tienda.
class CheckoutPage extends StatefulWidget {
  final CheckoutMode mode;

  const CheckoutPage({super.key, required this.mode});

  static Future<void> open(BuildContext context, CheckoutMode mode) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CheckoutPage(mode: mode)),
      );

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final CheckoutForm _form = CheckoutForm();
  final _contactKey = GlobalKey<FormState>();
  int _step = 0;
  bool _checkingStock = false;

  bool get _isPay => widget.mode == CheckoutMode.pay;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _form.name.text = user?.fullName ?? '';
    _form.email.text = user?.email ?? '';
    _form.document.text = user?.documentNumber ?? '';
    _form.phone.text = user?.phone ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final checkout = context.read<CheckoutProvider>();
      final addresses = context.read<AddressesProvider>();
      // Precios y stock al día antes de cobrar o cotizar.
      context.read<CartProvider>().load();
      await Future.wait([
        checkout.open(forQuote: !_isPay),
        addresses.load(),
      ]);
      if (!mounted) return;
      // El celular del titular (cuenta vinculada) manda sobre el del perfil.
      final holderPhone = checkout.holderPhone;
      if (holderPhone != null) _form.phone.text = holderPhone;
      _pickDefaultAddress(addresses.items);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _pickDefaultAddress(List<AddressEntity> items) {
    if (items.isEmpty) {
      _form.address = null;
      return;
    }
    // Si la elegida ya no existe (se editó o eliminó) se vuelve a la
    // predeterminada.
    final stillThere = items.where((a) => a.id == _form.address?.id).firstOrNull;
    _form.address = stillThere ??
        items.where((a) => a.isDefault).firstOrNull ??
        items.first;
  }

  Future<void> _addAddress() async {
    final addresses = context.read<AddressesProvider>();
    await AddressFormPage.open(context);
    if (!mounted) return;
    await addresses.load();
    if (!mounted) return;
    setState(() => _pickDefaultAddress(addresses.items));
  }

  Future<void> _continue() async {
    if (_form.address == null) {
      AppSnackbar.error(context, 'Elige una dirección de entrega');
      return;
    }
    if (_isPay && !_contactKey.currentState!.validate()) return;
    if (!_form.acceptedTerms) {
      AppSnackbar.error(context, 'Debes aceptar los términos y condiciones');
      return;
    }

    if (!_isPay) {
      // Se comprueba el stock antes de pedir los pagos, como la web.
      final cart = context.read<CartProvider>();
      final checkout = context.read<CheckoutProvider>();
      setState(() => _checkingStock = true);
      final result = await checkout.verifyStock(cart.items);
      if (!mounted) return;
      setState(() => _checkingStock = false);

      // Si la verificación falla no se bloquea: el servidor vuelve a
      // comprobar al crear la cotización.
      final check = result.fold((_) => null, (c) => c);
      if (check != null && !check.hasStock) {
        await _showShortages(check);
        return;
      }
    }

    setState(() => _step = 1);
  }

  Future<void> _showShortages(StockCheck check) async {
    final cart = context.read<CartProvider>();
    final shortages = check.shortages;

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Productos sin stock suficiente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in shortages)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${s.name}: pediste ${s.requested}, quedan ${s.available}',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'review'),
            child: const Text('Revisar carrito'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'adjust'),
            child: const Text('Ajustar'),
          ),
        ],
      ),
    );

    if (action == 'adjust') {
      // Se baja la cantidad al stock disponible, o se quita si no queda nada.
      for (final s in shortages) {
        if (s.available > 0) {
          await cart.setQuantity(s.productId, s.available);
        } else {
          await cart.remove(s.productId);
        }
      }
      if (mounted && cart.isEmpty) Navigator.of(context).pop();
    } else if (action == 'review' && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final addresses = context.watch<AddressesProvider>();

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        // Desde el pago, "atrás" vuelve a la entrega en vez de salir.
        if (!didPop) setState(() => _step = 0);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_isPay ? 'Pagar' : 'Cotizar')),
        body: switch (checkout.status) {
          LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
          LoadStatus.error => ErrorState(
              message: checkout.errorMessage,
              onRetry: () => checkout.open(forQuote: !_isPay),
            ),
          LoadStatus.loaded => Column(
              children: [
                _Steps(step: _step),
                Expanded(
                  child: _step == 0
                      ? _DeliveryStep(
                          form: _form,
                          formKey: _contactKey,
                          isPay: _isPay,
                          addresses: addresses,
                          busy: _checkingStock,
                          onSelect: (a) => setState(() => _form.address = a),
                          onAddAddress: _addAddress,
                          onTermsChanged: (v) =>
                              setState(() => _form.acceptedTerms = v),
                          onContinue: _continue,
                        )
                      : (_isPay
                          ? PayStep(form: _form)
                          : QuoteStep(form: _form)),
                ),
              ],
            ),
        },
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  final int step;

  const _Steps({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget item(int index, String label) {
      final active = step >= index;
      return Expanded(
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              foregroundColor: active
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              child: Text('${index + 1}'),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: step == index ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [item(0, 'Entrega'), item(1, 'Pago')]),
    );
  }
}

class _DeliveryStep extends StatelessWidget {
  final CheckoutForm form;
  final GlobalKey<FormState> formKey;
  final bool isPay;
  final AddressesProvider addresses;
  final bool busy;
  final ValueChanged<AddressEntity> onSelect;
  final VoidCallback onAddAddress;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onContinue;

  const _DeliveryStep({
    required this.form,
    required this.formKey,
    required this.isPay,
    required this.addresses,
    required this.busy,
    required this.onSelect,
    required this.onAddAddress,
    required this.onTermsChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delivery = form.toDelivery();

    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        Text('Dirección de entrega', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (addresses.status == LoadStatus.loading ||
            addresses.status == LoadStatus.initial)
          const Padding(
            padding: EdgeInsets.all(24),
            child: LoadingIndicator(),
          )
        else if (addresses.status == LoadStatus.error)
          ErrorState(message: addresses.errorMessage, onRetry: addresses.load)
        else ...[
          if (addresses.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aún no tienes direcciones. Agrega una para continuar.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          for (final a in addresses.items)
            _AddressChoice(
              address: a,
              selected: form.address?.id == a.id,
              onTap: () => onSelect(a),
            ),
          AppButton(
            label: 'Agregar dirección',
            icon: Icons.add_location_alt_outlined,
            variant: AppButtonVariant.outline,
            onPressed: onAddAddress,
          ),
        ],
        if (delivery != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(delivery.shippingLabel),
              subtitle: const Text(
                'El costo y la fecha del envío te los confirmamos por '
                'teléfono o WhatsApp.',
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(isPay ? 'Datos de contacto' : 'Contacto',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Form(
          key: formKey,
          child: Column(
            children: [
              if (isPay) ...[
                AppTextField(
                  label: 'Nombre completo',
                  controller: form.name,
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'Ingresa tu nombre completo'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Correo electrónico',
                  controller: form.email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch((v ?? '').trim())
                      ? null
                      : 'Ingresa un correo válido',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'DNI o RUC (opcional)',
                  controller: form.document,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.badge_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
              ],
              AppTextField(
                label: isPay ? 'Teléfono de contacto' : 'Teléfono (opcional)',
                controller: form.phone,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (!isPay && value.isEmpty) return null;
                  return RegExp(r'^[0-9+ ]{7,15}$').hasMatch(value)
                      ? null
                      : 'Ingresa un teléfono válido';
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Observaciones (opcional)',
                controller: form.notes,
                maxLines: 2,
                validator: (v) => (v ?? '').length > 500
                    ? 'Máximo 500 caracteres'
                    : null,
              ),
            ],
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: form.acceptedTerms,
          onChanged: (v) => onTermsChanged(v ?? false),
          title: const Text('Acepto los términos y condiciones de compra'),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Continuar al pago',
          icon: Icons.arrow_forward,
          isLoading: busy,
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _AddressChoice extends StatelessWidget {
  final AddressEntity address;
  final bool selected;
  final VoidCallback onTap;

  const _AddressChoice({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? theme.colorScheme.primary : null,
        ),
        title: Text(address.fullAddress),
        subtitle: Text(address.location.isEmpty ? address.recipient : address.location),
        trailing: address.isDefault
            ? const StatusTag(label: 'Predeterminada', type: StatusTagType.success)
            : null,
      ),
    );
  }
}
