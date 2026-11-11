import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/promotions_remote_datasource.dart';
import 'package:appecommerce/data/models/product_detail_model.dart';
import 'package:appecommerce/domain/entities/promotion_entity.dart';
import 'package:appecommerce/presentation/components/components.dart';
import 'package:appecommerce/presentation/pages/image_viewer_page.dart';
import 'package:appecommerce/presentation/utils/app_link.dart';
import 'package:appecommerce/presentation/utils/product_share.dart';
import 'package:appecommerce/theme/app_theme.dart';

import 'support/fakes.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.build(Colors.black),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

PromotionsRemoteDataSourceImpl _source(Object body) =>
    PromotionsRemoteDataSourceImpl(ApiClient(
      client: MockClient((_) async =>
          http.Response.bytes(utf8.encode(jsonEncode(body)), 200)),
    ));

void main() {
  group('AppLink.parse', () {
    AppLinkTarget parse(String? url) => AppLink.parse(url);

    test('las fichas de producto de la web se abren dentro del app', () {
      for (final url in [
        'https://7power.pe/product-details/667',
        'https://www.7power.pe/product-details/667',
        '/product-details/667',
        'product/667/bateria-de-litio',
      ]) {
        final t = parse(url);
        expect(t.kind, AppLinkKind.product, reason: url);
        expect(t.productId, 667, reason: url);
      }
    });

    test('la tienda, las ofertas y los cupones también', () {
      expect(parse('/shop').kind, AppLinkKind.shop);
      expect(parse('https://7power.pe/shop/categoria/audio').kind, AppLinkKind.shop);
      expect(parse('https://7power.pe/ofertas').kind, AppLinkKind.offers);
      expect(parse('/my-account/cupones').kind, AppLinkKind.coupons);
      expect(parse('/cupones').kind, AppLinkKind.coupons);
    });

    test('sin enlace lleva a la tienda', () {
      expect(parse(null).kind, AppLinkKind.shop);
      expect(parse('  ').kind, AppLinkKind.shop);
      expect(parse('https://7power.pe').kind, AppLinkKind.shop);
    });

    test('otras direcciones se abren en el navegador', () {
      final outside = parse('https://www.facebook.com/SEVENPOWER');
      expect(outside.kind, AppLinkKind.external);
      expect(outside.url, 'https://www.facebook.com/SEVENPOWER');

      // Una página de la web que el app no tiene: se abre en la web.
      final blog = parse('/blog');
      expect(blog.kind, AppLinkKind.external);
      expect(blog.url, 'https://7power.pe/blog');

      // Un producto sin número válido no se inventa.
      expect(parse('/product-details/abc').kind, AppLinkKind.external);
    });
  });

  group('Promociones del servidor', () {
    test('los banners promocionales se leen y se descartan los que no tienen imagen',
        () async {
      final banners = await _source({
        'status': 'success',
        'data': [
          {
            'id': 2,
            'titulo': 'BATERÍA LITIO',
            'precio': 'S/ 0.01',
            'texto_boton': 'Ir a la PROMOCION',
            'imagen_url': 'https://api.7power.pe/storage/x.jpg',
            'enlace_url': 'https://7power.pe/product-details/667',
            'color_boton': '#ff1100',
            'color_badge_nombre': '#0d6efd',
            'color_badge_precio': '#28a745',
          },
          {'id': 3, 'titulo': 'Sin imagen', 'imagen_url': null},
        ],
      }).getPromoBanners();

      expect(banners, hasLength(1));
      final b = banners.single;
      expect(b.title, 'BATERÍA LITIO');
      expect(b.price, 'S/ 0.01');
      expect(b.buttonColor, '#ff1100');
      expect(b.linkUrl, contains('product-details/667'));
    });

    test('las ventas flash vigentes se leen; las terminadas y las ilegibles no',
        () async {
      String at(Duration d) => DateTime.now().add(d).toIso8601String();
      final sales = await _source([
        {
          'id': 1,
          'nombre': 'Flash de la semana',
          'imagen_url': 'https://api.7power.pe/storage/f.png',
          'fecha_fin': at(const Duration(days: 2)),
          'texto_boton': 'Comprar',
          'enlace_url': '/shop',
          'color_boton': '#ff0000',
          'color_badge': '#112233',
        },
        {'id': 2, 'nombre': 'Terminada', 'fecha_fin': at(const Duration(hours: -3))},
        {'id': 3, 'nombre': 'Sin fecha'},
      ]).getFlashSales();

      expect(sales.map((s) => s.name), ['Flash de la semana']);
      expect(sales.single.badgeColor, '#112233');
    });

    test('sin promociones el servidor manda una lista vacía', () async {
      expect(await _source([]).getFlashSales(), isEmpty);
      expect(await _source({'status': 'success', 'data': []}).getPromoBanners(),
          isEmpty);
    });

    test('FlashSale calcula lo que falta y si sigue vigente', () {
      final now = DateTime(2026, 11, 5, 12);
      final sale = FlashSale(
        id: 1,
        name: 'X',
        endsAt: now.add(const Duration(hours: 5, minutes: 3)),
      );

      expect(sale.isActive(now), isTrue);
      expect(sale.remaining(now), const Duration(hours: 5, minutes: 3));
      expect(sale.isActive(now.add(const Duration(hours: 6))), isFalse);
      expect(sale.remaining(now.add(const Duration(hours: 6))), Duration.zero);
    });

    test('un cupón está "por vencer" desde 7 días antes y no si ya venció', () {
      final now = DateTime(2026, 11, 5);
      CouponOffer coupon(DateTime? end) => CouponOffer(
            id: 1,
            code: 'X',
            title: 'X',
            isPercentage: true,
            value: 10,
            endsAt: end,
          );

      expect(coupon(now.add(const Duration(days: 3))).expiresSoon(now), isTrue);
      expect(coupon(now.add(const Duration(days: 7))).expiresSoon(now), isTrue);
      expect(coupon(now.add(const Duration(days: 8))).expiresSoon(now), isFalse);
      expect(coupon(now.subtract(const Duration(days: 1))).expiresSoon(now), isFalse);
      expect(coupon(null).expiresSoon(now), isFalse);
    });
  });

  group('Secciones de la portada', () {
    final now = DateTime(2026, 11, 5, 12);

    FlashSale sale(int id, String name, Duration left) =>
        FlashSale(id: id, name: name, endsAt: now.add(left), buttonText: 'Comprar');

    testWidgets('la cuenta regresiva muestra días, horas, minutos y segundos',
        (tester) async {
      await tester.pumpWidget(_app(FlashSalesSection(
        sales: [
          sale(1, 'Flash 1', const Duration(days: 2, hours: 5, minutes: 3, seconds: 9)),
        ],
        now: () => now,
        onOpen: (_) {},
      )));

      expect(find.text('Ventas Flash'), findsOneWidget);
      expect(find.text('Flash 1'), findsOneWidget);
      for (final text in ['02', '05', '03', '09', 'Días', 'Hrs', 'Min', 'Seg']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('las que ya terminaron no se ven, y sin ninguna no hay sección',
        (tester) async {
      await tester.pumpWidget(_app(FlashSalesSection(
        sales: [
          sale(1, 'Vigente', const Duration(hours: 1)),
          sale(2, 'Terminada', const Duration(minutes: -5)),
        ],
        now: () => now,
        onOpen: (_) {},
      )));
      expect(find.text('Vigente'), findsOneWidget);
      expect(find.text('Terminada'), findsNothing);

      await tester.pumpWidget(_app(FlashSalesSection(
        sales: [sale(2, 'Terminada', const Duration(minutes: -5))],
        now: () => now,
        onOpen: (_) {},
      )));
      expect(find.text('Ventas Flash'), findsNothing);
    });

    testWidgets('tocar una venta flash la abre', (tester) async {
      FlashSale? opened;
      await tester.pumpWidget(_app(FlashSalesSection(
        sales: [sale(7, 'Flash', const Duration(hours: 1))],
        now: () => now,
        onOpen: (s) => opened = s,
      )));

      await tester.tap(find.text('Comprar'));

      expect(opened?.id, 7);
    });

    testWidgets('la cuenta regresiva se actualiza cada segundo', (tester) async {
      FlashCountdown.ticking = true;
      addTearDown(() => FlashCountdown.ticking = false);

      var clock = now;
      await tester.pumpWidget(_app(FlashCountdown(
        endsAt: now.add(const Duration(seconds: 10)),
        now: () => clock,
      )));
      expect(find.text('10'), findsOneWidget);

      clock = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('07'), findsOneWidget);

      // Terminó: se queda en cero.
      clock = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00'), findsNWidgets(4));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('el banner promocional muestra nombre, precio y botón',
        (tester) async {
      PromoBanner? opened;
      await tester.pumpWidget(_app(PromoBannersSection(
        banners: const [
          PromoBanner(
            id: 2,
            title: 'MEDIO SELLADO',
            price: 'S/ 0.01',
            buttonText: 'Ir a la oferta',
            imageUrl: 'http://api.test/a.jpg',
            buttonColor: '#fa0000',
          ),
        ],
        onOpen: (b) => opened = b,
      )));

      expect(find.text('Promociones'), findsOneWidget);
      expect(find.text('MEDIO SELLADO'), findsOneWidget);
      expect(find.text('S/ 0.01'), findsOneWidget);

      await tester.tap(find.text('Ir a la oferta'));
      expect(opened?.id, 2);
    });
  });

  group('Portada con promociones', () {
    testWidgets('se muestran las ventas flash y los banners que haya', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.promotionsRemote.flashSales = [
        FlashSale(
          id: 1,
          name: 'Flash de noviembre',
          endsAt: DateTime.now().add(const Duration(days: 3)),
        ),
      ];
      env.promotionsRemote.promoBanners = const [
        PromoBanner(id: 2, title: 'BATERÍA LITIO', imageUrl: 'http://api.test/a.jpg'),
      ];
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      expect(find.text('Ventas Flash'), findsOneWidget);
      expect(find.text('Flash de noviembre'), findsOneWidget);
      expect(find.text('Promociones'), findsOneWidget);
      expect(find.text('BATERÍA LITIO'), findsOneWidget);
    });

    testWidgets('sin promociones la portada no muestra esas secciones',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      expect(find.text('Ventas Flash'), findsNothing);
      expect(find.text('Promociones'), findsNothing);
    });

    testWidgets('si el servidor falla, la portada sigue sin esas secciones',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.promotionsRemote.failure = Exception('caído');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      expect(find.text('Ventas Flash'), findsNothing);
      expect(find.text('Recomendado para ti'), findsOneWidget);
    });
  });

  group('Ficha del producto', () {
    Future<void> openDetail(WidgetTester tester, TestEnv env) async {
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(ProductCard),
        matching: find.text('Driver'),
      ).first);
      await tester.pumpAndSettle();
    }

    testWidgets('compartir manda el nombre, el precio y el enlace de la web',
        (tester) async {
      String? sentText;
      String? sentSubject;
      ProductShare.sender = (text, subject) async {
        sentText = text;
        sentSubject = subject;
      };
      addTearDown(() => ProductShare.sender = (_, _) async {});

      final env = TestEnv(catalog: [product(5, 'Driver', price: 99.5, stock: 9)]);
      await openDetail(tester, env);
      await tester.tap(find.byTooltip('Compartir producto'));
      await tester.pumpAndSettle();

      expect(sentSubject, 'Driver');
      expect(sentText, contains('Mira este producto: Driver - S/ 99.50'));
      expect(sentText, contains('https://7power.pe/product-details/5'));
    });

    test('un invitado sin precio visible comparte sin el precio', () {
      final hidden = product(5, 'Driver', price: 0, priceVisible: false);

      expect(
        ProductShare.message(hidden),
        'Mira este producto: Driver\nhttps://7power.pe/product-details/5',
      );
    });

    testWidgets('si compartir falla se avisa', (tester) async {
      ProductShare.sender = (_, _) async => throw Exception('sin apps');
      addTearDown(() => ProductShare.sender = (_, _) async {});

      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      await openDetail(tester, env);
      await tester.tap(find.byTooltip('Compartir producto'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo compartir el producto.'), findsOneWidget);
    });

    testWidgets('con manual en PDF aparece el botón', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      env.products.manualUrls[5] = 'https://api.7power.pe/storage/manual.pdf';
      await openDetail(tester, env);

      expect(find.text('Ver manual del producto (PDF)'), findsOneWidget);
    });

    testWidgets('sin manual no hay botón', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      await openDetail(tester, env);

      expect(find.text('Ver manual del producto (PDF)'), findsNothing);
    });

    testWidgets('tocar la foto abre el visor a pantalla completa', (tester) async {
      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      env.products.galleries[5] = [
        'http://api.test/a.jpg',
        'http://api.test/b.jpg',
      ];
      await openDetail(tester, env);
      expect(find.byType(ImageViewerPage), findsNothing);

      await tester.tap(find.byIcon(Icons.zoom_in_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(ImageViewerPage), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    test('el modelo lee el manual del producto', () {
      final detail = ProductDetailModel.fromJson({
        'producto': {
          'id': 1,
          'nombre': 'X',
          'precio_venta': '10',
          'stock': 1,
          'manual_pdf_url': 'https://api.7power.pe/storage/manual.pdf',
        },
        'detalles': null,
      });
      expect(detail.manualUrl, 'https://api.7power.pe/storage/manual.pdf');

      final sin = ProductDetailModel.fromJson({
        'producto': {'id': 1, 'nombre': 'X', 'precio_venta': '10', 'stock': 1},
        'detalles': null,
      });
      expect(sin.manualUrl, isNull);
    });
  });

  group('Mis cupones', () {
    testWidgets('está en el menú de la cuenta y marca los que están por vencer',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.promotionsRemote.coupons = [
        CouponOffer(
          id: 1,
          code: 'PRONTO10',
          title: '10% por vencer',
          isPercentage: true,
          value: 10,
          endsAt: DateTime.now().add(const Duration(days: 2)),
        ),
        CouponOffer(
          id: 2,
          code: 'LARGO5',
          title: '5% de largo plazo',
          isPercentage: true,
          value: 5,
          endsAt: DateTime.now().add(const Duration(days: 60)),
        ),
      ];
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cuenta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mis cupones'));
      await tester.pumpAndSettle();

      expect(find.text('PRONTO10'), findsOneWidget);
      expect(find.text('LARGO5'), findsOneWidget);
      // Solo el que vence pronto lleva la marca.
      expect(find.text('Por vencer'), findsOneWidget);
    });
  });

  group('Visor de imágenes', () {
    double scale(WidgetTester tester) => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    testWidgets('el doble toque amplía y otro doble toque vuelve al tamaño normal',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ZoomableImage(url: 'http://api.test/a.jpg')),
      ));
      expect(scale(tester), 1);

      Future<void> doubleTap() async {
        final at = tester.getCenter(find.byType(ZoomableImage));
        await tester.tapAt(at);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tapAt(at);
        await tester.pumpAndSettle();
      }

      await doubleTap();
      expect(scale(tester), closeTo(ZoomableImage.zoomedScale, 0.01));

      await doubleTap();
      expect(scale(tester), closeTo(1, 0.01));
    });

    testWidgets('mientras la foto está ampliada no se cambia de página',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImageViewerPage(images: ['http://api.test/a.jpg', 'http://api.test/b.jpg']),
      ));
      expect(find.text('1 / 2'), findsOneWidget);

      // Sin ampliar, deslizar cambia a la segunda foto.
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
    });
  });
}
