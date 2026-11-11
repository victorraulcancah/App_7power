import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/statement_entity.dart';
import '../../../theme/app_theme.dart';
import '../../components/components.dart';
import '../../providers/auth_provider.dart';
import '../../providers/load_status.dart';
import '../../utils/document_pdf.dart';
import '../../providers/statement_provider.dart';

/// "Estado de cuenta": crédito, deuda y movimientos del cliente en el ERP.
class StatementPage extends StatefulWidget {
  const StatementPage({super.key});

  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final code = context.read<AuthProvider>().user?.erpCode;
      context.read<StatementProvider>().open(code);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Al llegar cerca del final se pide la página siguiente.
  void _onScroll() {
    if (_scroll.position.extentAfter < 300) {
      context.read<StatementProvider>().loadMore();
    }
  }

  Future<void> _pickRange() async {
    final provider = context.read<StatementProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: provider.from, end: provider.to),
      helpText: 'Rango del estado de cuenta',
      saveText: 'Aplicar',
    );
    if (picked != null) await provider.setRange(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final statement = context.watch<StatementProvider>();

    return Scaffold(
      backgroundColor: AppThemeSurface.canvas,
      appBar: AppBar(title: const Text('Estado de cuenta')),
      body: switch (statement.status) {
        LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
        LoadStatus.error => statement.isLinked
            ? ErrorState(
                message: statement.errorMessage,
                onRetry: statement.reload,
              )
            : const EmptyState(
                icon: Icons.link_off,
                title: 'Tu cuenta aún no está vinculada',
                message: 'Contacta a servicio al cliente para vincular tu '
                    'cuenta con tu historial en 7Power y ver aquí tu estado '
                    'de cuenta.',
              ),
        LoadStatus.loaded => _content(context, statement),
      },
    );
  }

  Widget _content(BuildContext context, StatementProvider statement) {
    final rows = _groupByDocument(statement.movements);

    // Si lo cargado no llena la pantalla no hay scroll que pida más (por
    // ejemplo, con una búsqueda que deja pocas filas): se piden las páginas
    // que falten hasta llenarla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0 &&
          statement.hasMore &&
          !statement.isLoadingMore) {
        statement.loadMore();
      }
    });

    return RefreshIndicator(
      onRefresh: statement.reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        // Cabecera + documentos + pie (cargando / cuántos se ven).
        itemCount: rows.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _Header(onPickRange: _pickRange);
          if (i == rows.length + 1) return _Footer(statement: statement);
          final row = rows[i - 1];
          return row.length == 1 && row.first.document == '-'
              ? _MovementCard(movement: row.first)
              : _DocumentCard(lines: row);
        },
      ),
    );
  }
}

/// Junta en un solo documento las líneas seguidas que son del mismo (una venta
/// llega del ERP una fila por producto). Los pagos van cada uno por su lado.
List<List<AccountMovement>> _groupByDocument(List<AccountMovement> movements) {
  final rows = <List<AccountMovement>>[];
  for (final m in movements) {
    if (m.document != '-' && rows.isNotEmpty && rows.last.first.document == m.document) {
      rows.last.add(m);
    } else {
      rows.add([m]);
    }
  }
  return rows;
}

/// Fondo gris muy claro de las pantallas con tarjetas.
class AppThemeSurface {
  static const Color canvas = Color(0xFFF6F6F7);
}

class _Header extends StatelessWidget {
  final VoidCallback onPickRange;

  const _Header({required this.onPickRange});

  @override
  Widget build(BuildContext context) {
    final statement = context.watch<StatementProvider>();
    final s = statement.summary;
    final theme = Theme.of(context);
    final range = 'Del ${FormatUtils.date(statement.from)} al '
        '${FormatUtils.date(statement.to)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BalanceCard(summary: s),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.credit_card_outlined,
                label: 'Línea de crédito',
                value: FormatUtils.money(s.creditLimit),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Crédito disponible',
                value: FormatUtils.money(s.creditAvailable),
                negative: s.creditAvailable < 0,
              ),
            ),
          ],
        ),
        if (s.hasPreviousDebt)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Deuda anterior: ${FormatUtils.money(s.previousDebtSoles)}'
                    '${s.previousDebtDollars > 0 ? ' · ${FormatUtils.money(s.previousDebtDollars, currency: 'd')}' : ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: statement.setSearch,
                decoration: InputDecoration(
                  hintText: 'Buscar en la descripción',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E2E6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E2E6)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Elegir fechas',
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range_outlined),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                side: const BorderSide(color: Color(0xFFE2E2E6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onPickRange,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  range,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          statement.total == 1 ? '1 movimiento' : '${statement.total} movimientos',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (statement.movements.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No hay movimientos registrados.')),
          ),
      ],
    );
  }
}

/// Tarjeta principal: lo que se debe hoy y cuánta línea de crédito se usó.
class _BalanceCard extends StatelessWidget {
  final AccountSummary summary;

  const _BalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.onPrimary;
    final used = summary.creditLimit > 0
        ? (summary.creditUsed / summary.creditLimit).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: on.withValues(alpha: 0.8), size: 18),
              const SizedBox(width: 8),
              Text(
                'Deuda total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: on.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            FormatUtils.money(summary.debtSoles),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: on,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (summary.debtDollars > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                FormatUtils.money(summary.debtDollars, currency: 'd'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: on.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: used,
              minHeight: 8,
              backgroundColor: on.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(
                used >= 0.9 ? const Color(0xFFFFB74D) : on,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Línea utilizada',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: on.withValues(alpha: 0.8)),
              ),
              const Spacer(),
              Text(
                '${FormatUtils.money(summary.creditUsed)}  ·  ${(used * 100).round()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: on,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool negative;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.negative = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = negative ? theme.colorScheme.error : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E9EC)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accent.withValues(alpha: 0.10),
            foregroundColor: accent,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: negative ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un movimiento como tarjeta: documento y tipo arriba, y debajo los datos en
/// filas "dato / valor" con el monto al final.
class _MovementCard extends StatelessWidget {
  final AccountMovement movement;

  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = movement;
    final inDollars = m.dollars > 0;

    final (label, tagType, icon, tint) = m.isVoided
        ? ('Anulada', StatusTagType.error, Icons.block, theme.colorScheme.error)
        : m.isPayment
            ? ('Pago', StatusTagType.error, Icons.payments_outlined, theme.colorScheme.error)
            : ('Venta', StatusTagType.info, Icons.shopping_bag_outlined, Colors.blue.shade700);
    // Como en el ERP, los pagos y las ventas anuladas van en rojo.
    final amountColor = m.isVoided || m.isPayment ? theme.colorScheme.error : null;

    return DataCard(
      icon: icon,
      iconColor: tint,
      badge: m.document == '-' ? null : m.document,
      trailing: StatusTag(label: label, type: tagType),
      fields: [
        if (m.date != null) DataField('Fecha', FormatUtils.date(m.date!.toLocal())),
        DataField('Descripción', m.description, maxLines: 3),
        if (m.quantity != null) DataField('Cantidad', '${m.quantity}'),
      ],
      footerLabel: 'Monto',
      footerValue: inDollars
          ? FormatUtils.money(m.dollars, currency: 'd')
          : FormatUtils.money(m.soles),
      footerColor: amountColor,
    );
  }
}

/// Un documento (venta) como una sola tarjeta, como en las cotizaciones: fecha,
/// cuántos productos y el monto total. Al tocarla se ve el detalle.
class _DocumentCard extends StatelessWidget {
  final List<AccountMovement> lines;

  const _DocumentCard({required this.lines});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = lines.first;
    final voided = lines.any((l) => l.isVoided);
    final (label, tagType, icon, tint) = voided
        ? ('Anulada', StatusTagType.error, Icons.block, theme.colorScheme.error)
        : ('Venta', StatusTagType.info, Icons.shopping_bag_outlined, Colors.blue.shade700);
    final soles = lines.fold<double>(0, (n, l) => n + l.soles);
    final dollars = lines.fold<double>(0, (n, l) => n + l.dollars);

    return DataCard(
      icon: icon,
      iconColor: tint,
      badge: first.document,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusTag(label: label, type: tagType),
          // El ícono del PDF a la derecha y sin agrandar la fila: la tarjeta
          // queda a la misma altura que la de un pago.
          if (first.sale != null)
            IconButton(
              tooltip: 'Ver PDF',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
              onPressed: () => _openPdf(context, lines),
            ),
        ],
      ),
      fields: [
        if (first.date != null)
          DataField('Fecha', FormatUtils.date(first.date!.toLocal())),
      ],
      footerLabel: 'Monto',
      footerValue: _amount(soles, dollars),
      footerColor: voided ? theme.colorScheme.error : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StatementDocumentPage(lines: lines)),
      ),
      // Todos los productos del documento en la misma tarjeta.
      children: [
        const SizedBox(height: 4),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(l.description, style: theme.textTheme.bodyMedium),
                ),
                if (l.quantity != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    '× ${l.quantity}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Abre el PDF del documento (nota de venta, con el diseño del ERP).
void _openPdf(BuildContext context, List<AccountMovement> lines) {
  final sale = lines.first.sale;
  if (sale != null) openDocumentPdf(context, pdfFromSale(sale));
}

String _amount(double soles, double dollars) => dollars > 0 && soles == 0
    ? FormatUtils.money(dollars, currency: 'd')
    : FormatUtils.money(soles);

/// El detalle de un documento (una venta), con el mismo formato del detalle
/// de una cotización: estado y fecha, productos, forma de pago y totales; y el
/// botón para ver e imprimir el PDF.
class StatementDocumentPage extends StatelessWidget {
  final List<AccountMovement> lines;

  const StatementDocumentPage({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = lines.first;
    final sale = first.sale;
    final voided = lines.any((l) => l.isVoided);
    final inDollars = sale?.inDollars ?? lines.any((l) => l.dollars > 0);
    final currency = inDollars ? 'd' : null;
    String money(double v) => FormatUtils.money(v, currency: currency);

    // Los productos de la venta; si no se conocen, las líneas del movimiento.
    final items = (sale != null && sale.lines.isNotEmpty)
        ? [
            for (final l in sale.lines)
              (
                name: l.name,
                brand: l.brand,
                code: l.code,
                quantity: l.quantity,
                unit: l.unitPrice,
                total: l.total,
              ),
          ]
        : [
            for (final l in lines)
              (
                name: l.description,
                brand: null,
                code: '',
                quantity: l.quantity ?? 1,
                unit: null,
                total: inDollars ? l.dollars : l.soles,
              ),
          ];
    final total = items.fold<double>(0, (n, i) => n + i.total);
    final discount = sale?.lines.fold<double>(0, (n, l) => n + l.discount) ?? 0;
    final igv = (sale?.isVoucher ?? false) ? total - total / 1.18 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(first.document),
        actions: [
          if (sale != null)
            IconButton(
              tooltip: 'Ver PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => _openPdf(context, lines),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              voided
                  ? const StatusTag(label: 'Anulada', type: StatusTagType.error)
                  : const StatusTag(label: 'Venta', type: StatusTagType.info),
              if (first.date != null) Text(FormatUtils.date(first.date!.toLocal())),
            ],
          ),
          if (sale != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(sale.title, style: theme.textTheme.bodySmall),
            ),
          const Divider(height: 32),
          Text('Productos', style: theme.textTheme.titleSmall),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.inventory_2_outlined, color: theme.colorScheme.outline),
              ),
              title: Text(
                item.brand == null ? item.name : '${item.name} | ${item.brand}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text([
                if (item.code.isNotEmpty) item.code,
                if (item.unit != null)
                  '${item.quantity} x ${money(item.unit!)}'
                else
                  'Cant. ${item.quantity}',
              ].join(' · ')),
              trailing: Text(money(item.total)),
            ),
          const Divider(height: 32),
          if (sale != null && sale.paymentMethods.isNotEmpty) ...[
            Text('Pago', style: theme.textTheme.titleSmall),
            Text(sale.paymentMethods.join(', ')),
            const Divider(height: 32),
          ],
          if (sale != null && (sale.sellerName != '-' || sale.warehouseName != null)) ...[
            Text('Atención', style: theme.textTheme.titleSmall),
            if (sale.sellerName != '-') Text('Vendedor: ${sale.sellerName}'),
            if (sale.warehouseName != null) Text('Sucursal: ${sale.warehouseName}'),
            const Divider(height: 32),
          ],
          if (sale?.observations != null) ...[
            Text('Observaciones', style: theme.textTheme.titleSmall),
            Text(sale!.observations!),
            const Divider(height: 32),
          ],
          if (igv > 0) _TotalLine('Subtotal', money(total - igv)),
          if (igv > 0) _TotalLine('IGV', money(igv)),
          if (discount > 0) _TotalLine('Descuento', money(discount)),
          _TotalLine('Total', money(total), bold: true),
          if (sale != null) ...[
            const SizedBox(height: 24),
            AppButton(
              label: 'Ver PDF / Imprimir',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: () => _openPdf(context, lines),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _TotalLine(this.label, this.value, {this.bold = false});

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

class _Footer extends StatelessWidget {
  final StatementProvider statement;

  const _Footer({required this.statement});

  @override
  Widget build(BuildContext context) {
    if (statement.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (statement.total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'Mostrando ${statement.loaded} de ${statement.total} movimientos',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
