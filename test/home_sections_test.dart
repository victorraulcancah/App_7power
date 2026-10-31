import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/domain/entities/product_filters.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';
import 'package:appecommerce/theme/app_theme.dart';

import 'support/fakes.dart';

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar, skipOffstage: false));

/// Portada en una pantalla alta, para que las secciones queden construidas.
Future<TestEnv> _openHome(
  WidgetTester tester, {
  List<BrandEntity> brands = const [],
}) async {
  tester.view.physicalSize = const Size(800, 3400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = TestEnv(catalog: [
    product(1, 'Driver 400W'),
    product(2, 'Cable RCA', categoryId: 2),
    product(3, 'Parlante 6x9'),
  ]);
  env.products.brands = brands;
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  return env;
}

int _selectedTab(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  group('Diseño de las pestañas', () {
    Future<void> pumpChips(WidgetTester tester, Color brand) =>
        tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(brand),
          home: const Scaffold(
            body: Row(children: [
              ChoiceChip(label: Text('Todo'), selected: true),
              ChoiceChip(label: Text('Cables'), selected: false),
            ]),
          ),
        ));

    Color? labelColor(WidgetTester tester, String text) =>
        DefaultTextStyle.of(tester.element(find.text(text))).style.color;

    testWidgets('el texto se lee: oscuro en las demás y claro sobre la elegida',
        (tester) async {
      // Marca negra (la que usa 7power): la elegida es negra con texto blanco.
      await pumpChips(tester, const Color(0xFF000000));

      expect(labelColor(tester, 'Cables'), const Color(0xFF26262B));
      expect(labelColor(tester, 'Todo'), Colors.white);
    });

    testWidgets('con una marca clara el texto de la elegida es oscuro',
        (tester) async {
      await pumpChips(tester, const Color(0xFFFFEB3B));

      expect(labelColor(tester, 'Todo'), Colors.black);
      expect(labelColor(tester, 'Cables'), const Color(0xFF26262B));
    });

    testWidgets('la elegida se rellena con el color de la marca y sin check',
        (tester) async {
      await pumpChips(tester, const Color(0xFF9B1C1C));

      final chip = tester.widget<RawChip>(find.byType(RawChip).first);
      expect(chip.showCheckmark, isFalse);
      final theme = Theme.of(tester.element(find.byType(RawChip).first));
      expect(theme.chipTheme.selectedColor, const Color(0xFF9B1C1C));
    });
  });

  group('Recomendado para ti', () {
    testWidgets('muestra pestañas por categoría y la cuadrícula de productos',
        (tester) async {
      await _openHome(tester);

      expect(find.text('Recomendado para ti'), findsOneWidget);
      expect(find.byKey(const Key('recommended-all')), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Todo'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'RCA'), findsOneWidget);
      // "Todo" arranca elegida y trae los productos de todas las categorías.
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('recommended-all'))).selected,
          isTrue);
      expect(find.text('Driver 400W'), findsOneWidget);
      expect(find.text('Cable RCA'), findsOneWidget);
      expect(find.text('Ver más productos'), findsOneWidget);
    });

    testWidgets('al elegir una categoría muestra solo sus productos',
        (tester) async {
      final env = await _openHome(tester);

      await tester.tap(find.byKey(const Key('recommended-2')));
      await tester.pumpAndSettle();

      expect(env.products.lastCategoryId, 2);
      expect(find.text('Cable RCA'), findsOneWidget);
      expect(find.text('Driver 400W'), findsNothing);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('recommended-2'))).selected,
          isTrue);

      // Volver a "Todo" trae otra vez todo.
      await tester.tap(find.byKey(const Key('recommended-all')));
      await tester.pumpAndSettle();
      expect(env.products.lastCategoryId, isNull);
      expect(find.text('Driver 400W'), findsOneWidget);
    });

    testWidgets('"Ver más productos" abre la tienda con la categoría elegida',
        (tester) async {
      await _openHome(tester);
      await tester.tap(find.byKey(const Key('recommended-2')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver más productos'));
      await tester.pumpAndSettle();

      expect(_selectedTab(tester), 1);
      expect(_context(tester).read<ProductsProvider>().selectedCategoryId, 2);
    });
  });

  group('Comprar por marcas', () {
    const brands = [
      BrandEntity(id: 25, name: '7POWER', productsCount: 404, inShowcase: true, showcaseOrder: 3),
      BrandEntity(id: 29, name: 'DS18', productsCount: 7, inShowcase: true, showcaseOrder: 6),
    ];

    testWidgets('muestra las marcas y al tocar una abre la tienda filtrada',
        (tester) async {
      final env = await _openHome(tester, brands: brands);

      expect(find.text('Comprar por marcas'), findsOneWidget);
      expect(find.byKey(const Key('home-brand-25')), findsOneWidget);
      expect(find.byKey(const Key('home-brand-29')), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-brand-29')));
      await tester.pumpAndSettle();

      expect(env.products.lastFilters.brandIds, {29});
      expect(_selectedTab(tester), 1);
    });

    testWidgets('"Ver todas" abre la lista completa de marcas', (tester) async {
      await _openHome(tester, brands: brands);

      await tester.tap(find.text('Ver todas'));
      await tester.pumpAndSettle();

      expect(find.text('Marcas'), findsOneWidget);
      expect(find.text('404 productos'), findsOneWidget);
    });

    testWidgets('sin marcas no se muestra la sección', (tester) async {
      await _openHome(tester);

      expect(find.text('Comprar por marcas'), findsNothing);
    });

    testWidgets('solo caben 12 marcas en la portada', (tester) async {
      await _openHome(tester, brands: [
        for (var i = 1; i <= 15; i++)
          BrandEntity(id: i, name: 'MARCA $i', productsCount: 5, inShowcase: true, showcaseOrder: i),
      ]);

      expect(find.byKey(const Key('home-brand-1')), findsOneWidget);
      expect(find.byKey(const Key('home-brand-15')), findsNothing);
    });
  });
}
