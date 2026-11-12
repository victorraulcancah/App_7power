import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appecommerce/core/errors/failures.dart';
import 'package:appecommerce/core/utils/color_utils.dart';
import 'package:appecommerce/data/datasources/store_local_datasource.dart';
import 'package:appecommerce/data/models/banner_model.dart';
import 'package:appecommerce/data/models/category_model.dart';
import 'package:appecommerce/data/models/company_info_model.dart';
import 'package:appecommerce/data/models/product_detail_model.dart';
import 'package:appecommerce/data/models/product_model.dart';
import 'package:appecommerce/domain/entities/company_info_entity.dart';
import 'package:appecommerce/presentation/components/components.dart';
import 'package:appecommerce/presentation/pages/home_page.dart';
import 'package:appecommerce/presentation/pages/startup_gate.dart';
import 'package:appecommerce/presentation/providers/company_provider.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/presentation/widgets/main_nav_bar.dart';

import 'support/fakes.dart';

/// Pasa a la pestaña "Tienda".
Future<void> _goToShop(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Tienda'));
  await tester.pumpAndSettle();
}

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(MainNavBar));

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
    expect(p.priceVisible, isTrue);
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
    expect(p.imageUrl, isNull);
    expect(p.isAvailable, isFalse);
  });

  test('ProductDetailModel arma galería, secciones y relacionados', () {
    final d = ProductDetailModel.fromJson({
      'producto': {
        'id': 635,
        'nombre': 'DRIVER',
        'codigo_producto': 'DRV2',
        'stock': 92,
        'precio_venta': '100.00',
        'imagen_url': 'https://api.7power.pe/storage/productos/a.jpg',
        'categoria': {'id': 46, 'nombre': 'DRIVER'},
        'marca': {'id': 25, 'nombre': '7POWER'},
      },
      'moneda': 'd',
      'detalles': {
        'descripcion_detallada': 'Un driver potente',
        'garantia': '  ',
        'imagenes': '["b.png","c.png"]',
      },
      'productos_relacionados': [
        {
          'id': 619,
          'nombre': 'DIFUSOR',
          'stock': 0,
          'precio_venta': '15.00',
          'moneda': 's',
          'imagen_url': 'https://api.7power.pe/storage/productos/d.jpg',
        },
      ],
    });

    expect(d.product.price, 100);
    expect(d.product.currency, 'd');
    expect(d.product.brand, '7POWER');
    expect(d.images, [
      'https://api.7power.pe/storage/productos/a.jpg',
      endsWith('/storage/productos/detalles/b.png'),
      endsWith('/storage/productos/detalles/c.png'),
    ]);
    // La garantía vacía no genera sección.
    expect(d.sections.keys, ['Descripción']);
    expect(d.related.single.name, 'DIFUSOR');
    expect(d.related.single.isAvailable, isFalse);
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

  test('CompanyInfoModel lee color, contacto, redes y métodos de pago', () {
    final c = CompanyInfoModel.fromJson({
      'nombre_empresa': '7power',
      'telefono': null,
      'celular': '  ',
      'email': 'ventas@7power.pe',
      'direccion': 'CERCADO DE LIMA',
      'facebook': 'https://www.facebook.com/SEVENPOWER',
      'instagram': 'https://www.instagram.com/7power_oficial/',
      'twitter': null,
      'logo_url': 'https://api.7power.pe/storage/empresa/logos/a.png',
      'color_navbar': '#000000',
      'metodos_pago': [
        {'id': 1, 'nombre': 'Plin', 'imagen_url': 'https://x/plin.png'},
      ],
    });

    expect(c.name, '7power');
    expect(c.navbarColor, '#000000');
    expect(c.phone, isNull);
    expect(c.mobile, isNull);
    expect(c.social.keys, [SocialNetwork.facebook, SocialNetwork.instagram]);
    expect(c.paymentMethods.single.name, 'Plin');
  });

  test('BannerModel interpreta /banners/publicos', () {
    final b = BannerModel.fromJson({
      'id': 9,
      'titulo': 'Oferta',
      'enlace_url': '/shop',
      'imagen_url': 'https://api.7power.pe/storage/banners/a.png',
    });

    expect(b.linkUrl, '/shop');
    expect(b.subtitle, isNull);
  });

  test('ColorUtils convierte hex y elige el color de texto legible', () {
    expect(ColorUtils.parseHex('#9B1C1C'), const Color(0xFF9B1C1C));
    expect(ColorUtils.parseHex('9b1c1c'), const Color(0xFF9B1C1C));
    expect(ColorUtils.parseHex('rojo'), isNull);
    expect(ColorUtils.parseHex(null), isNull);
    expect(ColorUtils.onColor(Colors.black), Colors.white);
    expect(ColorUtils.onColor(Colors.white), Colors.black);
  });

  testWidgets('El navbar toma el color que define el backend', (tester) async {
    final env = TestEnv(catalog: [product(1, 'Driver')]);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF112233));
  });

  testWidgets('Sin datos de empresa usa el color por defecto', (tester) async {
    final env = TestEnv(catalog: [product(1, 'Driver')], company: null);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF9B1C1C));
  });

  testWidgets('Con datos guardados el navbar sale con su color sin esperar a la red',
      (tester) async {
    // El backend "no responde" nunca: solo hay lo guardado en el equipo.
    final env = TestEnv(
      catalog: [product(1, 'Driver')],
      cachedCompany: testCompany,
      companyDelay: Completer<void>().future,
    );
    await tester.pumpWidget(env.app());
    await tester.pump();
    await tester.pump();

    final theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF112233));

    // Se agota el tiempo de espera del backend para no dejar el timer pendiente.
    await tester.pump(CompanyProvider.firstLoadLimit);
  });

  testWidgets('Sin datos guardados espera a la empresa y no pinta el color por defecto',
      (tester) async {
    final respuesta = Completer<void>();
    final env = TestEnv(
      catalog: [product(1, 'Driver')],
      companyDelay: respuesta.future,
    );
    await tester.pumpWidget(env.app());
    await tester.pump();

    // Mientras llega: el splash de la tienda, sin barra roja que luego cambie.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('CARGANDO...'), findsOneWidget);

    respuesta.complete();
    await tester.pumpAndSettle();

    // Ya con la tienda lista el splash se quita.
    expect(find.byType(SplashScreen), findsNothing);
    final theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF112233));
  });

  testWidgets('El splash usa el color y el texto que define la empresa',
      (tester) async {
    final respuesta = Completer<void>();
    final env = TestEnv(
      catalog: [product(1, 'Driver')],
      cachedCompany: const CompanyInfoEntity(
        name: '7power',
        navbarColor: '#112233',
        splashColor: '#003300',
        splashText: 'Preparando tu tienda',
      ),
      // La portada tarda: se ve el splash con lo guardado de la empresa.
      companyDelay: respuesta.future,
    );
    await tester.pumpWidget(env.app());
    await tester.pump();
    await tester.pump();

    expect(find.text('PREPARANDO TU TIENDA'), findsOneWidget);
    final fondo = tester.widget<ColoredBox>(find.descendant(
      of: find.byType(SplashScreen),
      matching: find.byType(ColoredBox),
    ).first);
    expect(fondo.color, const Color(0xFF003300));

    // Con la portada cargada se quita.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(StartupGate.fade);
    expect(find.byType(SplashScreen), findsNothing);

    await tester.pump(CompanyProvider.firstLoadLimit);
    respuesta.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Si la portada no llega, el splash se quita al pasar el límite',
      (tester) async {
    final env = TestEnv(
      catalog: [product(1, 'Driver')],
      cachedCompany: testCompany,
      companyDelay: Completer<void>().future,
    );
    await tester.pumpWidget(env.app());
    await tester.pump();

    // Pasado el límite se entra aunque la empresa no haya respondido; cada
    // paso (tienda construida, portada cargada, desvanecido) necesita un cuadro.
    await tester.pump(StartupGate.limit + const Duration(seconds: 1));
    for (var i = 0; i < 4; i++) {
      await tester.pump(StartupGate.fade + const Duration(milliseconds: 50));
    }

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(AppBar), findsWidgets);
  });

  testWidgets('Si la empresa tarda más del límite, entra con el tema por defecto y luego se actualiza',
      (tester) async {
    final respuesta = Completer<void>();
    final env = TestEnv(
      catalog: [product(1, 'Driver')],
      companyDelay: respuesta.future,
    );
    await tester.pumpWidget(env.app());
    await tester.pump(CompanyProvider.firstLoadLimit + const Duration(seconds: 1));
    await tester.pump();

    var theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF9B1C1C));

    respuesta.complete();
    await tester.pumpAndSettle();

    theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF112233));
  });

  test('CompanyInfoModel se guarda y se lee igual (toJson/fromJson)', () {
    final original = CompanyInfoModel.fromJson({
      'nombre_empresa': '7power',
      'logo_url': 'https://api.7power.pe/storage/empresa/logos/a.png',
      'color_navbar': '#000000',
      'email': 'ventas@7power.pe',
      'facebook': 'https://www.facebook.com/SEVENPOWER',
      'metodos_pago': [
        {'id': 1, 'nombre': 'Plin', 'imagen_url': 'https://x/plin.png'},
      ],
    });

    final copia = CompanyInfoModel.fromJson(original.toJson());

    expect(copia.name, '7power');
    expect(copia.navbarColor, '#000000');
    expect(copia.logoUrl, original.logoUrl);
    expect(copia.email, 'ventas@7power.pe');
    expect(copia.social, original.social);
    expect(copia.paymentMethods.single.name, 'Plin');
    expect(copia.paymentMethods.single.imageUrl, 'https://x/plin.png');
  });

  test('La empresa se guarda en el equipo y se recupera; un dato dañado se ignora',
      () async {
    SharedPreferences.setMockInitialValues({});
    final local = StoreLocalDataSourceImpl();
    expect(await local.readCompany(), isNull);

    await local.writeCompany(CompanyInfoModel.fromJson({
      'nombre_empresa': '7power',
      'color_navbar': '#123456',
    }));
    expect((await local.readCompany())?.navbarColor, '#123456');

    SharedPreferences.setMockInitialValues({'company_info_v1': '{no es json'});
    expect(await StoreLocalDataSourceImpl().readCompany(), isNull);
  });

  testWidgets('El logo de la empresa va en el navbar, menos en inicio y tienda',
      (tester) async {
    const conLogo = CompanyInfoEntity(
      name: '7power',
      logoUrl: 'http://api.test/logo.png',
      navbarColor: '#112233',
    );
    final env = TestEnv(catalog: [product(1, 'Driver')], company: conLogo);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();

    // El logo (no el fondo con destellos que lleva la barra de Cuenta y Más).
    final logo = find.descendant(
      of: find.byType(AppBar),
      matching: find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
    );

    // En el inicio el buscador ocupa la barra: sin logo.
    expect(logo, findsNothing);

    // La tienda tampoco lleva barra ni logo.
    await tester.tap(find.byTooltip('Tienda'));
    await tester.pumpAndSettle();
    expect(logo, findsNothing);

    // En Cuenta y Más el logo va en la barra.
    await tester.tap(find.byTooltip('Cuenta'));
    await tester.pumpAndSettle();
    expect(logo, findsOneWidget);
  });

  testWidgets('La portada muestra categorías y productos, sin footer',
      (tester) async {
    // Pantalla alta: con el buscador arriba, las categorías ya no caben en
    // la pantalla de prueba por defecto.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final env = TestEnv(catalog: [product(1, 'Driver 400W')]);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    // El título de la sección y la pestaña de la barra inferior.
    expect(find.text('Categorías'), findsNWidgets(2));
    expect(
      find.descendant(of: find.byType(HomePage), matching: find.text('Categorías')),
      findsOneWidget,
    );
    // "Driver" es la categoría y también su pestaña en "Recomendado para ti".
    expect(find.text('Driver'), findsNWidgets(2));
    expect(find.text('Recomendado para ti'), findsOneWidget);

    // La portada es una lista: lo que queda fuera de pantalla no se construye
    // hasta hacer scroll.
    await tester.scrollUntilVisible(
      find.text('Driver 400W'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Driver 400W'), findsOneWidget);

    expect(find.text('Escríbenos a: ventas@7power.pe'), findsNothing);
    expect(find.text('Métodos de pago'), findsNothing);
  });

  testWidgets('Tocar una categoría de la portada abre la tienda filtrada',
      (tester) async {
    // Pantalla alta: la portada es larga y las categorías quedan bajo el pliegue.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final env = TestEnv(catalog: [
      product(1, 'Driver 400W'),
      product(2, 'Cable RCA', categoryId: 2),
    ]);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();

    // "RCA" está en las categorías y también como pestaña de "Recomendado
    // para ti": la primera es la categoría.
    await tester.tap(find.text('RCA').first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'RCA'), findsOneWidget);
    expect(find.text('Cable RCA'), findsWidgets);
    expect(find.text('Driver 400W'), findsNothing);
  });

  testWidgets('Tienda lista productos, marca agotados y sin precio',
      (tester) async {
    final env = TestEnv(catalog: [
      product(1, 'Driver 400W', price: 120),
      product(2, 'Cable RCA', categoryId: 2, price: 0),
      product(3, 'Parlante', stock: 0),
    ]);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _goToShop(tester);

    expect(find.text('Driver 400W'), findsWidgets);
    expect(find.text('Cable RCA'), findsWidgets);
    expect(find.text('Parlante'), findsWidgets);
    expect(find.text('Agotado'), findsWidgets);
    // Como en la web, un precio 0 se muestra tal cual (no se oculta).
    expect(find.text('S/ 0.00'), findsWidgets);
    expect(find.text('S/ 120.00'), findsWidgets);
  });

  testWidgets('Buscar y elegir categoría consultan al servidor',
      (tester) async {
    final env = TestEnv(catalog: [
      product(1, 'Driver 400W'),
      product(2, 'Cable RCA', categoryId: 2),
    ]);
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _goToShop(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'RCA'));
    await tester.pumpAndSettle();
    expect(
      _context(tester).read<ProductsProvider>().products.map((p) => p.name),
      ['Cable RCA'],
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'driver');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      _context(tester).read<ProductsProvider>().products.map((p) => p.name),
      ['Driver 400W'],
    );
  });

  testWidgets('Al llegar al final carga la siguiente página', (tester) async {
    final env = TestEnv(
      catalog: [for (var i = 1; i <= 6; i++) product(i, 'Producto $i')],
      pageSize: 2,
    );
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    expect(env.products.requestedPages, contains(1));

    final provider = _context(tester).read<ProductsProvider>();
    expect(provider.hasMore, isTrue);

    await provider.loadMore();
    await tester.pumpAndSettle();

    expect(env.products.requestedPages, contains(2));
    expect(provider.products.length, 4);
  });

  testWidgets('La tienda muestra el error y permite reintentar',
      (tester) async {
    final env = TestEnv(catalogFailure: const NetworkFailure('Sin conexión'));
    await tester.pumpWidget(env.app());
    await tester.pumpAndSettle();
    await _goToShop(tester);

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
