import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../components/components.dart';
import '../../providers/load_status.dart';
import '../../providers/promotions_provider.dart';

/// Cupones vigentes. El código se copia y se escribe en el checkout al pagar.
class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PromotionsProvider>().loadCoupons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final promotions = context.watch<PromotionsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cupones')),
      body: switch (promotions.couponsStatus) {
        LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
        LoadStatus.error => ErrorState(
            message: promotions.couponsError,
            onRetry: promotions.loadCoupons,
          ),
        LoadStatus.loaded => promotions.coupons.isEmpty
            ? const EmptyState(
                icon: Icons.local_offer_outlined,
                title: 'No hay cupones activos',
                message: 'Cuando haya uno vigente lo verás aquí.',
              )
            : RefreshIndicator(
                onRefresh: promotions.loadCoupons,
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: promotions.coupons.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _CouponCard(coupon: promotions.coupons[i]),
                ),
              ),
      },
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponOffer coupon;

  const _CouponCard({required this.coupon});

  String get _discount => coupon.isPercentage
      ? '${coupon.value % 1 == 0 ? coupon.value.toInt() : coupon.value}% de descuento'
      : '${FormatUtils.money(coupon.value)} de descuento';

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: coupon.code));
    if (context.mounted) {
      AppSnackbar.success(context, 'Código ${coupon.code} copiado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(coupon.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              _discount,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            if (coupon.description != null) ...[
              const SizedBox(height: 6),
              Text(coupon.description!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (coupon.minPurchase != null && coupon.minPurchase! > 0)
                  StatusTag(
                    label: 'Compra mínima ${FormatUtils.money(coupon.minPurchase!)}',
                    type: StatusTagType.neutral,
                  ),
                if (coupon.firstPurchaseOnly)
                  const StatusTag(
                    label: 'Solo primera compra',
                    type: StatusTagType.info,
                  ),
                if (coupon.endsAt != null)
                  StatusTag(
                    label: 'Hasta el ${FormatUtils.date(coupon.endsAt!)}',
                    type: StatusTagType.neutral,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                      borderRadius:
                          BorderRadius.circular(AppConstants.defaultBorderRadius),
                    ),
                    child: Text(
                      coupon.code,
                      style: theme.textTheme.titleMedium?.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Copiar código',
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
