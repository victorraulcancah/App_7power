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
    testWidgets('está en la barra de arriba, más bajo, con favoritos, carrito y ayuda',
        (tester) async {
      await _openHome(tester);

      final appBar = tester.getRect(find.byType(AppBar));
      final search = tester.getRect(find.byKey(const Key('home-search')));
      final heart = tester.getRect(find.byTooltip('Favoritos'));
      final cart = tester.getRect(find.byTooltip('Carrito'));
      final help = tester.getRect(find.byTooltip('Ayuda'));

      // Todo dentro de la barra, en una sola fila.
      for (final r in [search, heart, cart, help]) {
        expect(r.top, greaterThanOrEqualTo(appBar.top));
        expect(r.bottom, lessThanOrEqualTo(appBar.bottom));
        expect((r.center.dy - search.center.dy).abs(), lessThan(8));
      }
      // Más bajo que el de antes (con 15 de relleno vertical pasaba de 50).
      expect(search.height, lessThan(50));
      // El orden: buscador, favoritos, carrito, ayuda.
      expect(search.right, lessThan(heart.left));
      expect(heart.right, lessThanOrEqualTo(cart.left));
      expect(cart.right, lessThanOrEqualTo(help.left));
    });

    testWidgets('el inicio no lleva logo', (tester) async {
      await _openHome(tester);

      expect(find.byType(BrandLogo), findsNothing);
    });

    testWidgets('en las otras pestañas siguen el logo, el carrito y la ayuda',
        (tester) async {
      await _openHome(tester);

      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();

      expect(find.byType(BrandLogo), findsOneWidget);
      expect(find.byKey(const Key('home-search')), findsNothing);
      expect(find.byTooltip('Carrito'), findsOneWidget);
      expect(find.byTooltip('Ayuda'), findsOneWidget);
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

      await tester.enterText(find.byKey(const Key('home-search')), 'driver');
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
