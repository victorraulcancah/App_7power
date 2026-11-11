import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format_utils.dart';
import '../../domain/entities/category_entity.dart';
import '../components/components.dart';
import '../providers/products_provider.dart';

/// Pestaña "Categorías": la lista de todas las categorías de la tienda. Al
/// tocar una se abre la tienda con sus productos.
class CategoriesPage extends StatelessWidget {
  /// Abre la tienda en esa categoría (null = todos los productos).
  final void Function({int? categoryId}) onOpenShop;

  const CategoriesPage({super.key, required this.onOpenShop});

  /// Las categorías sin productos no llevan a nada: se ocultan. Si el servidor
  /// no manda las cantidades, se muestran todas.
  static List<CategoryEntity> visible(List<CategoryEntity> all) {
    final withProducts = all.where((c) => c.productsCount > 0).toList();
    return withProducts.isEmpty ? all : withProducts;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    final categories = visible(provider.categories);

    if (categories.isEmpty) {
      return provider.categoriesLoaded
          ? EmptyState(
              icon: Icons.category_outlined,
              title: 'No hay categorías',
              message: 'No pudimos cargar las categorías.',
              actionLabel: 'Reintentar',
              onAction: provider.reloadCategories,
            )
          : const LoadingIndicator();
    }

    return ListView.separated(
      key: const Key('categories-list'),
      itemCount: categories.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Row(
            key: const Key('category-all'),
            icon: Icons.apps_rounded,
            title: 'Todos los productos',
            onTap: () => onOpenShop(),
          );
        }
        final category = categories[i - 1];
        return _Row(
          key: Key('category-${category.id}'),
          imageUrl: category.imageUrl,
          icon: Icons.category_outlined,
          title: FormatUtils.titleCase(category.name),
          count: category.productsCount,
          onTap: () => onOpenShop(categoryId: category.id),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? imageUrl;
  final int? count;
  final VoidCallback onTap;

  const _Row({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.imageUrl,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: SizedBox(
        width: 40,
        height: 40,
        child: imageUrl == null
            ? Icon(icon, color: theme.colorScheme.primary)
            : ClipOval(
                child: ProductImage(
                  url: imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  fallback: Icon(icon, color: theme.colorScheme.primary),
                ),
              ),
      ),
      title: Text(title, style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count != null && count! > 0)
            Text(
              '$count',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}
