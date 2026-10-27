import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/errors/failures.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/models/cart_item_model.dart';
import 'package:appecommerce/presentation/providers/auth_provider.dart';
import 'package:appecommerce/presentation/providers/cart_provider.dart';

import 'support/fakes.dart';

/// Contexto del shell, aunque haya otra pantalla encima (queda fuera de
/// escena pero sigue en el árbol).
BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar, skipOffstage: false));

void main() {
  group('ApiClient', () {
    ApiClient clientFor(http.Response Function(http.Request) handler) =>
        ApiClient(
          client: MockClient((r) async => handler(r)),
          isConnected: () async => true,
        );

    /// Respuesta JSON en UTF-8, como la manda el backend (http usa latin1 si
    /// no se le indica nada y rompería las tildes).
    http.Response json(String body, int status) =>
        http.Response.bytes(utf8.encode(body), status);

    test('envía el token como Bearer y el cuerpo como JSON', () async {
      late http.Request seen;
      final api = clientFor((r) {
        seen = r;
        return http.Response('{}', 200);
      })
        ..authToken = 'abc';

      await api.post('/cart/add', body: {'producto_id': 1, 'cantidad': 2});

      expect(seen.headers['Authorization'], 'Bearer abc');
      expect(seen.headers['Content-Type'], contains('application/json'));
      expect(seen.body, '{"producto_id":1,"cantidad":2}');
    });

    test('sin sesión no manda Authorization', () async {
      late http.Request seen;
      final api = clientFor((r) {
        seen = r;
        return http.Response('{}', 200);
      });

      await api.get('/productos-publicos');

      expect(seen.headers.containsKey('Authorization'), isFalse);
    });

    test('un 401 en el login muestra el mensaje del servidor', () async {
      final api = clientFor((_) => http.Response(
            '{"message":"Las credenciales proporcionadas son incorrectas."}',
            401,
          ));

      expect(
        () => api.post('/login', body: {'email': 'a', 'password': 'b'}),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Las credenciales proporcionadas son incorrectas.',
        )),
      );
    });

    test('un 401 con token avisa que la sesión venció', () async {
      var expired = 0;
      final api = clientFor((_) => http.Response('{}', 401))
        ..authToken = 'viejo'
        ..onUnauthorized = () => expired++;

      await expectLater(api.get('/cart'), throwsA(isA<AuthException>()));
      expect(expired, 1);
    });

    test('los errores de validación muestran el primer mensaje', () async {
      final api = clientFor((_) => json(
            '{"message":"The given data was invalid.",'
            '"errors":{"email":["Correo no válido"]}}',
            422,
          ));

      expect(
        () => api.post('/register', body: {}),
        throwsA(isA<ServerException>()
            .having((e) => e.message, 'message', 'Correo no válido')),
      );
    });

    test('un 409 conserva el mensaje y el código', () async {
      final api = clientFor(
        (_) => http.Response('{"message":"Stock insuficiente."}', 409),
      )..authToken = 't';

      expect(
        () => api.post('/cart/add', body: {}),
        throwsA(isA<ServerException>()
            .having((e) => e.code, 'code', '409')
            .having((e) => e.message, 'message', 'Stock insuficiente.')),
      );
    });

    test('sin internet falla antes de llamar al servidor', () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        isConnected: () async => false,
      );

      await expectLater(api.get('/x'), throwsA(isA<NetworkException>()));
      expect(calls, 0);
    });
  });

  group('AuthRepository', () {
    test('un cliente inicia sesión y queda guardada', () async {
      final env = TestEnv();

      final result = await env.authRepo.login('ana@correo.com', 'secreto');

      expect(result.isRight, isTrue);
      expect(env.apiClient.authToken, 'token-cliente');
      expect(env.authLocal.session?.token, 'token-cliente');
    });

    test('rechaza una cuenta de administración y revoca su token', () async {
      final env = TestEnv();
      env.authRemote.userType = 'admin';

      final result = await env.authRepo.login('admin@7power.pe', 'secreto');

      expect(result.isLeft, isTrue);
      expect(result.left, isA<ValidationFailure>());
      expect(env.apiClient.authToken, isNull);
      expect(env.authLocal.session, isNull);
      expect(env.authRemote.loggedOutTokens, ['token-admin']);
    });

    test('credenciales incorrectas devuelven el motivo', () async {
      final env = TestEnv();

      final result = await env.authRepo.login('ana@correo.com', 'mal');

      expect(result.left, isA<AuthenticationFailure>());
      expect(env.apiClient.authToken, isNull);
    });

    test('restaura la sesión guardada y la cierra con logout', () async {
      final env = TestEnv();
      await env.authRepo.login('ana@correo.com', 'secreto');
      env.apiClient.authToken = null;

      final restored = await env.authRepo.restoreSession();
      expect(restored.right?.email, 'ana@correo.com');
      expect(env.apiClient.authToken, 'token-cliente');

      await env.authRepo.logout();
      expect(env.apiClient.authToken, isNull);
      expect(env.authLocal.session, isNull);
      expect(env.authRemote.loggedOutTokens, ['token-cliente']);
    });

    test('si el servidor rechaza el token, la sesión se cierra', () async {
      final env = TestEnv();
      await env.authRepo.login('ana@correo.com', 'secreto');
      final expired = env.authRepo.onSessionExpired.first;

      env.apiClient.onUnauthorized!();
      await expired;

      expect(env.apiClient.authToken, isNull);
      expect(env.authLocal.session, isNull);
    });
  });

  group('CartRepository', () {
    test('invitado: suma al mismo producto y respeta el stock', () async {
      final env = TestEnv();
      final p = product(1, 'Driver', stock: 3);

      await env.cartRepo.add(p, 2);
      final merged = await env.cartRepo.add(p, 1);
      expect(merged.right.single.quantity, 3);

      final tooMany = await env.cartRepo.add(p, 1);
      expect(tooMany.left, isA<ValidationFailure>());
      expect(tooMany.left.message, 'Solo quedan 3 unidades disponibles.');
      expect(env.cartLocal.items.single.quantity, 3);
    });

    test('invitado: un producto sin stock no se agrega', () async {
      final env = TestEnv();

      final result = await env.cartRepo.add(product(1, 'X', stock: 0), 1);

      expect(result.left.message, 'Producto sin stock.');
      expect(env.cartLocal.items, isEmpty);
    });

    test('invitado: cambiar cantidad y quitar', () async {
      final env = TestEnv();
      await env.cartRepo.add(product(1, 'A', stock: 9), 1);
      await env.cartRepo.add(product(2, 'B', stock: 9), 1);

      final updated = await env.cartRepo.updateQuantity(1, 4);
      expect(updated.right.firstWhere((i) => i.productId == 1).quantity, 4);

      final removed = await env.cartRepo.remove(2);
      expect(removed.right.map((i) => i.productId), [1]);
    });

    test('con sesión usa el servidor y muestra su mensaje de stock', () async {
      final env = TestEnv();
      env.apiClient.authToken = 't';
      env.cartRemote.stockLimit = 2;

      final ok = await env.cartRepo.add(product(1, 'A'), 2);
      expect(ok.right.single.quantity, 2);
      expect(env.cartLocal.items, isEmpty);

      final tooMany = await env.cartRepo.add(product(1, 'A'), 1);
      expect(tooMany.left.message, 'Stock insuficiente.');
    });

    test('al iniciar sesión el carrito de invitado pasa al servidor', () async {
      final env = TestEnv();
      await env.cartRepo.add(product(1, 'A', stock: 9), 2);
      env.apiClient.authToken = 't';

      final result = await env.cartRepo.syncGuestCart();

      expect(result.right.single.quantity, 2);
      expect(env.cartRemote.syncCalls, 1);
      expect(env.cartLocal.items, isEmpty);
    });

    test('si no hay carrito de invitado no se llama a sync', () async {
      final env = TestEnv();
      env.apiClient.authToken = 't';
      env.cartRemote.items = [
        const CartItemModel(
            productId: 5, name: 'Del servidor', price: 1, quantity: 1, stock: 9),
      ];

      final result = await env.cartRepo.syncGuestCart();

      expect(result.right.single.name, 'Del servidor');
      expect(env.cartRemote.syncCalls, 0);
    });

    test('si el servidor falla al sincronizar, el carrito local se conserva',
        () async {
      final env = TestEnv();
      await env.cartRepo.add(product(1, 'A', stock: 9), 2);
      env.apiClient.authToken = 't';
      env.cartRemote.stockLimit = 0; // fuerza el error en sync

      final result = await env.cartRepo.syncGuestCart();

      expect(result.isLeft, isTrue);
      expect(env.cartLocal.items, hasLength(1));
    });
  });

  group('Pantallas', () {
    testWidgets('agregar desde la tienda actualiza la insignia del carrito',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver 400W')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
      await tester.pumpAndSettle();

      expect(find.text('Agregado al carrito'), findsOneWidget);
      expect(_context(tester).read<CartProvider>().totalUnits, 1);
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);
    });

    testWidgets('el carrito lista productos, total y permite quitar',
        (tester) async {
      final env = TestEnv(catalog: [
        product(1, 'Driver 400W', price: 120, stock: 9),
        product(2, 'Cable RCA', price: 30, stock: 9),
      ]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      final cart = _context(tester).read<CartProvider>();
      await cart.add(product(1, 'Driver 400W', price: 120, stock: 9));
      await cart.add(product(2, 'Cable RCA', price: 30, stock: 9),
          quantity: 2);

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Mi carrito'), findsOneWidget);
      expect(find.text('Driver 400W'), findsOneWidget);
      // Subtotal y total: 120 + 30 x 2.
      expect(find.text('S/ 180.00'), findsNWidgets(2));
      expect(find.text('Subtotal (3 items)'), findsOneWidget);
      expect(find.text('Pagar'), findsOneWidget);
      expect(find.text('Cotizar'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Driver 400W'), findsNothing);
      expect(find.text('S/ 60.00'), findsWidgets);
    });

    testWidgets('carrito vacío ofrece seguir comprando', (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      await tester.tap(find.text('Seguir comprando'));
      await tester.pumpAndSettle();
      expect(find.text('Mi carrito'), findsNothing);
    });

    testWidgets('la ficha del producto muestra datos y agrega con cantidad',
        (tester) async {
      final env = TestEnv(
        catalog: [product(1, 'Driver 400W', price: 120, stock: 9)],
      );
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Driver 400W').first);
      await tester.pumpAndSettle();

      expect(find.text('Producto'), findsOneWidget);
      expect(find.text('Stock: 9 unidades'), findsOneWidget);
      // La ficha es una lista: las secciones largas quedan bajo el pliegue.
      await tester.scrollUntilVisible(
        find.text('Descripción de Driver 400W'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Garantía'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add)); // cantidad 2
      await tester.pump();
      await tester.tap(find.text('Agregar al carrito'));
      await tester.pumpAndSettle();

      expect(_context(tester).read<CartProvider>().totalUnits, 2);
    });

    testWidgets('un producto agotado no se puede agregar desde la ficha',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Parlante', stock: 0)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parlante').first);
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('login desde la cuenta muestra el perfil y pasa el carrito',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      // Carrito de invitado antes de iniciar sesión.
      await _context(tester)
          .read<CartProvider>()
          .add(product(1, 'Driver', stock: 9), quantity: 2);

      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Inicia sesión'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo electrónico'),
          'ana@correo.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'), 'secreto');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Cerrar sesión'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(env.apiClient.authToken, 'token-cliente');
      expect(env.cartRemote.syncCalls, 1);
      expect(env.cartLocal.items, isEmpty);
      expect(_context(tester).read<CartProvider>().totalUnits, 2);
    });

    testWidgets('credenciales incorrectas muestran el error', (tester) async {
      final env = TestEnv();
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo electrónico'),
          'ana@correo.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'), 'mal');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Las credenciales proporcionadas son incorrectas.'),
          findsOneWidget);
      expect(find.text('Hola, Ana Pérez'), findsNothing);
    });

    testWidgets('el formulario valida correo y contraseña vacíos',
        (tester) async {
      final env = TestEnv();
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      expect(_context(tester).read<AuthProvider>().isAuthenticated, isFalse);
    });

    testWidgets('cerrar sesión vuelve al formulario', (tester) async {
      // Pantalla alta: el botón de cerrar sesión queda al final del menú.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final env = TestEnv();
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Cerrar sesión'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();

      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(env.apiClient.authToken, isNull);
    });
  });
}
