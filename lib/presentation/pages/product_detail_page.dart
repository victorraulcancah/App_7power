import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/stock_utils.dart';
import '../../domain/entities/product_detail_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../components/components.dart';
import '../providers/product_detail_provider.dart';
import '../widgets/favorite_button.dart';
import '../widgets/product_tile.dart';
import 'cart_page.dart';
import 'login_page.dart';

/// Ficha de un producto: galería, precio, stock, descripción y agregar al
/// carrito. Sigue las reglas de la web: precio oculto a invitados sin lista de
/// precios, selector de moneda cuando hay más de una, y stock con umbrales.
class ProductDetailPage extends StatefulWidget {
  final int productId;

  const ProductDetailPage({super.key, required this.productId});

  /// Abre la ficha de [product].
  static Future<void> open(BuildContext context, ProductEntity product) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProductDetailPage(productId: product.id),
      ));

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;

  /// Moneda elegida en el selector; null = la que resolvió el servidor.
  String? _currency;

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
        actions: [
          if (provider.detail != null)
            FavoriteButton(product: provider.detail!.product),
          const CartButton(),
        ],
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

  /// El producto con el precio de la moneda elegida (si hay selector).
  ProductEntity _selected(ProductDetailEntity detail) {
    final option = detail.currencyOptions
        .where((o) => o.currency == _currency)
        .firstOrNull;
    return option == null
        ? detail.product
        : detail.product.copyWith(price: option.price, currency: option.currency);
  }

  Widget _content(ProductDetailEntity detail) {
    final product = _selected(detail);
    final theme = Theme.of(context);
    final canBuy = product.priceVisible && product.isAvailable;
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
                    if (product.code != null)
                      Text('Código: ${product.code}',
                          style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    StockLabel(
                      stock: product.stock,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (product.priceVisible &&
                        detail.currencyOptions.length > 1)
                      _CurrencySelector(
                        options: detail.currencyOptions,
                        selected: product.currency,
                        onChanged: (c) => setState(() => _currency = c),
                      ),
                    const SizedBox(height: 16),
                    if (product.priceVisible)
                      PriceText(
                        price: product.price,
                        currency: product.currency,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else
                      const _LockedPriceBanner(),
                    if (product.priceVisible && product.isAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Disponible: ${StockUtils.units(product.stock)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
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
                  height: 330,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultPadding,
                    ),
                    itemCount: detail.related.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => SizedBox(
                      width: 170,
                      child: ProductTile(product: detail.related[i]),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        // Con el precio oculto no hay compra posible: la web no muestra la
        // cantidad ni el botón del carrito.
        if (product.priceVisible)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Row(
                children: [
                  if (canBuy) ...[
                    QuantitySelector(
                      value: _quantity.clamp(1, maxQuantity),
                      max: maxQuantity,
                      onChanged: (v) => setState(() => _quantity = v),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: AppButton(
                      label: canBuy ? 'Agregar al carrito' : 'Sin stock',
                      icon: canBuy ? Icons.add_shopping_cart : Icons.block,
                      onPressed: canBuy
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

class _CurrencySelector extends StatelessWidget {
  final List<CurrencyOption> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _CurrencySelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = FormatUtils.normalizeCurrency(selected);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Text('Moneda', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 12),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final o in options)
                ButtonSegment(
                  value: o.currency,
                  label: Text(o.currency == 'd' ? 'US\$' : 'S/'),
                ),
            ],
            selected: {current},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}

/// Lo que ve un invitado cuando el precio está oculto: invita a iniciar sesión.
class _LockedPriceBanner extends StatelessWidget {
  const _LockedPriceBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: theme.colorScheme.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Precio solo para clientes',
                    style: theme.textTheme.titleSmall),
                Text('Inicia sesión para ver el precio y comprar.',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => LoginPage.open(context),
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
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
