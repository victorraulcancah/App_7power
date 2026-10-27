class CategoryEntity {
  final int id;
  final String name;
  final String? imageUrl;
  final int productsCount;

  const CategoryEntity({
    required this.id,
    required this.name,
    this.imageUrl,
    this.productsCount = 0,
  });
}
