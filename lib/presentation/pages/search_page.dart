import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/product_entity.dart';
import '../components/components.dart';
import '../providers/product_search_provider.dart';
import '../providers/products_provider.dart';
import 'product_detail_page.dart';

/// Buscador a pantalla completa, como el de la web: un selector de categoría y,
/// mientras se escribe, una lista de sugerencias con foto, nombre, código y
/// precio. Tocar una sugerencia abre el producto; "Ver todos" (o la tecla de
/// buscar) abre la tienda con esos resultados.
class SearchPage extends StatefulWidget {
  /// Se llama al pedir todos los resultados, con el texto y la categoría.
  final void Function(String query, int? categoryId) onSubmit;

  const SearchPage({super.key, required this.onSubmit});

  static Future<void> open(
    BuildContext context, {
    required void Function(String query, int? categoryId) onSubmit,
  }) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SearchPage(onSubmit: onSubmit),
      ));

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  int? _categoryId;

  late final ProductSearchProvider _search =
      context.read<ProductSearchProvider>();

  @override
  void initState() {
    super.initState();
    // Cada vez que se abre, parte de cero.
    _search.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.reset();
    super.dispose();
  }

  void _onChanged(String value) {
    _search.update(value, categoryId: _categoryId);
    setState(() {});
  }

  void _onCategory(int? id) {
    setState(() => _categoryId = id);
    _search.update(_controller.text, categoryId: id);
    // Al elegir una categoría no hace falta esperar a que termine de escribir.
    _search.searchNow();
  }

  void _clear() {
    _controller.clear();
    _search.update('', categoryId: _categoryId);
    setState(() {});
  }

  /// Abre la tienda con lo escrito y la categoría elegida.
  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty && _categoryId == null) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
    widget.onSubmit(query, _categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final search = context.watch<ProductSearchProvider>();
    final categories = context.watch<ProductsProvider>().categories;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF26262B),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          key: const Key('search-field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Buscar productos, marcas o códigos',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.close),
              onPressed: _clear,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.defaultPadding, 4, AppConstants.defaultPadding, 8,
            ),
            child: DropdownButtonFormField<int?>(
              key: const Key('search-category'),
              initialValue: _categoryId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todas las categorías'),
                ),
                for (final c in categories)
                  DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(
                      FormatUtils.titleCase(c.name),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _onCategory,
            ),
          ),
          if (search.status == SearchStatus.loading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const Divider(height: 2),
          Expanded(child: _results(context, search, theme)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, ProductSearchProvider search, ThemeData theme) {
    final query = _controller.text.trim();

    switch (search.status) {
      case SearchStatus.idle:
        return _Message(
          icon: Icons.search,
          text: 'Escribe al menos ${ProductSearchProvider.minLength} letras '
              'o elige una categoría.',
        );
      case SearchStatus.error:
        return _Message(
          icon: Icons.error_outline,
          text: 'No se pudo buscar. Revisa tu conexión e intenta de nuevo.',
          actionLabel: 'Reintentar',
          onAction: search.searchNow,
        );
      case SearchStatus.loading:
      case SearchStatus.loaded:
        // Mientras llega la respuesta se sigue mostrando lo anterior.
        if (search.status == SearchStatus.loaded && search.results.isEmpty) {
          return _Message(
            icon: Icons.search_off,
            text: query.isEmpty
                ? 'No hay productos en esa categoría.'
                : 'No encontramos productos para «$query».',
          );
        }
        final results = search.results;
        return ListView(
          children: [
            for (final product in results)
              _SuggestionTile(product: product, query: query),
            if (results.isNotEmpty)
              ListTile(
                key: const Key('search-all'),
                leading: Icon(Icons.arrow_forward, color: theme.colorScheme.primary),
                title: Text(
                  query.isEmpty
                      ? 'Ver todos los productos de la categoría'
                      : 'Ver todos los resultados de «$query»',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: _submit,
              ),
          ],
        );
    }
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

/// Una sugerencia: foto completa, marca, nombre, código y precio.
class _SuggestionTile extends StatelessWidget {
  final ProductEntity product;
  final String query;

  const _SuggestionTile({required this.product, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soldOut = product.stock <= 0;

    return InkWell(
      onTap: () => ProductDetailPage.open(context, product),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
          vertical: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: ProductImage(url: product.imageUrl, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand != null)
                    Text(
                      product.brand!.toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (product.code != null && product.code!.isNotEmpty)
                    Text(
                      '${product.code}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800),
                    ),
                  const SizedBox(height: 2),
                  if (soldOut)
                    Text(
                      'Agotado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (product.priceVisible)
                    PriceText(price: product.price, currency: product.currency),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
