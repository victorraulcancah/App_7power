import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/statement_entity.dart';
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
    final movements = statement.movements;

    return RefreshIndicator(
      onRefresh: statement.reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        // Cabecera + movimientos + pie (cargando / cuántos se ven).
        itemCount: movements.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _Header(onPickRange: _pickRange);
          if (i == movements.length + 1) return _Footer(statement: statement);
          return _MovementTile(movement: movements[i - 1]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onPickRange;

  const _Header({required this.onPickRange});

  @override
  Widget build(BuildContext context) {
    final statement = context.watch<StatementProvider>();
    final s = statement.summary;
    final theme = Theme.of(context);
    final range = '${FormatUtils.date(statement.from)} - '
        '${FormatUtils.date(statement.to)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Stat('Línea de crédito', FormatUtils.money(s.creditLimit)),
            _Stat(
              'Crédito disponible',
              FormatUtils.money(s.creditAvailable),
              negative: s.creditAvailable < 0,
            ),
            _Stat('Línea utilizada', FormatUtils.money(s.creditUsed)),
            _Stat('Deuda en soles', FormatUtils.money(s.debtSoles)),
            _Stat(
              'Deuda en dólares',
              FormatUtils.money(s.debtDollars, currency: 'd'),
            ),
          ],
        ),
        if (s.hasPreviousDebt)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Deuda anterior: ${FormatUtils.money(s.previousDebtSoles)}'
              '${s.previousDebtDollars > 0 ? ' · ${FormatUtils.money(s.previousDebtDollars, currency: 'd')}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onPickRange,
          icon: const Icon(Icons.date_range_outlined),
          label: Text(range),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: statement.setSearch,
          decoration: const InputDecoration(
            hintText: 'Buscar en la descripción',
            prefixIcon: Icon(Icons.search),
            isDense: true,
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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool negative;

  const _Stat(this.label, this.value, {this.negative = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: negative ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final AccountMovement movement;

  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = movement;
    final color = m.isRed ? theme.colorScheme.error : null;
    final inDollars = m.dollars > 0;

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            m.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
          subtitle: Text(
            [
              if (m.date != null) FormatUtils.date(m.date!.toLocal()),
              if (m.document != '-') m.document,
              if (m.quantity != null) 'Cant. ${m.quantity}',
              if (m.isVoided) 'Anulada',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          trailing: Text(
            inDollars
                ? FormatUtils.money(m.dollars, currency: 'd')
                : FormatUtils.money(m.soles),
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
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
