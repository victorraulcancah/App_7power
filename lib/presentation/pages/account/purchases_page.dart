import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/purchase_entity.dart';
import '../../components/components.dart';
import '../../providers/load_status.dart';
import '../../providers/purchases_provider.dart';

/// "Mis compras": las hechas en la tienda en línea (con seguimiento) y, si la
/// cuenta está vinculada al ERP, las de tienda física.
class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchasesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchases = context.watch<PurchasesProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis compras'),
          bottom: const TabBar(
            tabs: [Tab(text: 'En línea'), Tab(text: 'En tienda')],
          ),
        ),
        body: switch (purchases.status) {
          LoadStatus.initial ||
          LoadStatus.loading =>
            const LoadingIndicator(),
          LoadStatus.error => ErrorState(
              message: purchases.errorMessage,
              onRetry: purchases.load,
            ),
          LoadStatus.loaded => TabBarView(
              children: [
                _OnlineList(purchases: purchases),
                _StoreList(purchases: purchases),
              ],
            ),
        },
      ),
    );
  }
}

class _OnlineList extends StatelessWidget {
  final PurchasesProvider purchases;

  const _OnlineList({required this.purchases});

  @override
  Widget build(BuildContext context) {
    if (purchases.online.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Aún no tienes compras en línea',
        message: 'Cuando pagues un pedido, lo verás aquí con su seguimiento.',
      );
    }

    return RefreshIndicator(
      onRefresh: purchases.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        itemCount: purchases.online.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = purchases.online[i];
          return Card(
            child: ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PurchaseDetailPage(purchase: p),
              )),
              title: Text(p.code),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.date != null) Text(FormatUtils.dateTime(p.date!)),
                    const SizedBox(height: 6),
                    StatusTag(label: p.stage.label, type: _tagType(p.stage)),
                  ],
                ),
              ),
              trailing: Text(
                FormatUtils.money(p.total, currency: p.currency),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          );
        },
      ),
    );
  }
}

StatusTagType _tagType(PurchaseStage stage) => switch (stage) {
      PurchaseStage.pendingInvoice => StatusTagType.warning,
      PurchaseStage.invoiced => StatusTagType.info,
      PurchaseStage.inDelivery => StatusTagType.info,
      PurchaseStage.delivered => StatusTagType.success,
      PurchaseStage.cancelled => StatusTagType.error,
    };

class _StoreList extends StatelessWidget {
  final PurchasesProvider purchases;

  const _StoreList({required this.purchases});

  @override
  Widget build(BuildContext context) {
    if (!purchases.storeLinked) {
      return const EmptyState(
        icon: Icons.link_off,
        title: 'Cuenta sin vincular',
        message: 'Tus compras en tienda aparecen cuando tu cuenta está '
            'vinculada. Pídele a un asesor que la vincule.',
      );
    }
    if (purchases.store.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'Aún no tienes compras en tienda',
      );
    }

    return RefreshIndicator(
      onRefresh: purchases.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        itemCount: purchases.store.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final sale = purchases.store[i];
          return Card(
            child: ListTile(
              onTap: () => _showSale(context, sale),
              title: Text(sale.document),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sale.date != null) Text(sale.date!),
                    const SizedBox(height: 6),
                    StatusTag(
                      label: sale.cancelled ? 'Anulada' : 'Emitida',
                      type: sale.cancelled
                          ? StatusTagType.error
                          : StatusTagType.success,
                    ),
                  ],
                ),
              ),
              trailing: Text(
                FormatUtils.money(sale.total, currency: sale.currency),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSale(BuildContext context, StoreSaleEntity sale) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            Text(sale.document, style: Theme.of(context).textTheme.titleLarge),
            if (sale.notes != null) Text(sale.notes!),
            const Divider(height: 24),
            for (final item in sale.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text(
                  '${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)} x '
                  '${FormatUtils.money(item.price, currency: sale.currency)}',
                ),
                trailing: Text(
                    FormatUtils.money(item.subtotal, currency: sale.currency)),
              ),
            const Divider(height: 24),
            Row(
              children: [
                Text('Total', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text(
                  FormatUtils.money(sale.total, currency: sale.currency),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalle de una compra en línea con su seguimiento.
class PurchaseDetailPage extends StatelessWidget {
  final PurchaseEntity purchase;

  const PurchaseDetailPage({super.key, required this.purchase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = purchase;
    String money(double v) => FormatUtils.money(v, currency: p.currency);

    return Scaffold(
      appBar: AppBar(title: Text(p.code)),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          if (p.date != null)
            Text(FormatUtils.dateTime(p.date!), style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          StatusTag(label: p.stage.label, type: _tagType(p.stage)),
          const SizedBox(height: 4),
          Text(p.stage.description),
          const SizedBox(height: 16),
          if (p.stage != PurchaseStage.cancelled) _Tracking(stage: p.stage),
          if (p.invoiceNumber != null) ...[
            const Divider(height: 32),
            Text('Comprobante', style: theme.textTheme.titleSmall),
            Text(p.invoiceNumber!),
            if (p.invoiceSentAt != null && p.customerEmail != null)
              Text('Enviado a ${p.customerEmail}',
                  style: theme.textTheme.bodySmall),
          ],
          if (p.deliveryAddress != null) ...[
            const Divider(height: 32),
            Text('Dirección de entrega', style: theme.textTheme.titleSmall),
            Text(p.deliveryAddress!),
          ],
          const Divider(height: 32),
          Text('Productos', style: theme.textTheme.titleSmall),
          for (final item in p.items)
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
          _Line('Subtotal', money(p.subtotal)),
          if (p.igv > 0) _Line('IGV', money(p.igv)),
          if (p.discount > 0)
            _Line(
              p.couponCode == null
                  ? 'Descuento'
                  : 'Descuento (${p.couponCode})',
              '- ${money(p.discount)}',
            ),
          if (p.shipping > 0) _Line('Envío', money(p.shipping)),
          const SizedBox(height: 4),
          _Line('Total', money(p.total), bold: true),
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

/// Los 4 pasos del seguimiento: los hechos con check, el actual resaltado.
class _Tracking extends StatelessWidget {
  final PurchaseStage stage;

  const _Tracking({required this.stage});

  static const _steps = [
    PurchaseStage.pendingInvoice,
    PurchaseStage.invoiced,
    PurchaseStage.inDelivery,
    PurchaseStage.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = stage.step;

    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                i < current
                    ? Icons.check_circle
                    : (i == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                color: i <= current
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _steps[i].label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: i == current ? FontWeight.bold : FontWeight.normal,
                    color: i <= current ? null : theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
