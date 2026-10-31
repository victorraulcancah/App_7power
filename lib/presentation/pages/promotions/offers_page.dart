import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/promotion_entity.dart';
import '../../components/components.dart';
import '../../providers/load_status.dart';
import '../../providers/promotions_provider.dart';
import '../product_detail_page.dart';

/// Ofertas: el banner activo y los productos con descuento.
class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PromotionsProvider>().loadOffers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final promotions = context.watch<PromotionsProvider>();
    final offers = promotions.offers;

    return Scaffold(
      appBar: AppBar(title: const Text('Ofertas')),
      body: switch (promotions.offersStatus) {
        LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
        LoadStatus.error => ErrorState(
            message: promotions.offersError,
            onRetry: promotions.loadOffers,
          ),
        LoadStatus.loaded => offers.products.isEmpty
            ? const EmptyState(
                icon: Icons.local_fire_department_outlined,
                title: 'No hay ofertas por ahora',
                message: 'Vuelve pronto: aquí verás los productos con descuento.',
              )
            : RefreshIndicator(
                onRefresh: promotions.loadOffers,
                child: ListView(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  children: [
                    if (offers.imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ProductImage(
                          url: offers.imageUrl,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(
                            AppConstants.defaultBorderRadius,
                          ),
                        ),
                      ),
                    for (final product in offers.products)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OfferTile(product: product),
                      ),
                    Text(
                      'El precio final depende de tu lista de precios y se '
                      'confirma en la ficha del producto.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
      },
    );
  }
}

class _OfferTile extends StatelessWidget {
  final OfferProduct product;

  const _OfferTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soldOut = product.stock <= 0;
    final percent = product.discountPercent;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: product.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProductImage(
                url: product.imageUrl,
                width: 84,
                height: 84,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.brand != null)
                      Text(product.brand!, style: theme.textTheme.labelSmall),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          FormatUtils.money(
                            product.discountPrice,
                            currency: product.currency,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (percent > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            FormatUtils.money(
                              product.price,
                              currency: product.currency,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (percent > 0)
                          StatusTag(
                            label: '-${percent % 1 == 0 ? percent.toInt() : percent}%',
                            type: StatusTagType.error,
                          ),
                        if (soldOut) ...[
                          if (percent > 0) const SizedBox(width: 6),
                          const StatusTag(label: 'Agotado'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
