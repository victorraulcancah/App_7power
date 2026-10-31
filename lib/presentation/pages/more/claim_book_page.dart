import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/info_entity.dart';
import '../../../domain/usecases/info_usecases.dart';
import '../../components/components.dart';
import '../../providers/auth_provider.dart';
import '../../providers/info_provider.dart';

const claimDocumentTypes = ['DNI', 'RUC', 'Carné de extranjería', 'Pasaporte'];
const claimVoucherTypes = ['Boleta', 'Factura', 'Nota de venta', 'Otro'];
const claimSolutions = [
  'Cambio de producto',
  'Devolución del dinero',
  'Reparación',
  'Cumplimiento del servicio',
  'Otro',
];

/// Libro de Reclamaciones virtual (obligatorio por el Código de Protección y
/// Defensa del Consumidor).
class ClaimBookPage extends StatefulWidget {
  const ClaimBookPage({super.key});

  @override
  State<ClaimBookPage> createState() => _ClaimBookPageState();
}

class _ClaimBookPageState extends State<ClaimBookPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _document = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  final _guardianName = TextEditingController();
  final _guardianDocument = TextEditingController();
  final _guardianAddress = TextEditingController();
  final _guardianPhone = TextEditingController();
  final _guardianEmail = TextEditingController();

  final _amount = TextEditingController();
  final _goodDescription = TextEditingController();

  final _voucherNumber = TextEditingController();
  final _orderCode = TextEditingController();
  final _productName = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();

  final _detail = TextEditingController();
  final _request = TextEditingController();
  final _otherSolution = TextEditingController();

  String _documentType = claimDocumentTypes.first;
  bool _isMinor = false;
  String _goodType = 'producto';
  String _requestType = 'reclamo';
  String? _voucherType;
  DateTime? _purchaseDate;
  String? _solution;
  bool _sending = false;

  List<TextEditingController> get _all => [
        _name, _document, _address, _phone, _email, _guardianName,
        _guardianDocument, _guardianAddress, _guardianPhone, _guardianEmail,
        _amount, _goodDescription, _voucherNumber, _orderCode, _productName,
        _brand, _model, _detail, _request, _otherSolution,
      ];

  @override
  void initState() {
    super.initState();
    // Con sesión, los datos del cliente ya vienen llenos.
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _name.text = user.fullName;
      _email.text = user.email;
      _phone.text = user.phone ?? '';
      _document.text = user.documentNumber ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  ClaimDraft _draft() => ClaimDraft(
        consumerName: _name.text,
        documentType: _documentType,
        documentNumber: _document.text,
        address: _address.text,
        phone: _phone.text,
        email: _email.text,
        isMinor: _isMinor,
        guardianName: _optional(_guardianName),
        guardianDocument: _optional(_guardianDocument),
        guardianAddress: _optional(_guardianAddress),
        guardianPhone: _optional(_guardianPhone),
        guardianEmail: _optional(_guardianEmail),
        goodType: _goodType,
        amount: double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0,
        goodDescription: _goodDescription.text,
        voucherType: _voucherType,
        voucherNumber: _optional(_voucherNumber),
        purchaseDate: _purchaseDate,
        orderCode: _optional(_orderCode),
        productName: _optional(_productName),
        brand: _optional(_brand),
        model: _optional(_model),
        requestType: _requestType,
        detail: _detail.text,
        consumerRequest: _request.text,
        expectedSolution: _solution,
        otherSolution: _optional(_otherSolution),
      );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(now.year - 5),
      // No se reclama por una compra que todavía no ocurrió.
      lastDate: now,
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final info = context.read<InfoProvider>();
    final navigator = Navigator.of(context);

    setState(() => _sending = true);
    final result = await info.submitClaim(_draft());
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.error != null) {
      AppSnackbar.error(context, result.error!);
      return;
    }
    navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => ClaimReceiptPage(receipt: result.receipt!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget gap([double h = 12]) => SizedBox(height: h);
    Widget title(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Text(text,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Libro de reclamaciones'),
        actions: [
          IconButton(
            tooltip: 'Consultar un reclamo',
            icon: const Icon(Icons.search),
            onPressed: () => showClaimLookup(context),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Tu reclamo o queja se registra en nuestro libro y te '
                  'respondemos en un máximo de 15 días hábiles. Los datos con '
                  'asterisco son obligatorios.',
                ),
              ),
            ),
            title('1. Tus datos'),
            AppTextField(
              label: 'Nombre completo *',
              controller: _name,
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (v) => (v ?? '').trim().length < 2
                  ? 'Ingresa tu nombre completo'
                  : null,
            ),
            gap(),
            _Select<String>(
              label: 'Tipo de documento *',
              value: _documentType,
              options: claimDocumentTypes,
              onChanged: (v) => setState(() => _documentType = v!),
            ),
            gap(),
            AppTextField(
              label: 'Número de documento *',
              controller: _document,
              prefixIcon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) => validateDocument(_documentType, v ?? ''),
            ),
            gap(),
            AppTextField(
              label: 'Dirección *',
              controller: _address,
              prefixIcon: Icons.home_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) => (v ?? '').trim().length < 10
                  ? 'Mínimo 10 caracteres'
                  : null,
            ),
            gap(),
            AppTextField(
              label: 'Teléfono (9 dígitos) *',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) => RegExp(r'^\d{9}$').hasMatch((v ?? '').trim())
                  ? null
                  : 'Debe tener exactamente 9 dígitos',
            ),
            gap(),
            AppTextField(
              label: 'Correo electrónico *',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline,
              validator: Validators.email,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Soy menor de edad'),
              subtitle: const Text('Lo presenta un padre, madre o apoderado.'),
              value: _isMinor,
              onChanged: (v) => setState(() => _isMinor = v),
            ),
            if (_isMinor) ...[
              AppTextField(
                label: 'Nombre del apoderado *',
                controller: _guardianName,
                prefixIcon: Icons.supervisor_account_outlined,
                validator: (v) => (v ?? '').trim().length < 2
                    ? 'Ingresa el nombre del apoderado'
                    : null,
              ),
              gap(),
              AppTextField(
                label: 'DNI del apoderado *',
                controller: _guardianDocument,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.badge_outlined,
                validator: (v) => RegExp(r'^\d{8}$').hasMatch((v ?? '').trim())
                    ? null
                    : 'El DNI debe tener 8 dígitos',
              ),
              gap(),
              AppTextField(
                label: 'Dirección del apoderado *',
                controller: _guardianAddress,
                prefixIcon: Icons.home_outlined,
                validator: (v) => (v ?? '').trim().length < 10
                    ? 'Mínimo 10 caracteres'
                    : null,
              ),
              gap(),
              AppTextField(
                label: 'Teléfono del apoderado *',
                controller: _guardianPhone,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: (v) => RegExp(r'^\d{9}$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Debe tener exactamente 9 dígitos',
              ),
              gap(),
              AppTextField(
                label: 'Correo del apoderado *',
                controller: _guardianEmail,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline,
                validator: Validators.email,
              ),
            ],
            title('2. Bien contratado'),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'producto', label: Text('Producto')),
                ButtonSegment(value: 'servicio', label: Text('Servicio')),
              ],
              selected: {_goodType},
              onSelectionChanged: (s) => setState(() => _goodType = s.first),
            ),
            gap(),
            AppTextField(
              label: 'Monto reclamado (S/) *',
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icons.payments_outlined,
              validator: (v) =>
                  (double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0) > 0
                      ? null
                      : 'Debe ser mayor a 0',
            ),
            gap(),
            AppTextField(
              label: 'Descripción del producto o servicio *',
              controller: _goodDescription,
              maxLines: 3,
              validator: (v) => (v ?? '').trim().length < 10
                  ? 'Mínimo 10 caracteres'
                  : null,
            ),
            title('3. Datos de la compra (opcional)'),
            _Select<String?>(
              label: 'Tipo de comprobante',
              value: _voucherType,
              options: claimVoucherTypes,
              onChanged: (v) => setState(() => _voucherType = v),
              allowEmpty: true,
            ),
            gap(),
            AppTextField(
              label: 'Número de comprobante',
              controller: _voucherNumber,
              prefixIcon: Icons.receipt_long_outlined,
            ),
            gap(),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha de compra',
                  prefixIcon: const Icon(Icons.event_outlined),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.defaultBorderRadius),
                  ),
                ),
                child: Text(_purchaseDate == null
                    ? 'Seleccionar'
                    : FormatUtils.date(_purchaseDate!)),
              ),
            ),
            gap(),
            AppTextField(
              label: 'Código de pedido',
              controller: _orderCode,
              prefixIcon: Icons.confirmation_number_outlined,
            ),
            gap(),
            AppTextField(
              label: 'Nombre del producto',
              controller: _productName,
              prefixIcon: Icons.inventory_2_outlined,
            ),
            gap(),
            Row(
              children: [
                Expanded(
                  child: AppTextField(label: 'Marca', controller: _brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(label: 'Modelo', controller: _model),
                ),
              ],
            ),
            title('4. Detalle'),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'reclamo', label: Text('Reclamo')),
                ButtonSegment(value: 'queja', label: Text('Queja')),
              ],
              selected: {_requestType},
              onSelectionChanged: (s) => setState(() => _requestType = s.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _requestType == 'reclamo'
                    ? 'Reclamo: disconformidad con el producto o el servicio.'
                    : 'Queja: malestar por la atención, sin relación con el producto.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
            gap(),
            AppTextField(
              label: 'Detalle del reclamo *',
              controller: _detail,
              maxLines: 4,
              validator: (v) => (v ?? '').trim().length < 20
                  ? 'Cuéntanos con más detalle (mínimo 20 caracteres)'
                  : null,
            ),
            gap(),
            AppTextField(
              label: 'Tu pedido al proveedor *',
              controller: _request,
              maxLines: 3,
              validator: (v) => (v ?? '').trim().length < 10
                  ? 'Mínimo 10 caracteres'
                  : null,
            ),
            gap(),
            _Select<String?>(
              label: '¿Qué solución esperas?',
              value: _solution,
              options: claimSolutions,
              onChanged: (v) => setState(() => _solution = v),
              allowEmpty: true,
            ),
            if (_solution == 'Otro') ...[
              gap(),
              AppTextField(
                label: 'Escribe la solución que esperas *',
                controller: _otherSolution,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Escribe la solución que esperas'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Para adjuntar fotos, facturas o videos usa el libro de '
              'reclamaciones de nuestra web.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Enviar reclamo',
              icon: Icons.send_outlined,
              isLoading: _sending,
              onPressed: _submit,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Lista desplegable. [allowEmpty] agrega la opción "Seleccionar" (sin valor).
class _Select<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool allowEmpty;

  const _Select({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allowEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      key: ValueKey('$label-$value'),
      initialValue: value as String?,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
      ),
      items: [
        if (allowEmpty)
          const DropdownMenuItem<String?>(value: null, child: Text('Seleccionar')),
        for (final o in options) DropdownMenuItem<String?>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Constancia del reclamo registrado.
class ClaimReceiptPage extends StatelessWidget {
  final ClaimReceipt receipt;

  const ClaimReceiptPage({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reclamo registrado'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
        children: [
          Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
          const SizedBox(height: 12),
          Text('Recibimos tu reclamo',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                children: [
                  Text('Número de reclamo', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  SelectableText(
                    receipt.number,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (receipt.deadline != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Te responderemos a más tardar el '
                      '${FormatUtils.date(receipt.deadline!)}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Guarda este número: con él puedes consultar el estado de tu '
            'reclamo desde "Más".',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Volver al inicio',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
    );
  }
}

/// Cómo se muestra el estado de un reclamo (`pendiente`, `en_proceso`, ...).
String claimStatusLabel(String status) => switch (status) {
      'pendiente' => 'Pendiente',
      'en_proceso' => 'En proceso',
      'resuelto' => 'Resuelto',
      'cerrado' => 'Cerrado',
      final other => other,
    };

StatusTagType claimStatusTagType(String status) => switch (status) {
      'resuelto' => StatusTagType.success,
      'cerrado' => StatusTagType.info,
      _ => StatusTagType.warning,
    };

/// Consulta el estado de un reclamo por su número.
Future<void> showClaimLookup(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ClaimLookupSheet(),
    );

class _ClaimLookupSheet extends StatefulWidget {
  const _ClaimLookupSheet();

  @override
  State<_ClaimLookupSheet> createState() => _ClaimLookupSheetState();
}

class _ClaimLookupSheetState extends State<_ClaimLookupSheet> {
  final _number = TextEditingController();
  bool _loading = false;
  ClaimStatus? _status;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final info = context.read<InfoProvider>();
    setState(() {
      _loading = true;
      _error = null;
      _status = null;
    });
    final result = await info.findClaim(_number.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = result.status;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.defaultPadding,
        0,
        AppConstants.defaultPadding,
        MediaQuery.of(context).viewInsets.bottom + AppConstants.defaultPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Consultar un reclamo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Número de reclamo',
            controller: _number,
            prefixIcon: Icons.confirmation_number_outlined,
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Buscar',
            icon: Icons.search,
            isLoading: _loading,
            onPressed: _search,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (status != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status.number, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    StatusTag(
                      label: claimStatusLabel(status.status),
                      type: claimStatusTagType(status.status),
                    ),
                    if (status.deadline != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Respuesta hasta el ${FormatUtils.date(status.deadline!)}',
                        ),
                      ),
                    if (status.response != null) ...[
                      const SizedBox(height: 8),
                      Text('Respuesta', style: theme.textTheme.titleSmall),
                      Text(status.response!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
