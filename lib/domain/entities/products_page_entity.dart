import 'product_entity.dart';

/// Una página de resultados del catálogo.
class ProductsPageEntity {
  final List<ProductEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  /// Precio mínimo y máximo del resultado SIN contar el rango de precio
  /// elegido: son los topes del deslizador. Null si el cliente no tiene lista
  /// de precios (el backend no filtra por precio en ese caso).
  final double? priceMin;
  final double? priceMax;

  const ProductsPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.priceMin,
    this.priceMax,
  });

  bool get hasMore => currentPage < lastPage;
}
