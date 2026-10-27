import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/product_detail_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../components/components.dart';
import '../providers/product_detail_provider.dart';
import 'cart_page.dart';

/// Ficha de un producto: galería, precio, stock, descripción y agregar al
/// carrito.
class ProductDetailPage extends StatefulWidget {
  final int productId;

  /// Datos que ya se tienen del catálogo, para mostrar algo mientras carga.
  final ProductEntity? preview;

  const ProductDetailPage({super.key, required this.productId, this.preview});

  /// Abre la ficha de [product].
  static Future<void> open(BuildContext context, ProductEntity product) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ProductDetailPage(productId: product.id, preview: product),
      ));

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductDetailProvider>().load(widget.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductDetailProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Producto'),
        actions: const [CartButton()],
      ),
      body: switch (provider.status) {
        ProductDetailStatus.loading =>
          const LoadingIndicator(message: 'Cargando producto...'),
        ProductDetailStatus.error => ErrorState(
            message: provider.errorMessage,
            onRetry: () => provider.load(widget.productId),
          ),
        ProductDetailStatus.loaded => _content(provider.detail!),
      },
    );
  }

  Widget _content(ProductDetailEntity detail) {
    final product = detail.product;
    final theme = Theme.of(context);
    final maxQuantity = product.stock > 0 ? product.stock : 1;

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              _Gallery(images: detail.images),
              Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.brand != null)
                      Text(product.brand!.toUpperCase(),
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text(product.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (product.code != null)
                          Text('Código: ${product.code}',
                              style: theme.textTheme.bodySmall),
                        StatusTag(
                          label: product.isAvailable
                              ? 'En stock (${product.stock})'
                              : 'Agotado',
                          type: product.isAvailable
                              ? StatusTagType.success
                              : StatusTagType.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PriceText(
                      price: product.price,
                      currency: product.currency,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    for (final entry in detail.sections.entries)
                      _Section(title: entry.key, body: entry.value),
                  ],
                ),
              ),
              if (detail.related.isNotEmpty) ...[
                const SectionHeader(title: 'Productos relacionados'),
                SizedBox(
                  height: 300,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    itemCount: detail.related.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final p = detail.related[i];
                      return SizedBox(
                        width: 170,
                        child: ProductCard(
                          name: p.name,
                          brand: p.brand,
                          imageUrl: p.imageUrl,
                          price: p.price,
                          currency: p.currency,
                          outOfStock: !p.isAvailable,
                          onTap: () => ProductDetailPage.open(context, p),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Row(
              children: [
                if (product.isAvailable) ...[
                  QuantitySelector(
                    value: _quantity.clamp(1, maxQuantity),
                    max: maxQuantity,
                    onChanged: (v) => setState(() => _quantity = v),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: AppButton(
                    label: product.isAvailable ? 'Agregar al carrito' : 'Agotado',
                    icon: Icons.add_shopping_cart,
                    onPressed: product.isAvailable
                        ? () => CartActions.add(
                              context,
                              product,
                              quantity: _quantity,
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  final List<String> images;

  const _Gallery({required this.images});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images.isEmpty ? <String?>[null] : widget.images;

    return Column(
      children: [
        // Cuadrada, pero sin pasar de 360 px de alto (tablets y pantallas
        // anchas la volverían enorme).
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) =>
                  ProductImage(url: images[i], fit: BoxFit.contain),
            ),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
