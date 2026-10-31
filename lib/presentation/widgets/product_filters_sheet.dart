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

/// Aspecto de los selectores de la hoja (borde redondeado, como los campos).
InputDecoration _selectDecoration({required IconData icon, String? hint}) =>
    InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
    );

/// Selector de marcas: un campo que resume lo elegido y abre una lista con
/// buscador y selección múltiple (son más de diez, no caben como botones).
class _BrandSelect extends StatelessWidget {
  final List<BrandEntity> brands;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const _BrandSelect({
    required this.brands,
    required this.selected,
    required this.onChanged,
  });

  String get _summary {
    final names = [
      for (final b in brands)
        if (selected.contains(b.id)) b.name,
    ];
    if (names.isEmpty) return 'Todas las marcas';
    if (names.length <= 2) return names.join(', ');
    return '${names.length} marcas';
  }

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BrandPicker(brands: brands, initial: selected),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = [
      for (final b in brands)
        if (selected.contains(b.id)) b,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('filter-brands'),
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          onTap: () => _open(context),
          child: InputDecorator(
            decoration: _selectDecoration(icon: Icons.verified_outlined).copyWith(
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              _summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: selected.isEmpty
                  ? theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.outline)
                  : theme.textTheme.bodyLarge,
            ),
          ),
        ),
        if (chosen.length > 2)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final b in chosen)
                  Chip(
                    label: Text(b.name),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => onChanged({...selected}..remove(b.id)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lista de marcas con buscador y casillas. Devuelve lo elegido al pulsar
/// "Listo"; si se cierra sin pulsarlo, no cambia nada.
class _BrandPicker extends StatefulWidget {
  final List<BrandEntity> brands;
  final Set<int> initial;

  const _BrandPicker({required this.brands, required this.initial});

  @override
  State<_BrandPicker> createState() => _BrandPickerState();
}

class _BrandPickerState extends State<_BrandPicker> {
  late final Set<int> _selected = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final brands = [
      for (final b in widget.brands)
        if (q.isEmpty || b.name.toLowerCase().contains(q)) b,
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.defaultPadding, 0, AppConstants.defaultPadding, 8,
                ),
                child: TextField(
                  key: const Key('brand-search'),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar marca',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              Flexible(
                child: brands.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No hay marcas con ese nombre.'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: brands.length,
                        itemBuilder: (context, i) {
                          final brand = brands[i];
                          return CheckboxListTile(
                            key: Key('brand-option-${brand.id}'),
                            value: _selected.contains(brand.id),
                            onChanged: (on) => setState(() {
                              on == true
                                  ? _selected.add(brand.id)
                                  : _selected.remove(brand.id);
                            }),
                            title: Text(brand.name),
                            secondary: Text(
                              '${brand.productsCount}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        },
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
                        onPressed:
                            _selected.isEmpty ? null : () => setState(_selected.clear),
                        child: const Text('Ninguna'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop({..._selected}),
                        child: Text(
                          _selected.isEmpty
                              ? 'Listo'
                              : 'Listo (${_selected.length})',
                        ),
                      ),
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
                  DropdownButtonFormField<ProductSort>(
                    key: const Key('filter-sort'),
                    initialValue: _draft.sort,
                    isExpanded: true,
                    decoration: _selectDecoration(
                      icon: Icons.sort,
                    ),
                    items: [
                      for (final sort in ProductSort.values)
                        DropdownMenuItem(value: sort, child: Text(sort.label)),
                    ],
                    onChanged: (sort) {
                      if (sort != null) {
                        setState(() => _draft = _draft.copyWith(sort: sort));
                      }
                    },
                  ),
                  if (_provider.brands.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Marcas', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _BrandSelect(
                      brands: _provider.brands,
                      selected: _draft.brandIds,
                      onChanged: (ids) =>
                          setState(() => _draft = _draft.copyWith(brandIds: ids)),
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
