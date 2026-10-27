import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/utils/format_utils.dart';
import 'package:appecommerce/core/utils/stock_utils.dart';
import 'package:appecommerce/data/models/cart_item_model.dart';
import 'package:appecommerce/data/models/product_detail_model.dart';
import 'package:appecommerce/data/models/product_model.dart';
import 'package:appecommerce/domain/entities/product_detail_entity.dart';
import 'package:appecommerce/presentation/providers/cart_provider.dart';

import 'support/fakes.dart';

/// Contexto del shell, aunque haya otra pantalla encima.
BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar, skipOffstage: false));

Future<void> _goToShop(WidgetTester tester) async {
  await tester.tap(find.text('Tienda'));
  await tester.pumpAndSettle();
}

/// Reglas de precio, moneda y stock copiadas de la tienda web.
void main() {
  group('Stock', () {
    test('umbrales: más de 10 no revela la cantidad, 1-10 sí, 0 agotado', () {
      expect(StockUtils.level(11), StockLevel.high);
      expect(StockUtils.level(10), StockLevel.low);
      expect(StockUtils.level(1), StockLevel.low);
      expect(StockUtils.level(0), StockLevel.out);

      expect(StockUtils.label(544), 'Stock: +10 unidades');
      expect(StockUtils.label(10), 'Stock: 10 unidades');
      expect(StockUtils.label(3), 'Stock: 3 unidades');
      expect(StockUtils.label(0), 'Agotado');

      expect(StockUtils.units(92), '+10 unidades');
      expect(StockUtils.units(4), '4 unidades');
    });

    testWidgets('la tarjeta usa esos textos y deshabilita sin stock',
        (tester) async {
      final env = TestEnv(catalog: [
        product(1, 'Con mucho', stock: 500),
        product(2, 'Con poco', stock: 4),
        product(3, 'Sin stock', stock: 0),
      ]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _goToShop(tester);

      expect(find.text('Stock: +10 unidades'), findsOneWidget);
      expect(find.text('Stock: 4 unidades'), findsOneWidget);
      expect(find.text('Agotado'), findsOneWidget);

      final buttons = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .where((b) => b.icon is Icon && (b.icon as Icon).icon == Icons.add_shopping_cart)
          .toList();
      expect(buttons.where((b) => b.onPressed == null), hasLength(1));
    });
  });

  group('Moneda', () {
    test('s es soles por defecto; d y usd son dólares', () {
      expect(FormatUtils.normalizeCurrency(null), 's');
      expect(FormatUtils.normalizeCurrency(''), 's');
      expect(FormatUtils.normalizeCurrency('S'), 's');
      expect(FormatUtils.normalizeCurrency('d'), 'd');
      expect(FormatUtils.normalizeCurrency(' USD '), 'd');

      expect(FormatUtils.money(1234.5), 'S/ 1,234.50');
      expect(FormatUtils.money(35, currency: 'd'), 'US\$ 35.00');
      expect(FormatUtils.money(35, currency: 'usd'), 'US\$ 35.00');
    });

    test('el detalle lee las opciones de moneda del servidor', () {
      final d = ProductDetailModel.fromJson({
        'producto': {
          'id': 1,
          'nombre': 'X',
          'stock': 5,
          'precio_venta': '100.00',
        },
        'moneda': 's',
        'moneda_opciones': [
          {'moneda': 's', 'tipo_precio_id': 1, 'precio_venta': 100},
          {'moneda': 'd', 'tipo_precio_id': 2, 'precio_venta': '27.5'},
        ],
      });

      expect(d.currencyOptions.map((o) => o.currency), ['s', 'd']);
      expect(d.currencyOptions.last.price, 27.5);
    });

    testWidgets('la ficha cambia de precio con el selector y lo lleva al carrito',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver', price: 100, stock: 9)]);
      env.products.currencyOptions[1] = const [
        CurrencyOption(currency: 's', price: 100),
        CurrencyOption(currency: 'd', price: 27),
      ];
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _goToShop(tester);
      await tester.tap(find.text('Driver').first);
      await tester.pumpAndSettle();

      expect(find.text('S/ 100.00'), findsOneWidget);

      // La ficha es una lista: el selector puede quedar bajo el pliegue.
      await tester.ensureVisible(find.text('US\$'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('US\$'));
      await tester.pumpAndSettle();
      expect(find.text('US\$ 27.00'), findsOneWidget);
      expect(find.text('S/ 100.00'), findsNothing);

      await tester.tap(find.text('Agregar al carrito'));
      await tester.pumpAndSettle();
      final item = _context(tester).read<CartProvider>().items.single;
      expect(item.currency, 'd');
      expect(item.price, 27);
    });

    testWidgets('sin varias monedas no hay selector', (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _goToShop(tester);
      await tester.tap(find.text('Driver').first);
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<String>), findsNothing);
    });
  });

  group('Precio oculto a invitados', () {
    test('solo un precio_visible false explícito lo oculta', () {
      expect(
        ProductModel.fromJson({'id': 1, 'nombre': 'a', 'precio_visible': false})
            .priceVisible,
        isFalse,
      );
      expect(
        ProductModel.fromJson({'id': 1, 'nombre': 'a', 'precio_visible': true})
            .priceVisible,
        isTrue,
      );
      expect(
        ProductModel.fromJson({'id': 1, 'nombre': 'a'}).priceVisible,
        isTrue,
      );
    });

    testWidgets('la tarjeta pide iniciar sesión y no ofrece el carrito',
        (tester) async {
      final env = TestEnv(
        catalog: [product(1, 'Driver', priceVisible: false, price: 0)],
      );
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _goToShop(tester);

      expect(find.text('Precio solo para clientes'), findsOneWidget);
      expect(find.byIcon(Icons.add_shopping_cart), findsNothing);
      expect(find.text('S/ 0.00'), findsNothing);
    });

    testWidgets('la ficha muestra el aviso, sin cantidad ni carrito',
        (tester) async {
      final env = TestEnv(
        catalog: [product(1, 'Driver', priceVisible: false, price: 0)],
      );
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _goToShop(tester);
      await tester.tap(find.text('Driver').first);
      await tester.pumpAndSettle();

      expect(find.text('Precio solo para clientes'), findsOneWidget);
      expect(find.text('Inicia sesión para ver el precio y comprar.'),
          findsOneWidget);
      expect(find.text('Agregar al carrito'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('al iniciar sesión se recargan los precios', (tester) async {
      final env = TestEnv(
        catalog: [product(1, 'Driver', priceVisible: false, price: 0)],
      );
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _goToShop(tester);
      expect(find.text('Precio solo para clientes'), findsOneWidget);

      // El servidor responde con los precios del cliente tras el login.
      env.products.products = [product(1, 'Driver', price: 80)];

      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo electrónico'),
          'ana@correo.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'), 'secreto');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      await _goToShop(tester);
      expect(find.text('S/ 80.00'), findsOneWidget);
      expect(find.text('Precio solo para clientes'), findsNothing);
    });

    testWidgets('una sesión restaurada también recarga los precios',
        (tester) async {
      final env = TestEnv(
        catalog: [product(1, 'Driver', priceVisible: false, price: 0)],
      );
      await env.authRepo.login('ana@correo.com', 'secreto');
      env.products.products = [product(1, 'Driver', price: 80)];

      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _goToShop(tester);

      expect(find.text('S/ 80.00'), findsOneWidget);
    });
  });

  group('Carrito', () {
    testWidgets('el invitado ve el candado en productos sin precio y no el total',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      final cart = _context(tester).read<CartProvider>();
      await cart.add(product(1, 'Driver', price: 0, stock: 9));
      await cart.add(product(2, 'Cable', price: 30, stock: 9));

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Precio solo para clientes'), findsOneWidget);
      expect(find.text('Precios solo para clientes'), findsOneWidget);
      expect(find.textContaining('Subtotal'), findsNothing);
      expect(find.text('Total'), findsNothing);
    });

    testWidgets('el invitado ve el total si todos los productos tienen precio',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _context(tester)
          .read<CartProvider>()
          .add(product(1, 'Driver', price: 25, stock: 9), quantity: 2);

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('S/ 50.00'), findsWidgets);
    });

    testWidgets('con sesión se ve el precio aunque sea 0', (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      await env.authRepo.login('ana@correo.com', 'secreto');
      env.cartRemote.items = [
        const CartItemModel(
          productId: 1,
          name: 'Driver',
          price: 0,
          quantity: 1,
          stock: 9,
        ),
      ];
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Precio solo para clientes'), findsNothing);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('un total por moneda, soles primero', (tester) async {
      final env = TestEnv(catalog: [product(1, 'A', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      final cart = _context(tester).read<CartProvider>();
      await cart.add(product(1, 'En dólares', price: 10, stock: 9, currency: 'd'));
      await cart.add(product(2, 'En soles', price: 40, stock: 9));

      final summaries = cart.summaries;
      expect(summaries.map((s) => s.currency), ['s', 'd']);
      expect(summaries.map((s) => s.total), [40, 10]);

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Total S/'), findsOneWidget);
      expect(find.text('Total US\$'), findsOneWidget);
    });

    testWidgets('la cantidad no pasa del stock del producto', (tester) async {
      final env = TestEnv(catalog: [product(1, 'A', stock: 2)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _context(tester)
          .read<CartProvider>()
          .add(product(1, 'A', price: 10, stock: 2), quantity: 2);

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      final plus = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add));
      expect(plus.onPressed, isNull);
    });

    test('al abrir el carrito de invitado se refrescan precio y stock', () async {
      final env = TestEnv();
      await env.cartRepo.add(product(1, 'Driver', price: 0, stock: 5), 2);
      env.productRemote.details[1] = ProductDetailModel(
        product: product(1, 'Driver 400W', price: 99, stock: 40, currency: 'd'),
      );

      final result = await env.cartRepo.getCart();

      final item = result.right.single;
      expect(item.price, 99);
      expect(item.currency, 'd');
      expect(item.stock, 40);
      expect(item.name, 'Driver 400W');
      expect(item.quantity, 2);
      // Y queda guardado para la próxima vez.
      expect(env.cartLocal.items.single.price, 99);
    });

    test('si un producto no responde, se conserva su copia', () async {
      final env = TestEnv();
      await env.cartRepo.add(product(1, 'Driver', price: 10, stock: 5), 1);

      final result = await env.cartRepo.getCart();

      expect(result.right.single.price, 10);
      expect(result.right.single.name, 'Driver');
    });
  });
}
