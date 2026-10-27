import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/product_remote_datasource.dart';
import 'package:appecommerce/domain/entities/product_filters.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';

import 'support/fakes.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar, skipOffstage: false));

TestEnv _env({bool priceBounds = false}) {
  final env = TestEnv(catalog: [
    product(1, 'Driver Bosch', price: 100, stock: 3, brand: '7POWER'),
    product(2, 'Cable RCA', price: 30, stock: 50, categoryId: 2, brand: 'BLAUPUNKT'),
    product(3, 'Amplificador', price: 500, stock: 8, brand: '7POWER'),
    product(4, 'Parlante', price: 200, stock: 20, brand: 'JBL'),
  ]);
  env.products.brands = const [
    BrandEntity(id: 25, name: '7POWER', productsCount: 404),
    BrandEntity(id: 45, name: 'BLAUPUNKT', productsCount: 12),
    BrandEntity(id: 50, name: 'JBL', productsCount: 7),
  ];
  env.products.priceBounds = priceBounds;
  return env;
}

Future<void> _openShop(WidgetTester tester, TestEnv env) async {
  _tall(tester);
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tienda'));
  await tester.pumpAndSettle();
}

Future<void> _openFilters(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtros'));
  await tester.pumpAndSettle();
}

void main() {
  group('ProductFilters', () {
    test('cuenta los filtros en uso', () {
      expect(ProductFilters.none.activeCount, 0);
      expect(ProductFilters.none.isActive, isFalse);

      const f = ProductFilters(
        brandIds: {1, 2},
        minPrice: 10,
        sort: ProductSort.nameAsc,
      );
      // Las marcas cuentan como un solo filtro, aunque sean varias.
      expect(f.activeCount, 3);
      expect(f.hasPriceRange, isTrue);
    });

    test('dos filtros iguales son iguales aunque las marcas estén en otro orden',
        () {
      expect(
        const ProductFilters(brandIds: {1, 2}, maxPrice: 50),
        ProductFilters(brandIds: {2, 1}, maxPrice: 50),
      );
      expect(
        const ProductFilters(brandIds: {1}),
        isNot(const ProductFilters(brandIds: {1, 2})),
      );
    });

    test('quitar el precio deja lo demás', () {
      const f = ProductFilters(
        brandIds: {5},
        minPrice: 10,
        maxPrice: 90,
        sort: ProductSort.stockDesc,
      );

      final cleared = f.copyWith(clearPrice: true);

      expect(cleared.hasPriceRange, isFalse);
      expect(cleared.brandIds, {5});
      expect(cleared.sort, ProductSort.stockDesc);
    });

    test('no se ofrece ordenar por precio (el backend no lo aplica)', () {
      expect(ProductSort.values.map((s) => s.apiValue),
          [null, 'name_asc', 'popularity_desc']);
    });
  });

  group('ProductRemoteDataSource', () {
    late Uri requested;

    ProductRemoteDataSourceImpl source(Map<String, dynamic> body) =>
        ProductRemoteDataSourceImpl(ApiClient(
          client: MockClient((r) async {
            requested = r.url;
            return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
          }),
          isConnected: () async => true,
        ));

    const page = {
      'productos': <Map<String, dynamic>>[],
      'pagination': {'current_page': 1, 'last_page': 1, 'total': 0},
    };

    test('manda marcas, precio y orden como los espera el backend', () async {
      final remote = source({...page, 'precio_min': 18.0, 'precio_max': 2786});

      final result = await remote.getProducts(
        page: 2,
        categoryId: 46,
        filters: const ProductFilters(
          brandIds: {45, 25},
          minPrice: 50,
          maxPrice: 199.5,
          sort: ProductSort.nameAsc,
        ),
      );

      final q = requested.queryParameters;
      expect(q['page'], '2');
      expect(q['categoria'], '46');
      expect(q['brandIds'], '25,45');
      expect(q['minPrice'], '50');
      expect(q['maxPrice'], '199.5');
      expect(q['sortBy'], 'name_asc');
      expect(result.priceMin, 18);
      expect(result.priceMax, 2786);
    });

    test('sin filtros no manda parámetros de más', () async {
      final remote = source(page);

      final result = await remote.getProducts(page: 1);

      final keys = requested.queryParameters.keys.toSet();
      expect(keys, {'page'});
      // Sin lista de precios el backend no manda los topes.
      expect(result.priceMin, isNull);
      expect(result.priceMax, isNull);
    });

    test('las marcas sin productos no se ofrecen', () async {
      final remote = source({}); // no se usa
      final brands = ProductRemoteDataSourceImpl(ApiClient(
        client: MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode([
                {'id': 25, 'nombre': '7POWER', 'productos_count': 404},
                {'id': 99, 'nombre': 'VACIA', 'productos_count': 0},
              ])),
              200,
            )),
        isConnected: () async => true,
      ));
      expect(remote, isNotNull);

      final result = await brands.getBrands();

      expect(result.map((b) => b.name), ['7POWER']);
      expect(result.single.productsCount, 404);
    });
  });

  group('Pantalla de filtros', () {
    testWidgets('el botón abre la hoja con orden y marcas', (tester) async {
      await _openShop(tester, _env());

      await _openFilters(tester);

      expect(find.text('Filtros'), findsWidgets);
      for (final label in ['Relevancia', 'Nombre (A-Z)', 'Mayor stock']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('7POWER (404)'), findsOneWidget);
      expect(find.text('BLAUPUNKT (12)'), findsOneWidget);
      // Sin lista de precios no hay deslizador.
      expect(find.byType(RangeSlider), findsNothing);
      expect(find.text('Ver productos'), findsOneWidget);
    });

    testWidgets('el rango de precio aparece cuando el cliente tiene lista',
        (tester) async {
      await _openShop(tester, _env(priceBounds: true));

      await _openFilters(tester);

      expect(find.byType(RangeSlider), findsOneWidget);
      expect(find.text('S/ 30.00 – S/ 500.00'), findsOneWidget);
    });

    testWidgets('elegir una marca filtra y muestra el filtro activo',
        (tester) async {
      final env = _env();
      await _openShop(tester, env);
      expect(find.text('4 productos'), findsOneWidget);

      await _openFilters(tester);
      await tester.tap(find.text('7POWER (404)'));
      await tester.pump();
      expect(find.text('Aplicar (1)'), findsOneWidget);
      await tester.tap(find.text('Aplicar (1)'));
      await tester.pumpAndSettle();

      expect(env.products.lastFilters.brandIds, {25});
      expect(find.text('2 productos'), findsOneWidget);
      // El filtro queda visible, con su nombre, y con insignia en el botón.
      expect(find.widgetWithText(InputChip, '7POWER'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Limpiar todo'), findsOneWidget);
    });

    testWidgets('varias marcas se piden juntas', (tester) async {
      final env = _env();
      await _openShop(tester, env);

      await _openFilters(tester);
      await tester.tap(find.text('7POWER (404)'));
      await tester.tap(find.text('JBL (7)'));
      await tester.pump();
      await tester.tap(find.text('Aplicar (1)'));
      await tester.pumpAndSettle();

      expect(env.products.lastFilters.brandIds, {25, 50});
      expect(find.text('3 productos'), findsOneWidget);
    });

    testWidgets('ordenar por nombre manda el orden y reordena', (tester) async {
      final env = _env();
      await _openShop(tester, env);

      await _openFilters(tester);
      await tester.tap(find.text('Nombre (A-Z)'));
      await tester.pump();
      await tester.tap(find.text('Aplicar (1)'));
      await tester.pumpAndSettle();

      expect(env.products.lastFilters.sort, ProductSort.nameAsc);
      final names = _context(tester)
          .read<ProductsProvider>()
          .products
          .map((p) => p.name)
          .toList();
      expect(names, [...names]..sort());
    });

    testWidgets('quitar un filtro con su "x" vuelve a cargar sin él',
        (tester) async {
      final env = _env();
      await _openShop(tester, env);
      await _openFilters(tester);
      await tester.tap(find.text('JBL (7)'));
      await tester.pump();
      await tester.tap(find.text('Aplicar (1)'));
      await tester.pumpAndSettle();
      expect(find.text('1 producto'), findsOneWidget);

      // El único icono del chip es su "x" de borrar.
      await tester.tap(find.descendant(
        of: find.widgetWithText(InputChip, 'JBL'),
        matching: find.byType(Icon),
      ));
      await tester.pumpAndSettle();

      expect(env.products.lastFilters.brandIds, isEmpty);
      expect(find.text('4 productos'), findsOneWidget);
      expect(find.text('Limpiar todo'), findsNothing);
    });

    testWidgets('Limpiar todo quita todos los filtros', (tester) async {
      final env = _env();
      await _openShop(tester, env);
      await _openFilters(tester);
      await tester.tap(find.text('7POWER (404)'));
      await tester.tap(find.text('Mayor stock'));
      await tester.pump();
      await tester.tap(find.text('Aplicar (2)'));
      await tester.pumpAndSettle();
      expect(env.products.lastFilters.activeCount, 2);

      await tester.tap(find.text('Limpiar todo'));
      await tester.pumpAndSettle();

      expect(env.products.lastFilters, ProductFilters.none);
      expect(find.text('4 productos'), findsOneWidget);
    });

    testWidgets('Limpiar dentro de la hoja descarta lo elegido sin aplicar',
        (tester) async {
      final env = _env();
      await _openShop(tester, env);
      final requests = env.products.filtersHistory.length;

      await _openFilters(tester);
      expect(
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Limpiar')).onPressed,
        isNull,
      );
      await tester.tap(find.text('JBL (7)'));
      await tester.pump();
      await tester.tap(find.text('Limpiar'));
      await tester.pump();
      await tester.tap(find.text('Ver productos'));
      await tester.pumpAndSettle();

      // No cambió nada, así que no se volvió a pedir el catálogo.
      expect(env.products.filtersHistory.length, requests);
    });

    testWidgets('el filtro de precio se envía al servidor', (tester) async {
      final env = _env(priceBounds: true);
      await _openShop(tester, env);
      final provider = _context(tester).read<ProductsProvider>();

      expect(provider.canFilterByPrice, isTrue);
      expect(provider.priceMin, 30);
      expect(provider.priceMax, 500);

      await provider.applyFilters(
        const ProductFilters(minPrice: 100, maxPrice: 250),
      );
      await tester.pumpAndSettle();

      expect(env.products.lastFilters.minPrice, 100);
      expect(provider.products.map((p) => p.name),
          unorderedEquals(['Driver Bosch', 'Parlante']));
      expect(find.text('S/ 100.00 – S/ 250.00'), findsOneWidget);
    });

    testWidgets('un invitado sin lista de precios no puede filtrar por precio',
        (tester) async {
      final env = _env();
      await _openShop(tester, env);

      final provider = _context(tester).read<ProductsProvider>();

      expect(provider.canFilterByPrice, isFalse);
    });
  });
}
