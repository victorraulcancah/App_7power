import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/product_filters.dart';
import '../components/components.dart';
import '../providers/products_provider.dart';

/// Marcas del catálogo: primero las de la vitrina (en el orden que define la
/// empresa) y luego las demás por nombre. Al elegir una se abre la tienda con
/// esa marca filtrada.
class BrandsPage extends StatelessWidget {
  /// Se llama con la marca elegida, después de cerrar esta pantalla.
  final ValueChanged<BrandEntity> onSelected;

  const BrandsPage({super.key, required this.onSelected});

  static int _byName(BrandEntity a, BrandEntity b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  static List<BrandEntity> sorted(List<BrandEntity> brands) {
    // Una marca de la vitrina sin orden (0) queda al final de la vitrina, por
    // nombre: así no desplaza a las que la empresa ordenó.
    final ordered = brands.where((b) => b.inShowcase && b.showcaseOrder > 0).toList()
      ..sort((a, b) => a.showcaseOrder.compareTo(b.showcaseOrder));
    final unordered = brands.where((b) => b.inShowcase && b.showcaseOrder <= 0).toList()
      ..sort(_byName);
    final rest = brands.where((b) => !b.inShowcase).toList()..sort(_byName);
    return [...ordered, ...unordered, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    final brands = sorted(provider.brands);

    return Scaffold(
      appBar: AppBar(title: const Text('Marcas')),
      body: brands.isEmpty
          ? ErrorState(
              message: 'No pudimos cargar las marcas.',
              onRetry: provider.init,
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemCount: brands.length,
              itemBuilder: (context, i) => _BrandTile(
                brand: brands[i],
                onTap: () {
                  Navigator.of(context).pop();
                  onSelected(brands[i]);
                },
              ),
            ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  final BrandEntity brand;
  final VoidCallback onTap;

  const _BrandTile({required this.brand, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: brand.imageUrl == null
                    ? Center(
                        child: Text(
                          brand.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      )
                    : ProductImage(url: brand.imageUrl, fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              Text(
                brand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
              Text(
                '${brand.productsCount} '
                '${brand.productsCount == 1 ? 'producto' : 'productos'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
