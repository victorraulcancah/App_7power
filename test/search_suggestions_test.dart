import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/product_remote_datasource.dart';
import 'package:appecommerce/data/models/product_model.dart';
import 'package:appecommerce/domain/usecases/search_products_usecase.dart';
import 'package:appecommerce/presentation/providers/product_search_provider.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';

import 'package:appecommerce/presentation/widgets/main_nav_bar.dart';

import 'support/fakes.dart';

TestEnv _env() => TestEnv(catalog: [
      product(1, 'Driver 400W', price: 120, stock: 5, brand: '7POWER'),
      product(2, 'Cable RCA', price: 30, stock: 9, categoryId: 2, brand: 'BLAUPUNKT'),
      product(3, 'Parlante 6x9', price: 80, stock: 0, brand: 'JBL'),
      product(4, 'Subwoofer 12', price: 300, stock: 3, brand: '7POWER'),
    ]);

SearchProductsUseCase _useCase(TestEnv env) => SearchProductsUseCase(env.products);

Future<TestEnv> _openSearch(WidgetTester tester, [TestEnv? given]) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = given ?? _env();
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('home-search')));
  await tester.pumpAndSettle();
  return env;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('search-field')), text);
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pumpAndSettle();
}

void main() {
  group('Datos', () {
    late Uri requested;

    ProductRemoteDataSourceImpl source() => ProductRemoteDataSourceImpl(ApiClient(
          client: MockClient((r) async {
            requested = r.url;
            return http.Response.bytes(
              utf8.encode(jsonEncode([
                {
                  'id': 1049,
                  'nombre': "4'' TWEETER BALA NEODIMIO",
                  'precio': 25.5,
                  'precio_visible': true,
                  'moneda': 's',
                  'categoria': 'TWEETER',
                  'categoria_id': 65,
                  'marca': '7POWER',
                  'codigo_producto': 'ND4.4',
                  'stock': 386,
                  'imagen_url': 'https://api.7power.pe/storage/productos/a.jpg',
                },
                {
                  'id': 648,
                  'nombre': 'AMPLIFICADOR',
                  'precio': 0,
                  'moneda': 's',
                  'marca': 'PIONEER',
                  'codigo_producto': 'GM-D9705',
                  'stock': 4,
                  'imagen_url': null,
                },
              ])),
              200,
            );
          }),
          isConnected: () async => true,
        ));

    test('pide /productos/buscar con el texto y la categoría', () async {
      await source().searchProducts('700', categoryId: 65);

      expect(requested.path, endsWith('/productos/buscar'));
      expect(requested.queryParameters, {'q': '700', 'categoria': '65'});
    });

    test('sin categoría solo manda el texto', () async {
      await source().searchProducts('jbl');

      expect(requested.queryParameters, {'q': 'jbl'});
    });

    test('lee código, marca, imagen y precio de cada sugerencia', () async {
      final results = await source().searchProducts('700');

      expect(results, hasLength(2));
      expect(results.first.code, 'ND4.4');
      expect(results.first.brand, '7POWER');
      expect(results.first.categoryId, 65);
      expect(results.first.imageUrl, contains('a.jpg'));
      expect(results.first.price, 25.5);
      expect(results.first.stock, 386);
      expect(results.last.imageUrl, isNull);
    });

    test('ProductModel.fromSuggestionJson tolera datos que faltan', () {
      final p = ProductModel.fromSuggestionJson({'id': 1, 'nombre': 'X'});

      expect(p.code, isNull);
      expect(p.brand, isNull);
      expect(p.stock, 0);
      expect(p.priceVisible, isTrue);
    });
  });

  group('Proveedor', () {
    test('menos de 2 letras y sin categoría no busca', () async {
      final env = _env();
      final search = ProductSearchProvider(
        searchProductsUseCase: _useCase(env),
        debounce: const Duration(milliseconds: 5),
      );

      search.update('d');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(search.status, SearchStatus.idle);
      expect(env.products.searchRequests, isEmpty);
      search.dispose();
    });

    test('espera la pausa y busca una sola vez con lo último escrito', () async {
      final env = _env();
      final search = ProductSearchProvider(
        searchProductsUseCase: _useCase(env),
        debounce: const Duration(milliseconds: 40),
      );

      search.update('dr');
      search.update('dri');
      search.update('driv');
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(env.products.searchRequests, [('driv', null)]);
      expect(search.status, SearchStatus.loaded);
      expect(search.results.single.name, 'Driver 400W');
      search.dispose();
    });

    test('solo con categoría también busca', () async {
      final env = _env();
      final search = ProductSearchProvider(
        searchProductsUseCase: _useCase(env),
        debounce: const Duration(milliseconds: 5),
      );

      search.update('', categoryId: 2);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(search.results.single.name, 'Cable RCA');
      search.dispose();
    });

    test('borrar el texto vacía la lista y descarta lo que venía en camino',
        () async {
      final env = _env();
      final search = ProductSearchProvider(
        searchProductsUseCase: _useCase(env),
        debounce: const Duration(milliseconds: 5),
      );

      search.update('driver');
      search.update('');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(search.status, SearchStatus.idle);
      expect(search.results, isEmpty);
      search.dispose();
    });

    test('un fallo queda como error, sin lista', () async {
      final env = _env()..products.searchFails = true;
      final search = ProductSearchProvider(
        searchProductsUseCase: _useCase(env),
        debounce: const Duration(milliseconds: 5),
      );

      search.update('driver');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(search.status, SearchStatus.error);
      expect(search.results, isEmpty);
      search.dispose();
    });
  });

  group('Pantalla del buscador', () {
    testWidgets('tocar la barra abre el buscador con el selector de categoría',
        (tester) async {
      await _openSearch(tester);

      expect(find.byKey(const Key('search-field')), findsOneWidget);
      expect(find.byKey(const Key('search-category')), findsOneWidget);
      expect(find.text('Todas las categorías'), findsOneWidget);
      expect(find.textContaining('Escribe al menos 2 letras'), findsOneWidget);
    });

    testWidgets('al escribir sale la lista con foto, marca, nombre, código y precio',
        (tester) async {
      await _openSearch(tester);

      await _type(tester, 'driver');

      expect(find.text('7POWER'), findsOneWidget);
      expect(find.text('Driver 400W'), findsOneWidget);
      expect(find.text('S/ 120.00'), findsOneWidget);
      expect(find.text('Ver todos los resultados de «driver»'), findsOneWidget);
    });

    testWidgets('también busca por código y por marca', (tester) async {
      final env = TestEnv(catalog: [
        const ProductModel(
          id: 1,
          name: 'Driver 400W',
          price: 10,
          stock: 5,
          brand: '7POWER',
          code: 'DRV2',
        ),
        product(2, 'Cable', brand: 'JBL'),
      ]);
      await _openSearch(tester, env);

      await _type(tester, 'drv2');
      expect(find.text('Driver 400W'), findsOneWidget);
      expect(find.text('DRV2'), findsOneWidget);

      await _type(tester, 'jbl');
      expect(find.text('Cable'), findsOneWidget);
      expect(find.text('Driver 400W'), findsNothing);
    });

    testWidgets('un agotado se marca como tal en lugar del precio',
        (tester) async {
      await _openSearch(tester);

      await _type(tester, 'parlante');

      expect(find.text('Parlante 6x9'), findsOneWidget);
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('S/ 80.00'), findsNothing);
    });

    testWidgets('elegir una categoría filtra las sugerencias', (tester) async {
      final env = await _openSearch(tester);

      await tester.tap(find.byKey(const Key('search-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RCA').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(env.products.searchRequests.last, ('', 2));
      expect(find.text('Cable RCA'), findsOneWidget);
      expect(find.text('Driver 400W'), findsNothing);
      expect(find.text('Ver todos los productos de la categoría'), findsOneWidget);
    });

    testWidgets('texto y categoría juntos se piden juntos', (tester) async {
      final env = await _openSearch(tester);

      await _type(tester, 'cable');
      await tester.tap(find.byKey(const Key('search-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RCA').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(env.products.searchRequests.last, ('cable', 2));
    });

    testWidgets('sin coincidencias lo dice', (tester) async {
      await _openSearch(tester);

      await _type(tester, 'zzzz');

      expect(find.text('No encontramos productos para «zzzz».'), findsOneWidget);
      expect(find.byKey(const Key('search-all')), findsNothing);
    });

    testWidgets('si falla, ofrece reintentar', (tester) async {
      final env = _env()..products.searchFails = true;
      await _openSearch(tester, env);

      await _type(tester, 'driver');
      expect(find.textContaining('No se pudo buscar'), findsOneWidget);

      env.products.searchFails = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Driver 400W'), findsOneWidget);
    });

    testWidgets('tocar una sugerencia abre el producto', (tester) async {
      await _openSearch(tester);
      await _type(tester, 'driver');

      await tester.tap(find.text('Driver 400W'));
      await tester.pumpAndSettle();

      expect(find.text('Producto'), findsOneWidget);
    });

    testWidgets('"Ver todos" abre la tienda con el texto y la categoría',
        (tester) async {
      await _openSearch(tester);
      await _type(tester, 'cable');
      await tester.tap(find.byKey(const Key('search-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RCA').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search-all')));
      await tester.pumpAndSettle();

      final provider = tester
          .element(find.byType(MainNavBar, skipOffstage: false))
          .read<ProductsProvider>();
      expect(provider.query, 'cable');
      expect(provider.selectedCategoryId, 2);
      expect(
        tester.widget<MainNavBar>(find.byType(MainNavBar)).selectedIndex,
        1,
      );
    });

    testWidgets('con solo una categoría, la tecla de buscar abre la tienda en ella',
        (tester) async {
      await _openSearch(tester);
      await tester.tap(find.byKey(const Key('search-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RCA').last);
      await tester.pumpAndSettle();

      // Se vuelve al campo (el selector le quitó el foco) y se pulsa buscar.
      await tester.tap(find.byKey(const Key('search-field')));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      final provider = tester
          .element(find.byType(MainNavBar, skipOffstage: false))
          .read<ProductsProvider>();
      expect(provider.selectedCategoryId, 2);
      expect(provider.query, '');
    });

    testWidgets('borrar con la X limpia la lista', (tester) async {
      await _openSearch(tester);
      await _type(tester, 'driver');
      expect(find.text('Driver 400W'), findsOneWidget);

      await tester.tap(find.byTooltip('Borrar'));
      await tester.pumpAndSettle();

      expect(find.text('Driver 400W'), findsNothing);
      expect(find.textContaining('Escribe al menos 2 letras'), findsOneWidget);
    });

    testWidgets('al volver a abrirlo parte de cero', (tester) async {
      await _openSearch(tester);
      await _type(tester, 'driver');

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-search')));
      await tester.pumpAndSettle();

      expect(find.text('Driver 400W'), findsNothing);
      expect(find.textContaining('Escribe al menos 2 letras'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('search-field'))).controller!.text,
        isEmpty,
      );
    });
  });
}
