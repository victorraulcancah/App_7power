import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/errors/failures.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/product_remote_datasource.dart';
import 'package:appecommerce/domain/entities/product_filters.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';

import 'package:appecommerce/presentation/widgets/main_nav_bar.dart';

import 'support/fakes.dart';

const _sevenPower = BrandEntity(id: 25, name: '7POWER', productsCount: 404);
const _blaupunkt = BrandEntity(id: 45, name: 'BLAUPUNKT', productsCount: 12);
const _jbl = BrandEntity(id: 50, name: 'JBL', productsCount: 7);

/// Catálogo con dos categorías: DRIVER (1) y RCA (2). Solo BLAUPUNKT tiene
/// productos en RCA, así que 7POWER + RCA no da resultados.
TestEnv _env() {
  final env = TestEnv(catalog: [
    product(1, 'Driver Bosch', price: 100, stock: 3, brand: '7POWER'),
    product(2, 'Cable RCA', price: 30, stock: 50, categoryId: 2, brand: 'BLAUPUNKT'),
    product(3, 'Amplificador', price: 500, stock: 8, brand: '7POWER'),
    product(4, 'Parlante', price: 200, stock: 20, brand: 'JBL'),
  ]);
  env.products.brands = const [_sevenPower, _blaupunkt, _jbl];
  // Lo que respondería el servidor con `categoria_id`: cantidades en la categoría.
  env.products.brandsByCategory[2] = const [
    BrandEntity(id: 45, name: 'BLAUPUNKT', productsCount: 1),
  ];
  env.products.brandsByCategory[1] = const [
    BrandEntity(id: 25, name: '7POWER', productsCount: 2),
    BrandEntity(id: 50, name: 'JBL', productsCount: 1),
  ];
  return env;
}

Future<TestEnv> _openShop(WidgetTester tester, [TestEnv? given]) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = given ?? _env();
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Tienda'));
  await tester.pumpAndSettle();
  return env;
}

ProductsProvider _provider(WidgetTester tester) => tester
    .element(find.byType(MainNavBar, skipOffstage: false))
    .read<ProductsProvider>();

Future<void> _chooseCategory(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await tester.pumpAndSettle();
}

Future<void> _openBrandPicker(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtros'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('filter-brands')));
  await tester.pumpAndSettle();
}

Future<void> _applyBrands(WidgetTester tester, List<String> names) async {
  await _openBrandPicker(tester);
  for (final name in names) {
    await tester.tap(find.widgetWithText(CheckboxListTile, name));
    await tester.pump();
  }
  await tester.tap(find.textContaining('Listo'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Aplicar'));
  await tester.pumpAndSettle();
}

void main() {
  group('Marcas de una categoría (datos)', () {
    late Uri requested;

    ProductRemoteDataSourceImpl source() => ProductRemoteDataSourceImpl(ApiClient(
          client: MockClient((r) async {
            requested = r.url;
            return http.Response.bytes(
              utf8.encode(jsonEncode([
                {'id': 45, 'nombre': 'BLAUPUNKT', 'productos_count': 1},
                {'id': 99, 'nombre': 'VACIA', 'productos_count': 0},
              ])),
              200,
            );
          }),
          isConnected: () async => true,
        ));

    test('con categoría pide solo las de ella con categoria_id', () async {
      final brands = await source().getBrands(categoryId: 2);

      expect(requested.queryParameters, {'categoria_id': '2'});
      // La que no tiene productos en la categoría no se ofrece.
      expect(brands.map((b) => b.name), ['BLAUPUNKT']);
      expect(brands.single.productsCount, 1);
    });

    test('sin categoría pide la lista completa, sin parámetros', () async {
      await source().getBrands();

      expect(requested.queryParameters, isEmpty);
    });
  });

  group('Marcas de una categoría (pantalla)', () {
    testWidgets('con una categoría elegida, el selector solo ofrece sus marcas',
        (tester) async {
      final env = await _openShop(tester);

      await _chooseCategory(tester, 'RCA');
      // La carga inicial pide todas (null); al elegir la categoría, las de ella.
      expect(env.products.brandRequests, [null, 2]);
      await _openBrandPicker(tester);

      expect(find.widgetWithText(CheckboxListTile, 'BLAUPUNKT'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, '7POWER'), findsNothing);
      expect(find.widgetWithText(CheckboxListTile, 'JBL'), findsNothing);
      // La cantidad es la de la categoría, no la global (12).
      expect(find.text('1'), findsWidgets);
      expect(find.text('12'), findsNothing);
    });

    testWidgets('la hoja dice en qué categoría están las marcas', (tester) async {
      await _openShop(tester);
      await _chooseCategory(tester, 'RCA');

      await tester.tap(find.byTooltip('Filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Con productos en RCA'), findsOneWidget);
    });

    testWidgets('sin categoría vuelven todas las marcas', (tester) async {
      await _openShop(tester);
      await _chooseCategory(tester, 'RCA');
      await _chooseCategory(tester, 'Todos');

      await _openBrandPicker(tester);

      expect(find.widgetWithText(CheckboxListTile, '7POWER'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'BLAUPUNKT'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'JBL'), findsOneWidget);
      expect(find.text('Con productos en RCA'), findsNothing);
    });

    testWidgets('cambiar de categoría cambia las marcas', (tester) async {
      final env = await _openShop(tester);

      await _chooseCategory(tester, 'RCA');
      await _chooseCategory(tester, 'Driver');
      await _openBrandPicker(tester);

      expect(env.products.brandRequests, [null, 2, 1]);
      expect(find.widgetWithText(CheckboxListTile, '7POWER'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'JBL'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'BLAUPUNKT'), findsNothing);
    });

    testWidgets('una marca ya elegida se sigue viendo para poder soltarla',
        (tester) async {
      await _openShop(tester);
      await _applyBrands(tester, ['7POWER']);

      await _chooseCategory(tester, 'RCA');
      await _openBrandPicker(tester);

      final seven = find.widgetWithText(CheckboxListTile, '7POWER');
      expect(seven, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(seven).value, isTrue);
      expect(find.widgetWithText(CheckboxListTile, 'BLAUPUNKT'), findsOneWidget);
    });

    testWidgets('si no se pueden pedir las de la categoría, salen todas',
        (tester) async {
      final env = _env()..products.brandsFailure = const ServerFailure('sin red');
      await _openShop(tester, env);

      await _chooseCategory(tester, 'RCA');
      await _openBrandPicker(tester);

      expect(find.widgetWithText(CheckboxListTile, '7POWER'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'BLAUPUNKT'), findsOneWidget);
    });

    testWidgets('una respuesta tardía de otra categoría se ignora',
        (tester) async {
      await _openShop(tester);
      final provider = _provider(tester);

      await provider.selectCategory(2);
      await provider.selectCategory(null);
      await tester.pumpAndSettle();

      // Sin categoría, aunque llegue lo de la 2, se ofrecen todas.
      expect(provider.availableBrands.map((b) => b.name),
          ['7POWER', 'BLAUPUNKT', 'JBL']);
    });
  });

  group('Sin resultados', () {
    testWidgets('dice la combinación pedida y deja quitar los filtros',
        (tester) async {
      final env = await _openShop(tester);
      await _applyBrands(tester, ['7POWER']);
      await _chooseCategory(tester, 'RCA');

      expect(find.text('Sin productos'), findsOneWidget);
      expect(find.text('No hay productos con la combinación: 7POWER + RCA.'),
          findsOneWidget);
      expect(find.text('Quitar filtros'), findsOneWidget);
      expect(find.text('Ver todas las categorías'), findsOneWidget);

      await tester.tap(find.text('Quitar filtros'));
      await tester.pumpAndSettle();

      // La categoría se queda; la marca se fue y vuelve el producto de RCA.
      expect(env.products.lastFilters, ProductFilters.none);
      expect(env.products.lastCategoryId, 2);
      expect(find.text('Cable RCA'), findsOneWidget);
      expect(find.text('Sin productos'), findsNothing);
    });

    testWidgets('también deja soltar solo la categoría', (tester) async {
      final env = await _openShop(tester);
      await _applyBrands(tester, ['7POWER']);
      await _chooseCategory(tester, 'RCA');

      await tester.tap(find.text('Ver todas las categorías'));
      await tester.pumpAndSettle();

      // La marca se queda; sin categoría hay productos de 7POWER.
      expect(env.products.lastCategoryId, isNull);
      expect(env.products.lastFilters.brandIds, {25});
      expect(find.text('Driver Bosch'), findsOneWidget);
    });

    testWidgets('solo con categoría ofrece volver a todas', (tester) async {
      final env = _env();
      // Una categoría sin productos.
      env.products.products = [];
      await _openShop(tester, env);

      await _chooseCategory(tester, 'RCA');

      expect(find.text('No encontramos productos con RCA.'), findsOneWidget);
      expect(find.text('Quitar filtros'), findsNothing);
      expect(find.text('Ver todas las categorías'), findsOneWidget);
    });

    testWidgets('sin ningún filtro mantiene el mensaje de siempre',
        (tester) async {
      final env = _env()..products.products = [];
      await _openShop(tester, env);

      expect(find.text('No encontramos productos con ese filtro.'), findsOneWidget);
      expect(find.text('Quitar filtros'), findsNothing);
      expect(find.text('Ver todas las categorías'), findsNothing);
    });

    testWidgets('con una búsqueda la nombra', (tester) async {
      await _openShop(tester);

      await _provider(tester).search('zzz');
      await tester.pumpAndSettle();

      expect(find.text('No encontramos productos con "zzz".'), findsOneWidget);
    });
  });

  group('Topes del precio', () {
    testWidgets('el deslizador llega al producto más caro de todo el catálogo',
        (tester) async {
      final env = _env();
      env.products.priceBounds = true;
      await _openShop(tester, env);
      final provider = _provider(tester);

      expect(provider.priceMin, 30);
      expect(provider.priceMax, 500);

      // La categoría RCA solo tiene un producto de S/ 30: el resultado no da
      // rango, pero el deslizador sigue con los topes de todo el catálogo.
      await provider.selectCategory(2);
      await tester.pumpAndSettle();
      expect(provider.priceMin, 30);
      expect(provider.priceMax, 500);
      expect(provider.canFilterByPrice, isTrue);

      await provider.search('zzz');
      await tester.pumpAndSettle();
      expect(provider.priceMax, 500);
    });
  });

  group('Búsqueda activa', () {
    testWidgets('las marcas del filtro son las que tienen resultados', (tester) async {
      final env = _env();
      await _openShop(tester, env);

      await _provider(tester).search('amplificador');
      await tester.pumpAndSettle();

      // Solo 7POWER tiene un "Amplificador": elegir JBL daría "Sin productos".
      expect(_provider(tester).availableBrands.map((b) => b.name), ['7POWER']);
      expect(_provider(tester).availableBrands.single.productsCount, 1);

      await _provider(tester).clearSearch();
      await tester.pumpAndSettle();
      expect(_provider(tester).availableBrands.map((b) => b.name),
          ['7POWER', 'BLAUPUNKT', 'JBL']);
    });

    testWidgets('la búsqueda se ve como filtro y se puede quitar', (tester) async {
      await _openShop(tester);
      await _provider(tester).search('amplificador');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, '"amplificador"'), findsOneWidget);
      expect(find.text('Limpiar todo'), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.widgetWithText(InputChip, '"amplificador"'),
        matching: find.byType(Icon),
      ));
      await tester.pumpAndSettle();

      expect(_provider(tester).query, isEmpty);
      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Parlante'), findsOneWidget);
    });

    testWidgets('"Limpiar todo" quita también la búsqueda y la categoría',
        (tester) async {
      final env = await _openShop(tester);
      await _chooseCategory(tester, 'RCA');
      await _provider(tester).search('cable');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Limpiar todo'));
      await tester.pumpAndSettle();

      expect(_provider(tester).query, isEmpty);
      expect(_provider(tester).selectedCategoryId, isNull);
      expect(env.products.lastCategoryId, isNull);
      expect(find.text('Parlante'), findsOneWidget);
    });
  });
}
