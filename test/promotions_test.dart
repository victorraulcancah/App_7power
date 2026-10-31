import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/promotions_remote_datasource.dart';
import 'package:appecommerce/domain/entities/product_filters.dart';
import 'package:appecommerce/domain/entities/promotion_entity.dart';
import 'package:appecommerce/presentation/pages/brands_page.dart';

import 'support/fakes.dart';

Future<void> _openMore(WidgetTester tester, TestEnv env) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Más'));
  await tester.pumpAndSettle();
}

Future<void> _openFromMore(WidgetTester tester, String item) async {
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  group('Datos del servidor', () {
    PromotionsRemoteDataSourceImpl source(
      Object? Function(http.Request) body, {
      int status = 200,
      void Function(http.Request)? onRequest,
    }) =>
        PromotionsRemoteDataSourceImpl(ApiClient(
          client: MockClient((r) async {
            onRequest?.call(r);
            return http.Response.bytes(utf8.encode(jsonEncode(body(r))), status);
          }),
          isConnected: () async => true,
        ));

    test('lee los cupones activos aunque los decimales lleguen como texto', () async {
      late http.Request request;
      final remote = source((_) => [
            {
              'id': 3,
              'codigo': 'PROMO10',
              'titulo': '10% en todo',
              'descripcion': 'Válido en toda la tienda',
              'tipo_descuento': 'porcentaje',
              'valor_descuento': '10.00',
              'compra_minima': '150.00',
              'fecha_fin': '2026-12-31T23:59:59.000000Z',
              'solo_primera_compra': 1,
            },
            {
              'id': 4,
              'codigo': 'MENOS20',
              'tipo_descuento': 'cantidad_fija',
              'valor_descuento': 20,
            },
          ], onRequest: (r) => request = r);

      final coupons = await remote.getActiveCoupons();

      expect(request.url.path, '/api/cupones/activos');
      expect(coupons, hasLength(2));
      expect(coupons[0].code, 'PROMO10');
      expect(coupons[0].isPercentage, isTrue);
      expect(coupons[0].value, 10);
      expect(coupons[0].minPurchase, 150);
      expect(coupons[0].firstPurchaseOnly, isTrue);
      expect(coupons[0].endsAt, DateTime.utc(2026, 12, 31, 23, 59, 59));
      expect(coupons[1].isPercentage, isFalse);
      expect(coupons[1].title, 'MENOS20');
      expect(coupons[1].minPurchase, isNull);
    });

    test('lee el banner de ofertas y sus productos con descuento', () async {
      late http.Request request;
      final remote = source((_) => {
            'id': 1,
            'imagen_url': 'https://api.7power.pe/storage/banners-ofertas/a.gif',
            'productos': [
              {
                'id': 12,
                'nombre': 'DRIVER 400W',
                'precio': '100.00',
                'descuento_porcentaje': '15.00',
                'precio_con_descuento': 85,
                'imagen_principal': 'https://api.7power.pe/storage/productos/d.png',
                'stock': 8,
                'marca_nombre': '7POWER',
              },
            ],
          }, onRequest: (r) => request = r);

      final banner = await remote.getOffers();

      expect(request.url.path, '/api/banners-ofertas/activo');
      expect(banner.imageUrl, endsWith('a.gif'));
      expect(banner.products, hasLength(1));
      final p = banner.products.single;
      expect([p.id, p.name, p.price, p.discountPrice, p.discountPercent, p.stock],
          [12, 'DRIVER 400W', 100.0, 85.0, 15.0, 8]);
      expect(p.brand, '7POWER');
    });

    test('sin banner activo (404) no hay ofertas, no es un error', () async {
      final remote = source((_) => {'message': 'No hay banner activo'}, status: 404);

      final banner = await remote.getOffers();

      expect(banner.products, isEmpty);
      expect(banner.isEmpty, isTrue);
    });

    test('otros errores del servidor sí se propagan', () async {
      final remote = source((_) => {'message': 'Falló'}, status: 500);

      expect(remote.getOffers(), throwsA(isA<ServerException>()));
    });
  });

  group('Cupones', () {
    testWidgets('lista los cupones y copia el código', (tester) async {
      final env = TestEnv();
      env.promotionsRemote.coupons = [
        CouponOffer(
          id: 3,
          code: 'PROMO10',
          title: '10% en todo',
          isPercentage: true,
          value: 10,
          minPurchase: 150,
          firstPurchaseOnly: true,
          endsAt: DateTime(2026, 12, 31),
        ),
        const CouponOffer(
          id: 4,
          code: 'MENOS20',
          title: 'S/ 20 menos',
          isPercentage: false,
          value: 20,
        ),
      ];
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _openMore(tester, env);
      await _openFromMore(tester, 'Cupones');

      expect(find.text('10% en todo'), findsOneWidget);
      expect(find.text('10% de descuento'), findsOneWidget);
      expect(find.text('PROMO10'), findsOneWidget);
      expect(find.text('Solo primera compra'), findsOneWidget);
      expect(find.textContaining('Compra mínima'), findsOneWidget);
      expect(find.text('20.00 de descuento'), findsNothing);
      expect(find.textContaining('de descuento'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Copiar código').first);
      await tester.pumpAndSettle();

      expect(copied, 'PROMO10');
      expect(find.text('Código PROMO10 copiado'), findsOneWidget);
    });

    testWidgets('sin cupones muestra el estado vacío', (tester) async {
      final env = TestEnv();
      await _openMore(tester, env);
      await _openFromMore(tester, 'Cupones');

      expect(find.text('No hay cupones activos'), findsOneWidget);
    });

    testWidgets('si falla muestra el motivo y permite reintentar', (tester) async {
      final env = TestEnv();
      env.promotionsRemote.failure = const ServerException('Sin conexión', '500');
      await _openMore(tester, env);
      await _openFromMore(tester, 'Cupones');
      expect(find.text('Sin conexión'), findsOneWidget);

      env.promotionsRemote.failure = null;
      env.promotionsRemote.coupons = const [
        CouponOffer(id: 1, code: 'VUELVE', title: 'Vuelve', isPercentage: true, value: 5),
      ];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('VUELVE'), findsOneWidget);
    });
  });

  group('Ofertas', () {
    testWidgets('muestra los productos con su descuento', (tester) async {
      final env = TestEnv();
      env.promotionsRemote.offers = const OfferBanner(products: [
        OfferProduct(
          id: 12,
          name: 'DRIVER 400W',
          price: 100,
          discountPrice: 85,
          discountPercent: 15,
          stock: 8,
          brand: '7POWER',
        ),
        OfferProduct(
          id: 13,
          name: 'PARLANTE 6x9',
          price: 200,
          discountPrice: 200,
          discountPercent: 0,
          stock: 0,
        ),
      ]);
      await _openMore(tester, env);
      await _openFromMore(tester, 'Ofertas');

      expect(find.text('DRIVER 400W'), findsOneWidget);
      expect(find.text('S/ 85.00'), findsOneWidget);
      expect(find.text('S/ 100.00'), findsOneWidget);
      expect(find.text('-15%'), findsOneWidget);
      expect(find.text('PARLANTE 6x9'), findsOneWidget);
      expect(find.text('Agotado'), findsOneWidget);
      // Sin descuento no hay precio tachado ni etiqueta.
      expect(find.text('S/ 200.00'), findsOneWidget);
      expect(find.textContaining('lista de precios'), findsOneWidget);
    });

    testWidgets('sin ofertas muestra el estado vacío', (tester) async {
      final env = TestEnv();
      await _openMore(tester, env);
      await _openFromMore(tester, 'Ofertas');

      expect(find.text('No hay ofertas por ahora'), findsOneWidget);
    });
  });

  group('Marcas', () {
    test('van primero las de la vitrina, en su orden, y luego las demás por nombre', () {
      final sorted = BrandsPage.sorted(const [
        BrandEntity(id: 1, name: 'ZETA', productsCount: 3),
        BrandEntity(id: 2, name: 'DS18', productsCount: 7, inShowcase: true, showcaseOrder: 6),
        BrandEntity(id: 3, name: 'ALFA', productsCount: 2),
        BrandEntity(id: 4, name: '7POWER', productsCount: 404, inShowcase: true, showcaseOrder: 3),
        // En la vitrina pero sin orden asignado (0): después de las ordenadas.
        BrandEntity(id: 5, name: 'JOEL', productsCount: 1, inShowcase: true),
      ]);

      expect(sorted.map((b) => b.name), ['7POWER', 'DS18', 'JOEL', 'ALFA', 'ZETA']);
    });

    testWidgets('al elegir una marca abre la tienda filtrada por ella', (tester) async {
      final env = TestEnv();
      env.products.brands = const [
        BrandEntity(id: 25, name: '7POWER', productsCount: 404, inShowcase: true, showcaseOrder: 3),
        BrandEntity(id: 29, name: 'DS18', productsCount: 7),
      ];
      await _openMore(tester, env);
      await _openFromMore(tester, 'Marcas');

      expect(find.text('7POWER'), findsWidgets);
      expect(find.text('404 productos'), findsOneWidget);
      expect(find.text('7 productos'), findsOneWidget);

      await tester.tap(find.text('DS18').last);
      await tester.pumpAndSettle();

      expect(env.products.lastFilters.brandIds, {29});
      // Volvió al shell, ahora en la pestaña Tienda.
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
      expect(find.text('Marcas'), findsNothing);
    });
  });
}
