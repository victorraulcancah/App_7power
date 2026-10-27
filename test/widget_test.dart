import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/errors/failures.dart';
import 'package:appecommerce/core/utils/either.dart';
import 'package:appecommerce/data/models/category_model.dart';
import 'package:appecommerce/data/models/product_model.dart';
import 'package:appecommerce/domain/entities/category_entity.dart';
import 'package:appecommerce/domain/entities/product_entity.dart';
import 'package:appecommerce/domain/entities/products_page_entity.dart';
import 'package:appecommerce/domain/repositories/product_repository.dart';
import 'package:appecommerce/domain/usecases/get_categories_usecase.dart';
import 'package:appecommerce/domain/usecases/get_products_usecase.dart';
import 'package:appecommerce/main.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';

/// Repositorio falso: filtra en memoria como lo haría el backend y devuelve
/// los resultados en páginas de [pageSize].
class _FakeRepo implements ProductRepository {
  final List<ProductEntity> products;
  final Failure? failure;
  final int pageSize;
  final List<int> requestedPages = [];

  _FakeRepo(this.products, {this.failure, this.pageSize = 20});

  @override
  Future<Either<Failure, ProductsPageEntity>> getProducts({
    int page = 1,
    String? search,
    int? categoryId,
  }) async {
    requestedPages.add(page);
    if (failure != null) return Either.left(failure!);

    final filtered = products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (search != null &&
          !p.name.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();
    return Either.right(ProductsPageEntity(
      items: items,
      currentPage: page,
      lastPage: (filtered.length / pageSize).ceil().clamp(1, 9999),
      total: filtered.length,
    ));
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async =>
      Either.right(const [
        CategoryEntity(id: 1, name: 'DRIVER'),
        CategoryEntity(id: 2, name: 'RCA'),
      ]);
}

Widget _app(_FakeRepo repo) => MyApp(providers: [
      ChangeNotifierProvider<ProductsProvider>(
        create: (_) => ProductsProvider(
          getProductsUseCase: GetProductsUseCase(repo),
          getCategoriesUseCase: GetCategoriesUseCase(repo),
        ),
      ),
    ]);

ProductEntity _p(int id, String name,
        {int categoryId = 1, double price = 10, int stock = 5}) =>
    ProductEntity(
      id: id,
      name: name,
      categoryId: categoryId,
      price: price,
      currency: 's',
      stock: stock,
    );

void main() {
  test('ProductModel interpreta la respuesta de /productos-publicos', () {
    final p = ProductModel.fromJson({
      'id': 635,
      'nombre': "1.5'' DRIVER 2VC",
      'precio': 45.5,
      'moneda': 'd',
      'stock': 92,
      'imagen_principal': 'http://api.test/storage/productos/a.jpg',
      'categoria': 'DRIVER',
      'categoria_id': 46,
      'marca': '7POWER',
      'codigo_producto': 'DRV2',
    });

    expect(p.price, 45.5);
    expect(p.hasPrice, isTrue);
    expect(p.currency, 'd');
    expect(p.stock, 92);
    expect(p.categoryId, 46);
    expect(p.imageUrl, startsWith('http'));
  });

  test('ProductModel tolera precio null y descarta imagen relativa', () {
    final p = ProductModel.fromJson({
      'id': 1,
      'nombre': 'X',
      'precio': null,
      'stock': 0,
      'imagen_principal': '/placeholder-product.jpg',
    });

    expect(p.price, 0);
    expect(p.hasPrice, isFalse);
    expect(p.imageUrl, isNull);
    expect(p.isAvailable, isFalse);
  });

  test('CategoryModel interpreta /categorias/publicas', () {
    final c = CategoryModel.fromJson({
      'id': 38,
      'nombre': 'ACCESORIOS',
      'imagen_url': 'http://api.test/storage/categorias/a.jpg',
      'productos_count': 39,
    });

    expect(c.name, 'ACCESORIOS');
    expect(c.productsCount, 39);
  });

  testWidgets('Catálogo lista productos, marca agotados y sin precio',
      (tester) async {
    final repo = _FakeRepo([
      _p(1, 'Driver 400W', price: 120),
      _p(2, 'Cable RCA', categoryId: 2, price: 0),
      _p(3, 'Parlante', stock: 0),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Driver 400W'), findsOneWidget);
    expect(find.text('Cable RCA'), findsOneWidget);
    expect(find.text('Parlante'), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Consultar precio'), findsOneWidget);
    expect(find.text('S/ 120.00'), findsOneWidget);
  });

  testWidgets('Buscar y elegir categoría consultan al servidor',
      (tester) async {
    final repo = _FakeRepo([
      _p(1, 'Driver 400W'),
      _p(2, 'Cable RCA', categoryId: 2),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'RCA'));
    await tester.pumpAndSettle();
    expect(find.text('Cable RCA'), findsOneWidget);
    expect(find.text('Driver 400W'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'driver');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Driver 400W'), findsOneWidget);
    expect(find.text('Cable RCA'), findsNothing);
  });

  testWidgets('Al llegar al final carga la siguiente página', (tester) async {
    final repo = _FakeRepo(
      [for (var i = 1; i <= 6; i++) _p(i, 'Producto $i')],
      pageSize: 2,
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(repo.requestedPages, [1]);

    final provider =
        tester.element(find.byType(Scaffold)).read<ProductsProvider>();
    expect(provider.hasMore, isTrue);

    await provider.loadMore();
    await tester.pumpAndSettle();

    expect(repo.requestedPages, [1, 2]);
    expect(provider.products.length, 4);
  });

  testWidgets('Muestra el error y permite reintentar', (tester) async {
    final repo = _FakeRepo(const [], failure: const NetworkFailure('Sin conexión'));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
