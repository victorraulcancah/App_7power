import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/data/models/address_model.dart';
import 'package:appecommerce/data/models/cart_item_model.dart';
import 'package:appecommerce/data/models/quote_model.dart';
import 'package:appecommerce/domain/entities/quote_entity.dart';

import 'support/fakes.dart';

QuoteModel _quote({
  String status = 'En espera',
  bool editable = true,
  bool canConvert = true,
  List<QuoteItemEntity>? items,
}) =>
    QuoteModel(
      id: 25,
      code: '2026-00025',
      status: status,
      total: 150,
      currency: 's',
      editable: editable,
      canConvert: canConvert,
      items: items ??
          const [
            QuoteItemEntity(
              productId: 1,
              name: 'Driver',
              quantity: 2,
              unitPrice: 75,
              subtotal: 150,
            ),
          ],
    );

/// Sesión iniciada, en el detalle de la cotización 2026-00025.
Future<TestEnv> _openQuote(WidgetTester tester, QuoteModel quote) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = TestEnv(catalog: [product(1, 'Driver', price: 75, stock: 9)]);
  await env.authRepo.login('ana@correo.com', 'secreto');
  env.quotesRemote.items = [quote];
  // Algo que ya había en el carrito: "Editar" lo reemplaza.
  env.cartRemote.items = [
    const CartItemModel(
      productId: 9,
      name: 'Parlante',
      price: 50,
      currency: 's',
      quantity: 1,
      stock: 9,
    ),
  ];
  env.addressesRemote.items = [
    const AddressModel(
      id: 1,
      recipient: 'ANA PEREZ',
      fullAddress: 'Av. Larco 123',
      ubigeoId: '150122',
      isDefault: true,
      departmentCode: '15',
      provinceCode: '01',
      districtCode: '22',
      department: 'LIMA',
      province: 'LIMA',
      district: 'MIRAFLORES',
    ),
  ];
  env.checkoutRemote.holderPhone = '951127833';

  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cotizaciones'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cotización 2026-00025'));
  await tester.pumpAndSettle();
  return env;
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('Comprar', () {
    testWidgets('pide confirmación, convierte la cotización y avisa', (tester) async {
      final env = await _openQuote(tester, _quote());

      await _tapButton(tester, 'Comprar');
      expect(find.text('¿Convertir a compra?'), findsOneWidget);
      await tester.tap(find.text('Sí, convertir'));
      await tester.pumpAndSettle();

      expect(env.quotesRemote.converted, [25]);
      expect(find.textContaining('COMP-1'), findsOneWidget);
      // Volvió a la lista.
      expect(find.text('Mis cotizaciones'), findsOneWidget);
    });

    testWidgets('si se cancela el diálogo no se convierte', (tester) async {
      final env = await _openQuote(tester, _quote());

      await _tapButton(tester, 'Comprar');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(env.quotesRemote.converted, isEmpty);
    });

    testWidgets('si el servidor la rechaza muestra el motivo y se queda', (tester) async {
      final env = await _openQuote(tester, _quote());
      env.quotesRemote.convertFailure =
          const ServerException('Esta cotización no puede convertirse a compra', '422');

      await _tapButton(tester, 'Comprar');
      await tester.tap(find.text('Sí, convertir'));
      await tester.pumpAndSettle();

      expect(find.text('Esta cotización no puede convertirse a compra'), findsOneWidget);
      expect(find.text('Cotización 2026-00025'), findsWidgets);
    });

    testWidgets('no se ofrece si el servidor no la deja convertir o está cancelada',
        (tester) async {
      await _openQuote(tester, _quote(canConvert: false));
      expect(find.text('Comprar'), findsNothing);
    });

    testWidgets('una cotización cancelada no se compra ni se edita', (tester) async {
      await _openQuote(tester, _quote(status: 'Cancelado'));
      expect(find.text('Comprar'), findsNothing);
      expect(find.text('Editar cotización'), findsNothing);
    });
  });

  group('Editar', () {
    testWidgets('no se ofrece si un vendedor ya la atiende', (tester) async {
      await _openQuote(tester, _quote(editable: false, status: 'En preparación'));
      expect(find.text('Editar cotización'), findsNothing);
      expect(find.text('Cancelar cotización'), findsNothing);
    });

    testWidgets('devuelve los productos al carrito y avisa que se está editando',
        (tester) async {
      final env = await _openQuote(tester, _quote());

      await _tapButton(tester, 'Editar cotización');
      expect(find.text('¿Editar esta cotización?'), findsOneWidget);
      await tester.tap(find.text('Sí, editar'));
      await tester.pumpAndSettle();

      // El carrito quedó solo con los productos de la cotización.
      expect(env.cartRemote.items.map((i) => (i.productId, i.quantity)), [(1, 2)]);
      expect(find.text('Mi carrito'), findsOneWidget);
      expect(find.textContaining('Editando la cotización 2026-00025'), findsOneWidget);

      await tester.tap(find.text('Dejar de editar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Editando la cotización'), findsNothing);
    });

    testWidgets('al generar la cotización manda cuál reemplaza', (tester) async {
      final env = await _openQuote(tester, _quote());
      await _tapButton(tester, 'Editar cotización');
      await tester.tap(find.text('Sí, editar'));
      await tester.pumpAndSettle();

      await _tapButton(tester, 'Cotizar');
      final terms = find.byType(CheckboxListTile);
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pump();
      await _tapButton(tester, 'Continuar al pago');
      await _tapButton(tester, 'Transferencia');
      await _tapButton(tester, 'Generar cotización');

      final order = env.checkoutRemote.lastQuote!;
      expect(order.replacesQuoteId, 25);
      expect(order.items.single.productId, 1);
      expect(order.items.single.quantity, 2);
      expect(find.text('Cotización generada'), findsWidgets);
    });

    testWidgets('sin editar, una cotización nueva no reemplaza nada', (tester) async {
      final env = await _openQuote(tester, _quote());
      // Se entra al checkout desde el carrito, sin pasar por "Editar".
      // (No se usa `pageBack`: busca el tooltip "Back" y la app está en español.)
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Carrito'));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Cotizar');
      final terms = find.byType(CheckboxListTile);
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pump();
      await _tapButton(tester, 'Continuar al pago');
      await _tapButton(tester, 'Transferencia');
      await _tapButton(tester, 'Generar cotización');

      expect(env.checkoutRemote.lastQuote!.replacesQuoteId, isNull);
    });
  });
}
