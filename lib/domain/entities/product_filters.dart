/// Orden del catálogo. Solo se ofrecen los que el backend realmente aplica.
///
/// El backend también acepta `price_asc` y `price_desc`, pero ordena por una
/// columna que está en 0 en todo el catálogo: devuelve el mismo orden en ambos
/// casos, así que no se ofrecen.
enum ProductSort {
  relevance(null, 'Relevancia'),
  nameAsc('name_asc', 'Nombre (A-Z)'),
  stockDesc('popularity_desc', 'Mayor stock');

  /// Valor de `sortBy` en la API (null = el orden por defecto del servidor).
  final String? apiValue;
  final String label;

  const ProductSort(this.apiValue, this.label);
}

/// Marca para el filtro del catálogo y la pantalla "Marcas".
class BrandEntity {
  final int id;
  final String name;
  final int productsCount;
  final String? imageUrl;

  /// La empresa elige qué marcas van en la vitrina y en qué orden.
  final bool inShowcase;
  final int showcaseOrder;

  const BrandEntity({
    required this.id,
    required this.name,
    this.productsCount = 0,
    this.imageUrl,
    this.inShowcase = false,
    this.showcaseOrder = 0,
  });
}

/// Filtros del catálogo elegidos en la hoja de filtros (la búsqueda y la
/// categoría tienen sus propios controles).
class ProductFilters {
  final Set<int> brandIds;
  final double? minPrice;
  final double? maxPrice;
  final ProductSort sort;

  const ProductFilters({
    this.brandIds = const {},
    this.minPrice,
    this.maxPrice,
    this.sort = ProductSort.relevance,
  });

  static const ProductFilters none = ProductFilters();

  bool get hasPriceRange => minPrice != null || maxPrice != null;

  /// Cantidad de filtros en uso, para la insignia del botón.
  int get activeCount =>
      (brandIds.isEmpty ? 0 : 1) +
      (hasPriceRange ? 1 : 0) +
      (sort == ProductSort.relevance ? 0 : 1);

  bool get isActive => activeCount > 0;

  ProductFilters copyWith({
    Set<int>? brandIds,
    ProductSort? sort,
    double? minPrice,
    double? maxPrice,
    bool clearPrice = false,
  }) =>
      ProductFilters(
        brandIds: brandIds ?? this.brandIds,
        sort: sort ?? this.sort,
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
      );

  @override
  bool operator ==(Object other) =>
      other is ProductFilters &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.sort == sort &&
      other.brandIds.length == brandIds.length &&
      other.brandIds.containsAll(brandIds);

  @override
  int get hashCode =>
      Object.hash(minPrice, maxPrice, sort, Object.hashAllUnordered(brandIds));
}
