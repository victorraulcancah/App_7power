import 'product_entity.dart';

/// Una página de resultados del catálogo.
class ProductsPageEntity {
  final List<ProductEntity> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const ProductsPageEntity({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;
}
