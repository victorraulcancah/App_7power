import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/statement_entity.dart';
import '../../../theme/app_theme.dart';
import '../../components/components.dart';
import '../../providers/auth_provider.dart';
import '../../providers/load_status.dart';
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
            ? ('Pago', StatusTagType.success, Icons.payments_outlined, Colors.green.shade700)
            : ('Venta', StatusTagType.info, Icons.shopping_bag_outlined, Colors.blue.shade700);
    // Un pago baja la deuda: va en verde; una venta anulada, en rojo.
    final amountColor = m.isVoided
        ? theme.colorScheme.error
        : m.isPayment
            ? Colors.green.shade700
            : null;

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
      trailing: StatusTag(label: label, type: tagType),
      fields: [
        if (first.date != null)
          DataField('Fecha', FormatUtils.date(first.date!.toLocal())),
      ],
      footerLabel: 'Monto',
      footerValue: _amount(soles, dollars),
      footerColor: voided ? theme.colorScheme.error : null,
      onTap: () => _showDocument(context, lines),
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

String _amount(double soles, double dollars) => dollars > 0 && soles == 0
    ? FormatUtils.money(dollars, currency: 'd')
    : FormatUtils.money(soles);

/// El detalle de un documento: cada producto con su cantidad y su monto.
void _showDocument(BuildContext context, List<AccountMovement> lines) {
  final theme = Theme.of(context);
  final first = lines.first;
  final soles = lines.fold<double>(0, (n, l) => n + l.soles);
  final dollars = lines.fold<double>(0, (n, l) => n + l.dollars);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(first.document, style: theme.textTheme.titleLarge),
            if (first.date != null)
              Text(
                FormatUtils.date(first.date!.toLocal()),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lines.length,
                separatorBuilder: (_, _) => const Divider(height: 20),
                itemBuilder: (context, i) {
                  final l = lines[i];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(l.description, style: theme.textTheme.bodyMedium),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _amount(l.soles, l.dollars),
                            style: theme.textTheme.titleSmall,
                          ),
                          if (l.quantity != null)
                            Text(
                              'Cant. ${l.quantity}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Monto', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  _amount(soles, dollars),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
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
