import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/domain/entities/category_entity.dart';
import 'package:appecommerce/presentation/pages/categories_page.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';

import 'support/fakes.dart';

TestEnv _env() => TestEnv(catalog: [
      product(1, 'Driver 400W'),
      product(2, 'Cable RCA', categoryId: 2),
    ]);

Future<TestEnv> _open(WidgetTester tester, [TestEnv? given]) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = given ?? _env();
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text('Categorías'),
  ));
  await tester.pumpAndSettle();
  return env;
}

NavigationBar _bar(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar));

void main() {
  group('Barra inferior', () {
    testWidgets('tiene cinco pestañas, con Categorías entre Tienda y Cuenta',
        (tester) async {
      await _open(tester);

      final labels = [
        for (final d in _bar(tester).destinations) (d as NavigationDestination).label,
      ];
      expect(labels, ['Inicio', 'Tienda', 'Categorías', 'Cuenta', 'Más']);
      expect(_bar(tester).selectedIndex, 2);
    });

    testWidgets('Cuenta y Más siguen funcionando con sus nuevos lugares',
        (tester) async {
      await _open(tester);

      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      expect(_bar(tester).selectedIndex, 3);

      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();
      expect(_bar(tester).selectedIndex, 4);
      expect(find.text('Consultar un reclamo'), findsOneWidget);
    });
  });

  group('Pestaña Categorías', () {
    testWidgets('lista las categorías con su título, búsqueda y carrito',
        (tester) async {
      await _open(tester);

      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Categorías')),
        findsOneWidget,
      );
      expect(find.byTooltip('Buscar'), findsOneWidget);
      expect(find.byTooltip('Carrito'), findsOneWidget);
      // Sin logo ni WhatsApp: barra blanca.
      expect(find.byTooltip('Ayuda'), findsNothing);
      expect(tester.widget<AppBar>(find.byType(AppBar)).backgroundColor, Colors.white);

      expect(find.byKey(const Key('category-all')), findsOneWidget);
      expect(find.byKey(const Key('category-1')), findsOneWidget);
      expect(find.byKey(const Key('category-2')), findsOneWidget);
      expect(find.text('Driver'), findsOneWidget);
      expect(find.text('RCA'), findsOneWidget);
    });

    testWidgets('tocar una categoría abre la tienda con sus productos',
        (tester) async {
      final env = await _open(tester);

      await tester.tap(find.byKey(const Key('category-2')));
      await tester.pumpAndSettle();

      expect(_bar(tester).selectedIndex, 1);
      final provider = tester
          .element(find.byType(NavigationBar))
          .read<ProductsProvider>();
      expect(provider.selectedCategoryId, 2);
      expect(env.products.lastCategoryId, 2);
      expect(find.text('Cable RCA'), findsOneWidget);
    });

    testWidgets('"Todos los productos" abre la tienda sin categoría',
        (tester) async {
      await _open(tester);
      final provider = tester
          .element(find.byType(NavigationBar))
          .read<ProductsProvider>();
      await provider.selectCategory(2);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category-all')));
      await tester.pumpAndSettle();

      expect(_bar(tester).selectedIndex, 1);
      expect(provider.selectedCategoryId, isNull);
    });

    testWidgets('la lupa abre el buscador y buscar lleva a la tienda',
        (tester) async {
      await _open(tester);

      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('search-field')), 'cable');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(_bar(tester).selectedIndex, 1);
      expect(
        tester.element(find.byType(NavigationBar)).read<ProductsProvider>().query,
        'cable',
      );
    });

    testWidgets('el carrito abre el carrito', (tester) async {
      await _open(tester);

      await tester.tap(find.byTooltip('Carrito'));
      await tester.pumpAndSettle();

      expect(find.text('Mi carrito'), findsOneWidget);
    });
  });

  group('Qué categorías se muestran', () {
    const withProducts = CategoryEntity(id: 1, name: 'DRIVER', productsCount: 9);
    const empty = CategoryEntity(id: 2, name: 'OBSEQUIO', productsCount: 0);
    const noCount = CategoryEntity(id: 3, name: 'RCA');

    test('si hay cantidades, se ocultan las categorías sin productos', () {
      expect(CategoriesPage.visible([withProducts, empty]), [withProducts]);
    });

    test('si el servidor no manda cantidades, se muestran todas', () {
      expect(CategoriesPage.visible([noCount, empty]), [noCount, empty]);
    });

    test('sin categorías no hay nada', () {
      expect(CategoriesPage.visible(const []), isEmpty);
    });
  });
}
