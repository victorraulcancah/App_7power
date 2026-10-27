import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/product_filters.dart';
import '../providers/products_provider.dart';

/// Hoja con los filtros del catálogo: orden, marcas y rango de precio.
Future<void> showProductFilters(BuildContext context, ProductsProvider provider) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProductFiltersSheet(provider: provider),
    );

class ProductFiltersSheet extends StatefulWidget {
  final ProductsProvider provider;

  const ProductFiltersSheet({super.key, required this.provider});

  @override
  State<ProductFiltersSheet> createState() => _ProductFiltersSheetState();
}

class _ProductFiltersSheetState extends State<ProductFiltersSheet> {
  late ProductFilters _draft = widget.provider.filters;
  late RangeValues _range = _initialRange();

  ProductsProvider get _provider => widget.provider;

  RangeValues _initialRange() {
    final min = _provider.priceMin;
    final max = _provider.priceMax;
    if (min == null || max == null || max <= min) return const RangeValues(0, 1);
    final f = _provider.filters;
    return RangeValues(
      (f.minPrice ?? min).clamp(min, max),
      (f.maxPrice ?? max).clamp(min, max),
    );
  }

  /// El rango solo cuenta como filtro si se movió de los topes.
  ProductFilters get _result {
    if (!_provider.canFilterByPrice) return _draft.copyWith(clearPrice: true);
    final min = _provider.priceMin!;
    final max = _provider.priceMax!;
    final untouched = _range.start <= min && _range.end >= max;
    return untouched
        ? _draft.copyWith(clearPrice: true)
        : _draft.copyWith(
            minPrice: _range.start.floorToDouble(),
            maxPrice: _range.end.ceilToDouble(),
          );
  }

  void _toggleBrand(int id) {
    final brands = {..._draft.brandIds};
    brands.contains(id) ? brands.remove(id) : brands.add(id);
    setState(() => _draft = _draft.copyWith(brandIds: brands));
  }

  void _reset() => setState(() {
        _draft = ProductFilters.none;
        if (_provider.canFilterByPrice) {
          _range = RangeValues(_provider.priceMin!, _provider.priceMax!);
        }
      });

  void _apply() {
    _provider.applyFilters(_result);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = _provider.products.firstOrNull?.currency;
    final active = _result.activeCount;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.defaultPadding, 0, AppConstants.defaultPadding, 8,
                ),
                children: [
                  Text('Filtros', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Text('Ordenar por', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final sort in ProductSort.values)
                        ChoiceChip(
                          label: Text(sort.label),
                          selected: _draft.sort == sort,
                          onSelected: (_) =>
                              setState(() => _draft = _draft.copyWith(sort: sort)),
                        ),
                    ],
                  ),
                  if (_provider.brands.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Marcas', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final brand in _provider.brands)
                          FilterChip(
                            label: Text('${brand.name} (${brand.productsCount})'),
                            selected: _draft.brandIds.contains(brand.id),
                            onSelected: (_) => _toggleBrand(brand.id),
                          ),
                      ],
                    ),
                  ],
                  if (_provider.canFilterByPrice) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('Precio', style: theme.textTheme.titleSmall),
                        const Spacer(),
                        Text(
                          '${FormatUtils.money(_range.start.floorToDouble(), currency: currency)}'
                          ' – ${FormatUtils.money(_range.end.ceilToDouble(), currency: currency)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    RangeSlider(
                      min: _provider.priceMin!,
                      max: _provider.priceMax!,
                      values: _range,
                      labels: RangeLabels(
                        _range.start.round().toString(),
                        _range.end.round().toString(),
                      ),
                      onChanged: (v) => setState(() => _range = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.defaultPadding, 8, AppConstants.defaultPadding, 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: active == 0 ? null : _reset,
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _apply,
                      child: Text(active == 0 ? 'Ver productos' : 'Aplicar ($active)'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
