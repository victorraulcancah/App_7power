import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/presentation/components/components.dart';
import 'package:appecommerce/presentation/providers/cart_provider.dart';

import 'support/fakes.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<TestEnv> _openHome(WidgetTester tester, {bool loggedIn = false}) async {
  _tall(tester);
  final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
  if (loggedIn) await env.authRepo.login('ana@correo.com', 'secreto');
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  return env;
}

/// Abre la ficha de "Driver" desde la tienda.
Future<void> _openDetail(WidgetTester tester, TestEnv env) async {
  _tall(tester);
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tienda'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ProductCard'),
    matching: find.text('Driver'),
  ).first);
  await tester.pumpAndSettle();
}

void main() {
  group('Buscador del inicio', () {
    testWidgets('está en la barra de arriba, más bajo, con favoritos y carrito',
        (tester) async {
      await _openHome(tester);

      final appBar = tester.getRect(find.byType(AppBar));
      final search = tester.getRect(find.byKey(const Key('home-search')));
      final heart = tester.getRect(find.byTooltip('Favoritos'));
      final cart = tester.getRect(find.byTooltip('Carrito'));

      // Todo dentro de la barra, en una sola fila.
      for (final r in [search, heart, cart]) {
        expect(r.top, greaterThanOrEqualTo(appBar.top));
        expect(r.bottom, lessThanOrEqualTo(appBar.bottom));
        expect((r.center.dy - search.center.dy).abs(), lessThan(8));
      }
      // Más bajo que el de antes (con 15 de relleno vertical pasaba de 50).
      expect(search.height, lessThan(50));
      // El orden: buscador, favoritos, carrito.
      expect(search.right, lessThan(heart.left));
      expect(heart.right, lessThanOrEqualTo(cart.left));
    });

    testWidgets('el inicio no lleva el ícono de WhatsApp', (tester) async {
      await _openHome(tester);

      expect(find.byTooltip('Ayuda'), findsNothing);
    });

    testWidgets('en un teléfono de 360 px el buscador es ancho y no pisa los íconos',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      final search = tester.getRect(find.byKey(const Key('home-search')));
      final cart = tester.getRect(find.byTooltip('Carrito'));

      // Sin WhatsApp, el buscador ocupa más de dos tercios de la pantalla.
      expect(search.width, greaterThan(240));
      // Los íconos son chicos: ninguno pasa de 36 px de ancho.
      for (final tip in ['Favoritos', 'Carrito']) {
        expect(tester.getRect(find.byTooltip(tip)).width, lessThanOrEqualTo(36), reason: tip);
      }
      expect(search.right, lessThan(tester.getRect(find.byTooltip('Favoritos')).left));
      expect(cart.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    });

    testWidgets('la barra del inicio es blanca; en las otras pestañas, la de la marca',
        (tester) async {
      await _openHome(tester);

      Color? barColor() => tester.widget<AppBar>(find.byType(AppBar)).backgroundColor;

      expect(barColor(), Colors.white);

      // La tienda no lleva barra.
      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);

      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      // Sin color propio: toma el de la marca del tema.
      expect(barColor(), isNull);
    });

    testWidgets('el inicio no lleva logo', (tester) async {
      await _openHome(tester);

      expect(find.byType(BrandLogo), findsNothing);
    });

    testWidgets('Cuenta y Más siguen con el logo, el carrito y la ayuda',
        (tester) async {
      await _openHome(tester);

      for (final tab in ['Cuenta', 'Más']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();

        // (La pestaña Más tiene además su portada con el logo.)
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.byType(BrandLogo)),
          findsOneWidget,
          reason: tab,
        );
        expect(find.byKey(const Key('home-search')), findsNothing, reason: tab);
        expect(find.byTooltip('Carrito'), findsOneWidget, reason: tab);
        expect(find.byTooltip('Ayuda'), findsOneWidget, reason: tab);
      }
    });

    testWidgets('la tienda no lleva barra negra, logo ni WhatsApp, pero sí el carrito',
        (tester) async {
      await _openHome(tester);

      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BrandLogo), findsNothing);
      expect(find.byTooltip('Ayuda'), findsNothing);

      // Buscador, filtros y carrito en la primera fila, bajo la barra de estado.
      final search = tester.getRect(find.byType(TextField).first);
      final filters = tester.getRect(find.byTooltip('Filtros'));
      final cart = tester.getRect(find.byTooltip('Carrito'));
      expect((filters.center.dy - search.center.dy).abs(), lessThan(10));
      expect((cart.center.dy - search.center.dy).abs(), lessThan(10));
      expect(search.right, lessThan(filters.left));
      expect(filters.right, lessThanOrEqualTo(cart.left));
    });

    testWidgets('el carrito de la tienda abre el carrito', (tester) async {
      await _openHome(tester);

      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Carrito'));
      await tester.pumpAndSettle();

      expect(find.text('Mi carrito'), findsOneWidget);
    });

    testWidgets('al volver al inicio el buscador está de nuevo', (tester) async {
      await _openHome(tester);

      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-search')), findsOneWidget);
      expect(find.byType(BrandLogo), findsNothing);
    });

    testWidgets('el carrito abre el carrito', (tester) async {
      await _openHome(tester);

      await tester.tap(find.byTooltip('Carrito'));
      await tester.pumpAndSettle();

      expect(find.text('Mi carrito'), findsOneWidget);
    });

    testWidgets('el carrito del buscador cuenta las unidades', (tester) async {
      await _openHome(tester);
      final cart = tester
          .element(find.byType(NavigationBar, skipOffstage: false))
          .read<CartProvider>();

      await cart.add(product(5, 'Driver', stock: 9), quantity: 3);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byTooltip('Carrito'),
          matching: find.widgetWithText(Badge, '3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin sesión, favoritos pide iniciarla', (tester) async {
      await _openHome(tester);

      await tester.tap(find.byTooltip('Favoritos'));
      await tester.pumpAndSettle();

      expect(find.text('Inicia sesión para ver tus favoritos.'), findsOneWidget);
      expect(find.text('Aún no tienes favoritos'), findsNothing);
    });

    testWidgets('con sesión, favoritos abre la lista', (tester) async {
      await _openHome(tester, loggedIn: true);

      await tester.tap(find.byTooltip('Favoritos'));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes favoritos'), findsOneWidget);
    });

    testWidgets('buscar sigue llevando a la tienda con los resultados',
        (tester) async {
      await _openHome(tester);

      await tester.tap(find.byKey(const Key('home-search')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('search-field')), 'driver');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Driver'), findsWidgets);
    });
  });

  group('Ficha del producto', () {
    testWidgets('no ofrece preguntar por WhatsApp', (tester) async {
      final env = TestEnv(catalog: [product(5, 'Driver', stock: 0, price: 0)]);
      await _openDetail(tester, env);

      expect(find.text('Preguntar por WhatsApp'), findsNothing);
    });

    testWidgets('los relacionados sin stock no se muestran', (tester) async {
      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      env.products.relatedProducts[5] = [
        product(6, 'Cable con stock', stock: 4),
        product(7, 'Kit agotado', stock: 0),
        product(8, 'Otro agotado', stock: 0),
        product(9, 'Parlante con stock', stock: 12),
      ];
      await _openDetail(tester, env);
      await tester.scrollUntilVisible(
        find.text('Productos relacionados'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Productos relacionados'), findsOneWidget);
      expect(find.text('Cable con stock'), findsOneWidget);
      expect(find.text('Parlante con stock'), findsOneWidget);
      expect(find.text('Kit agotado', skipOffstage: false), findsNothing);
      expect(find.text('Otro agotado', skipOffstage: false), findsNothing);
    });

    testWidgets('si todos están agotados no aparece la sección', (tester) async {
      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      env.products.relatedProducts[5] = [
        product(7, 'Kit agotado', stock: 0),
        product(8, 'Otro agotado', stock: 0),
      ];
      await _openDetail(tester, env);

      expect(find.text('Productos relacionados', skipOffstage: false), findsNothing);
      expect(find.text('Kit agotado', skipOffstage: false), findsNothing);
    });

    testWidgets('sin relacionados tampoco hay sección', (tester) async {
      await _openDetail(tester, TestEnv(catalog: [product(5, 'Driver', stock: 9)]));

      expect(find.text('Productos relacionados', skipOffstage: false), findsNothing);
    });
  });
}
