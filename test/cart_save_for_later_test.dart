import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/data/models/cart_item_model.dart';
import 'package:appecommerce/presentation/components/components.dart';
import 'package:appecommerce/presentation/providers/cart_provider.dart';

import 'support/fakes.dart';

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar, skipOffstage: false));

CartItemModel _item(
  int id,
  String name, {
  double price = 100,
  int quantity = 1,
  int stock = 9,
  bool saved = false,
}) =>
    CartItemModel(
      productId: id,
      name: name,
      code: 'COD$id',
      price: price,
      currency: 's',
      quantity: quantity,
      stock: stock,
      savedForLater: saved,
    );

/// App con sesión iniciada, con [items] en el carrito del servidor, y el
/// carrito abierto.
Future<TestEnv> _openCart(
  WidgetTester tester,
  List<CartItemModel> items,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = TestEnv(catalog: [product(1, 'Driver', price: 100, stock: 9)]);
  await env.authRepo.login('ana@correo.com', 'secreto');
  env.cartRemote.items = List.of(items);

  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Carrito'));
  await tester.pumpAndSettle();
  return env;
}

Future<void> _menu(WidgetTester tester, String option, {int line = 0}) async {
  await tester.tap(find.byTooltip('Más opciones').at(line));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

void main() {
  group('Modelo', () {
    test('GET /cart marca los guardados para después', () {
      final saved = CartItemModel.fromApi({
        'producto_id': 4,
        'nombre': 'Cable',
        'cantidad': 2,
        'precio': 10,
        'guardado_para_despues': true,
      });
      final active = CartItemModel.fromApi({
        'producto_id': 5,
        'nombre': 'Driver',
        'cantidad': 1,
        'precio': 10,
        'guardado_para_despues': false,
      });
      final oldServer = CartItemModel.fromApi({
        'producto_id': 6,
        'nombre': 'Sin dato',
        'cantidad': 1,
        'precio': 10,
      });

      expect(saved.savedForLater, isTrue);
      expect(active.savedForLater, isFalse);
      expect(oldServer.savedForLater, isFalse);
    });

    test('el carrito del invitado recuerda lo guardado', () {
      final copy = CartItemModel.fromLocal(_item(1, 'Driver', saved: true).toLocal());

      expect(copy.savedForLater, isTrue);
    });

    test('un carrito guardado antes de esta función se lee como activo', () {
      final json = _item(1, 'Driver').toLocal()..remove('savedForLater');

      expect(CartItemModel.fromLocal(json).savedForLater, isFalse);
    });
  });

  group('Carrito con sesión', () {
    testWidgets('lo guardado no cuenta en las unidades, el total ni el vacío',
        (tester) async {
      await _openCart(tester, [
        _item(1, 'Driver', price: 100),
        _item(2, 'Cable', price: 0, quantity: 4, saved: true),
      ]);
      final cart = _context(tester).read<CartProvider>();

      expect(cart.items.map((i) => i.productId), [1]);
      expect(cart.savedItems.map((i) => i.productId), [2]);
      expect(cart.totalUnits, 1);
      expect(cart.summaries.single.total, 100);
      // El guardado sin precio no impide al invitado ver el total.
      expect(cart.allItemsPriced, isTrue);
    });

    test('guardar para después y volver al carrito', () async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await env.authRepo.login('ana@correo.com', 'secreto');
      env.cartRemote.items = [_item(1, 'Driver')];

      var result = await env.cartRepo.saveForLater(1);
      expect(result.fold((_) => null, (v) => v.single.savedForLater), isTrue);

      result = await env.cartRepo.moveToCart(1);
      expect(result.fold((_) => null, (v) => v.single.savedForLater), isFalse);
    });

    test('devolver al carrito sin stock falla con el motivo del servidor',
        () async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await env.authRepo.login('ana@correo.com', 'secreto');
      env.cartRemote
        ..stockLimit = 2
        ..items = [_item(1, 'Driver', quantity: 5, saved: true)];

      final result = await env.cartRepo.moveToCart(1);

      expect(
        result.fold((f) => f.message, (_) => null),
        'Stock insuficiente para mover este producto al carrito.',
      );
      expect(env.cartRemote.items.single.savedForLater, isTrue);
    });

    test('vaciar el carrito conserva lo guardado', () async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await env.authRepo.login('ana@correo.com', 'secreto');
      env.cartRemote.items = [
        _item(1, 'Driver'),
        _item(2, 'Cable', saved: true),
      ];

      final result = await env.cartRepo.clear();

      final left = result.fold((_) => <CartItemModel>[], (v) => v);
      expect(left.map((i) => i.productId), [2]);
      expect(left.single.savedForLater, isTrue);
    });

    test('agregar un producto que estaba guardado lo devuelve al carrito',
        () async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      await env.authRepo.login('ana@correo.com', 'secreto');
      env.cartRemote.items = [_item(1, 'Driver', saved: true)];

      final result = await env.cartRepo.add(product(1, 'Driver', stock: 9), 1);

      final item = result.fold((_) => null, (v) => v.single);
      expect(item!.savedForLater, isFalse);
      expect(item.quantity, 2);
    });
  });

  group('Carrito de invitado', () {
    test('se guarda para después en el equipo y vuelve al carrito', () async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      await env.cartRepo.add(product(1, 'Driver', stock: 9), 2);

      await env.cartRepo.saveForLater(1);
      expect(env.cartLocal.items.single.savedForLater, isTrue);
      expect(env.cartLocal.items.single.quantity, 2);

      await env.cartRepo.moveToCart(1);
      expect(env.cartLocal.items.single.savedForLater, isFalse);
    });

    test('sin stock no vuelve al carrito', () async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.cartLocal.items = [_item(1, 'Driver', quantity: 3, stock: 1, saved: true)];

      final result = await env.cartRepo.moveToCart(1);

      expect(result.fold((f) => f.message, (_) => null),
          'Solo quedan 1 unidades disponibles.');
      expect(env.cartLocal.items.single.savedForLater, isTrue);
    });

    test('vaciar conserva lo guardado', () async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.cartLocal.items = [
        _item(1, 'Driver'),
        _item(2, 'Cable', saved: true),
      ];

      await env.cartRepo.clear();

      expect(env.cartLocal.items.map((i) => i.productId), [2]);
    });

    test('agregar un producto guardado lo devuelve al carrito', () async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      env.cartLocal.items = [_item(1, 'Driver', saved: true)];

      await env.cartRepo.add(product(1, 'Driver', stock: 9), 1);

      expect(env.cartLocal.items.single.savedForLater, isFalse);
    });

    test('al iniciar sesión, lo guardado pasa al servidor como guardado',
        () async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      env.cartLocal.items = [
        _item(1, 'Driver'),
        _item(2, 'Cable', saved: true),
      ];
      await env.authRepo.login('ana@correo.com', 'secreto');

      final result = await env.cartRepo.syncGuestCart();

      final merged = result.fold((_) => <CartItemModel>[], (v) => v);
      expect(merged.firstWhere((i) => i.productId == 1).savedForLater, isFalse);
      expect(merged.firstWhere((i) => i.productId == 2).savedForLater, isTrue);
      expect(env.cartLocal.items, isEmpty);
    });
  });

  group('Pantalla del carrito', () {
    testWidgets('la cantidad lleva la unidad de medida', (tester) async {
      await _openCart(tester, [_item(1, 'Driver', quantity: 5)]);

      expect(find.text('5 un'), findsOneWidget);
    });

    testWidgets('la unidad sigue al cambiar la cantidad', (tester) async {
      await _openCart(tester, [_item(1, 'Driver', quantity: 1)]);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('2 un'), findsOneWidget);
    });

    testWidgets('los 3 puntos ofrecen guardar para después y eliminar',
        (tester) async {
      await _openCart(tester, [_item(1, 'Driver')]);

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();

      expect(find.text('Guardar para después'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('Eliminar quita el producto del carrito', (tester) async {
      final env = await _openCart(tester, [
        _item(1, 'Driver'),
        _item(2, 'Cable', price: 30),
      ]);

      await _menu(tester, 'Eliminar');

      expect(find.text('Driver'), findsNothing);
      expect(find.text('Cable'), findsOneWidget);
      expect(env.cartRemote.items.map((i) => i.productId), [2]);
    });

    testWidgets('Guardar para después lo saca del pedido y lo muestra aparte',
        (tester) async {
      final env = await _openCart(tester, [
        _item(1, 'Driver', price: 100),
        _item(2, 'Cable', price: 30, quantity: 2),
      ]);
      expect(find.text('Subtotal (3 items)'), findsOneWidget);

      await _menu(tester, 'Guardar para después');

      // El pedido sigue con el cable; el driver quedó guardado.
      expect(find.text('Subtotal (2 items)'), findsOneWidget);
      expect(find.text('Guardados para después (1)'), findsOneWidget);
      expect(find.text('Driver'), findsOneWidget);
      expect(find.text('Mover al carrito'), findsOneWidget);
      expect(find.text('Guardado para después'), findsOneWidget); // aviso
      expect(env.cartRemote.items.firstWhere((i) => i.productId == 1).savedForLater,
          isTrue);
      // La insignia del carrito tampoco cuenta lo guardado.
      expect(_context(tester).read<CartProvider>().totalUnits, 2);
    });

    testWidgets('Mover al carrito lo devuelve al pedido', (tester) async {
      final env = await _openCart(tester, [
        _item(1, 'Driver', price: 100),
        _item(2, 'Cable', price: 30, saved: true),
      ]);
      expect(find.text('Guardados para después (1)'), findsOneWidget);

      await tester.tap(find.text('Mover al carrito'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Guardados para después'), findsNothing);
      expect(find.text('Subtotal (2 items)'), findsOneWidget);
      expect(find.text('S/ 130.00'), findsNWidgets(2));
      expect(env.cartRemote.items.every((i) => !i.savedForLater), isTrue);
    });

    testWidgets('si ya no hay stock avisa y sigue guardado', (tester) async {
      final env = await _openCart(tester, [
        _item(1, 'Driver'),
        _item(2, 'Cable', quantity: 5, saved: true),
      ]);
      env.cartRemote.stockLimit = 2;

      await tester.tap(find.text('Mover al carrito'));
      await tester.pumpAndSettle();

      expect(find.text('Stock insuficiente para mover este producto al carrito.'),
          findsOneWidget);
      expect(find.text('Guardados para después (1)'), findsOneWidget);
    });

    testWidgets('quitar de guardados lo borra del todo', (tester) async {
      final env = await _openCart(tester, [
        _item(1, 'Driver'),
        _item(2, 'Cable', saved: true),
      ]);

      await tester.tap(find.byTooltip('Quitar de guardados'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Guardados para después'), findsNothing);
      expect(env.cartRemote.items.map((i) => i.productId), [1]);
    });

    testWidgets('con todo guardado no hay total ni botones de pago',
        (tester) async {
      await _openCart(tester, [_item(1, 'Driver', saved: true)]);

      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(find.text('Guardados para después (1)'), findsOneWidget);
      expect(find.text('Pagar'), findsNothing);
      expect(find.text('Cotizar'), findsNothing);
      expect(find.byType(QuantitySelector), findsNothing);
    });

    testWidgets('guardar el último producto deja el carrito vacío con lo guardado',
        (tester) async {
      await _openCart(tester, [_item(1, 'Driver')]);

      await _menu(tester, 'Guardar para después');

      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(find.text('Guardados para después (1)'), findsOneWidget);
      expect(find.text('Pagar'), findsNothing);
    });

    testWidgets('vaciar el carrito deja los guardados', (tester) async {
      await _openCart(tester, [
        _item(1, 'Driver'),
        _item(2, 'Cable', saved: true),
      ]);

      await tester.tap(find.byTooltip('Vaciar carrito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vaciar'));
      await tester.pumpAndSettle();

      expect(find.text('Guardados para después (1)'), findsOneWidget);
      expect(find.text('Cable'), findsOneWidget);
      expect(find.text('Pagar'), findsNothing);
    });

    testWidgets('sin nada en el carrito ni guardado, ofrece seguir comprando',
        (tester) async {
      await _openCart(tester, []);

      expect(find.text('Seguir comprando'), findsOneWidget);
    });
  });
}
