import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/domain/entities/product_filters.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';
import 'package:appecommerce/theme/app_theme.dart';

import 'package:appecommerce/presentation/widgets/main_nav_bar.dart';

import 'support/fakes.dart';

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(MainNavBar, skipOffstage: false));

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
    tester.widget<MainNavBar>(find.byType(MainNavBar)).selectedIndex;

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
      // Aunque el navbar de la empresa sea negro, las fichas son rojas.
      await pumpChips(tester, const Color(0xFF000000));

      expect(labelColor(tester, 'Cables'), const Color(0xFF26262B));
      expect(labelColor(tester, 'Todo'), Colors.white);
    });

    testWidgets('el color del navbar no cambia el de las fichas', (tester) async {
      await pumpChips(tester, const Color(0xFFFFEB3B));

      expect(labelColor(tester, 'Todo'), Colors.white);
      final theme = Theme.of(tester.element(find.byType(RawChip).first));
      expect(theme.chipTheme.selectedColor, AppTheme.primary);
    });

    testWidgets('la elegida se rellena de rojo y sin check', (tester) async {
      await pumpChips(tester, const Color(0xFF000000));

      final chip = tester.widget<RawChip>(find.byType(RawChip).first);
      expect(chip.showCheckmark, isFalse);
      final theme = Theme.of(tester.element(find.byType(RawChip).first));
      expect(theme.chipTheme.selectedColor, const Color(0xFF9B1C1C));
    });
  });

  group('Buscador del inicio', () {
    /// Toca el campo de la barra: abre el buscador a pantalla completa.
    Future<void> openSearchPage(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('home-search')));
      await tester.pumpAndSettle();
    }

    testWidgets('al enviar abre la tienda con los resultados y el texto escrito',
        (tester) async {
      await _openHome(tester);
      expect(find.byKey(const Key('home-search')), findsOneWidget);

      await openSearchPage(tester);
      await tester.enterText(find.byKey(const Key('search-field')), 'rca');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(_selectedTab(tester), 1);
      expect(_context(tester).read<ProductsProvider>().query, 'rca');
      // El buscador de la tienda muestra lo buscado.
      expect(find.widgetWithText(TextField, 'rca'), findsOneWidget);
      expect(find.text('1 producto'), findsOneWidget);
    });

    testWidgets('busca en todo el catálogo: quita la categoría y los filtros de antes',
        (tester) async {
      await _openHome(tester);
      final provider = _context(tester).read<ProductsProvider>();
      await provider.selectCategory(2);
      await provider.applyFilters(const ProductFilters(brandIds: {25}));
      await tester.pumpAndSettle();

      await openSearchPage(tester);
      await tester.enterText(find.byKey(const Key('search-field')), 'parlante');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(provider.selectedCategoryId, isNull);
      expect(provider.filters, ProductFilters.none);
      expect(provider.query, 'parlante');
    });

    testWidgets('con el campo vacío y sin categoría no hace nada', (tester) async {
      await _openHome(tester);

      await openSearchPage(tester);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Sigue en el buscador, sin abrir la tienda.
      expect(find.byKey(const Key('search-field')), findsOneWidget);
      final bar = tester.widget<MainNavBar>(
        find.byType(MainNavBar, skipOffstage: false),
      );
      expect(bar.selectedIndex, 0);
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
