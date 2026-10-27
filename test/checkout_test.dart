import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/checkout_remote_datasource.dart';
import 'package:appecommerce/data/models/address_model.dart';
import 'package:appecommerce/data/repositories/checkout_repository_impl.dart';
import 'package:appecommerce/data/models/cart_item_model.dart';
import 'package:appecommerce/domain/entities/address_entity.dart';
import 'package:appecommerce/domain/entities/checkout_entity.dart';
import 'package:appecommerce/domain/entities/payment_plan.dart';
import 'package:appecommerce/domain/usecases/checkout_usecases.dart';
import 'package:appecommerce/presentation/providers/cart_provider.dart';

import 'support/fakes.dart';

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar, skipOffstage: false));

const _transfer =
    PaymentTypeEntity(id: 1, name: 'Transferencia', code: 'transferencia');
const _yape = PaymentTypeEntity(id: 2, name: 'Yape', code: 'yape');
const _credit =
    PaymentTypeEntity(id: 3, name: 'Crédito', code: 'credito_autorizado');

AddressModel _address({
  int id = 1,
  String dept = '15',
  String? deptName = 'LIMA',
  bool isDefault = true,
}) =>
    AddressModel(
      id: id,
      recipient: 'ANA PEREZ',
      fullAddress: 'Av. Larco 123',
      ubigeoId: '150122',
      isDefault: isDefault,
      departmentCode: dept,
      provinceCode: '01',
      districtCode: '22',
      department: deptName,
      province: 'LIMA',
      district: 'MIRAFLORES',
    );

DeliveryInfo _delivery({AddressEntity? address, String phone = '951127833'}) =>
    DeliveryInfo(
      recipientName: 'Ana Pérez',
      email: 'ana@correo.com',
      phone: phone,
      address: address ?? _address(),
    );

/// App con sesión iniciada y un carrito con productos en el servidor.
Future<TestEnv> _openCart(
  WidgetTester tester, {
  List<CartItemModel>? items,
  List<AddressModel>? addresses,
}) async {
  final env = TestEnv(catalog: [product(1, 'Driver', price: 100, stock: 9)]);
  await env.authRepo.login('ana@correo.com', 'secreto');
  // Una copia: el doble modifica la lista y una const no se puede cambiar.
  env.cartRemote.items = List.of(items ??
      const [
        CartItemModel(
          productId: 1,
          name: 'Driver',
          price: 100,
          currency: 's',
          quantity: 1,
          stock: 9,
        ),
      ]);
  env.addressesRemote.items = addresses ?? [_address()];

  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
  await tester.pumpAndSettle();
  return env;
}

/// Baja la pantalla hasta que [finder] se construya (las listas son perezosas).
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
    return;
  }
  // Primero hacia abajo; si no está, hacia arriba.
  try {
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable, maxScrolls: 60);
  } catch (_) {
    await tester.scrollUntilVisible(finder, -200, scrollable: scrollable, maxScrolls: 60);
  }
}

/// Escribe en el campo con esa etiqueta, bajando hasta él si hace falta.
Future<void> _enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await _reveal(tester, field);
  await tester.enterText(field, text);
}

/// Llena la entrega y pasa al paso de pago.
Future<void> _goToPayment(WidgetTester tester, {bool quote = false}) async {
  if (!quote) {
    await _enter(tester, 'Teléfono de contacto', '951127833');
  }
  await _reveal(tester, find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await _reveal(tester, find.text('Continuar al pago'));
  await tester.tap(find.text('Continuar al pago'));
  await tester.pumpAndSettle();
}

/// Origen de datos que falla en todo, para probar los valores por defecto.
class _ThrowingRemote extends FakeCheckoutRemote {
  @override
  Future<bool> isGatewayInTestMode() => throw const NetworkException('sin red');

  @override
  Future<double> getCreditAvailable() => throw const NetworkException('sin red');

  @override
  Future<String?> getHolderPhone() => throw const NetworkException('sin red');

  @override
  Future<double?> getExchangeRate() => throw const NetworkException('sin red');
}

void main() {
  group('PaymentPlan', () {
    test('agrega la forma de pago con lo que falta y la quita al repetir', () {
      final plan = PaymentPlan();

      plan.toggle(_transfer, 's', 100);
      expect(plan.amountOf('transferencia', 's'), 100);
      expect(plan.remaining('s', 100), 0);

      plan.toggle(_transfer, 's', 100);
      expect(plan.lines, isEmpty);
    });

    test('un segundo método parte de lo que falta, no del total', () {
      final plan = PaymentPlan();
      plan.toggle(_transfer, 's', 100);
      plan.setAmount('transferencia', 's', 100, 40);

      plan.toggle(_yape, 's', 100);

      expect(plan.amountOf('yape', 's'), 60);
      expect(plan.isBalanced({'s': 100}), isTrue);
    });

    test('el monto no puede pasar de lo que falta', () {
      final plan = PaymentPlan();
      plan.toggle(_transfer, 's', 100);
      plan.toggle(_yape, 's', 100); // ya no falta nada: queda en 0

      plan.setAmount('yape', 's', 100, 500);
      expect(plan.amountOf('yape', 's'), 0);

      plan.setAmount('transferencia', 's', 100, 70);
      plan.setAmount('yape', 's', 100, 500);
      expect(plan.amountOf('yape', 's'), 30);
    });

    test('el crédito se limita al disponible', () {
      final plan = PaymentPlan(creditAvailable: 40);

      plan.toggle(_credit, 's', 100);
      expect(plan.amountOf('credito_autorizado', 's'), 40);

      plan.toggle(_yape, 's', 100);
      expect(plan.amountOf('yape', 's'), 60);
      expect(plan.isBalanced({'s': 100}), isTrue);
    });

    test('el crédito solo se ofrece desde 1', () {
      expect(PaymentPlan(creditAvailable: 0.5).creditOffered, isFalse);
      expect(PaymentPlan(creditAvailable: 1).creditOffered, isTrue);
    });

    test('cada moneda debe cuadrar por separado', () {
      final plan = PaymentPlan();
      plan.toggle(_transfer, 's', 100);

      expect(plan.isBalanced({'s': 100, 'd': 20}), isFalse);

      plan.toggle(_transfer, 'd', 20);
      expect(plan.isBalanced({'s': 100, 'd': 20}), isTrue);

      plan.setAmount('transferencia', 'd', 20, 19.99);
      expect(plan.isBalanced({'s': 100, 'd': 20}), isFalse);
    });

    test('tolera diferencias de redondeo menores a un centavo', () {
      final plan = PaymentPlan();
      plan.toggle(_transfer, 's', 33.333);
      expect(plan.isBalanced({'s': 33.333}), isTrue);
    });

    test('una línea en 0 no cuenta ni se envía', () {
      final plan = PaymentPlan();
      plan.toggle(_transfer, 's', 100);
      plan.setAmount('transferencia', 's', 100, 0);

      expect(plan.effectiveLines, isEmpty);
      expect(plan.isBalanced({'s': 100}), isFalse);
      expect(plan.isBalanced({}), isFalse);
    });

    test('quita las monedas que ya no están en el carrito', () {
      final plan = PaymentPlan();
      plan.toggle(_transfer, 's', 100);
      plan.toggle(_transfer, 'd', 20);

      plan.keepOnly(['s']);

      expect(plan.lines.map((l) => l.currency), ['s']);
    });
  });

  group('Reglas de entrega', () {
    test('delivery en Lima y envío a provincia en el resto', () {
      expect(_delivery().shippingMethod, 'delivery');
      expect(_delivery().shippingLabel, 'Delivery');

      final arequipa = _delivery(address: _address(dept: '04'));
      expect(arequipa.shippingMethod, 'envio_provincia');
      expect(arequipa.shippingLabel, 'Envío a provincia');
    });

    test('valida contacto como la web', () {
      expect(validateDelivery(_delivery()), isNull);
      expect(validateDelivery(_delivery(), contactRequired: true), isNull);

      expect(
        validateDelivery(_delivery(phone: '12'), contactRequired: true),
        contains('teléfono'),
      );
      // Al cotizar el teléfono es opcional.
      expect(validateDelivery(_delivery(phone: '')), isNull);
    });

    test('el crédito se reconoce por sus tres códigos, sin mayúsculas', () {
      for (final code in ['credito_autorizado', 'CREDITO', 'Crédito']) {
        expect(PaymentTypeEntity.isCreditCode(code), isTrue, reason: code);
      }
      expect(PaymentTypeEntity.isCreditCode('yape'), isFalse);
    });
  });

  group('CheckoutRemoteDataSource', () {
    late Map<String, dynamic> sent;
    late String sentPath;

    CheckoutRemoteDataSourceImpl source(
      http.Response Function(http.Request) handler,
    ) =>
        CheckoutRemoteDataSourceImpl(ApiClient(
          client: MockClient((r) async {
            sentPath = r.url.path;
            if (r.body.isNotEmpty) sent = jsonDecode(r.body) as Map<String, dynamic>;
            return handler(r);
          }),
          isConnected: () async => true,
        ));

    http.Response json(Object body, [int status = 200]) =>
        http.Response.bytes(utf8.encode(jsonEncode(body)), status);

    test('la cotización manda ubicación por códigos, forma de envío y costo 0',
        () async {
      final remote = source((_) => json({
            'cotizaciones': [
              {'codigo_cotizacion': '2026-00001', 'pedido_codigo': 'P-1', 'moneda': 's', 'total': '100.00'},
            ],
          }, 201));

      final quotes = await remote.createQuotes(QuoteOrder(
        items: const [
          CartItemModel(productId: 7, name: 'Driver', price: 100, quantity: 2, stock: 9),
        ],
        delivery: _delivery(),
        payments: const [
          PaymentLine(type: 'transferencia', currency: 's', amount: 200),
        ],
      ));

      expect(sentPath, endsWith('/cotizaciones/ecommerce'));
      expect(sent['productos'], [
        {'producto_id': 7, 'cantidad': 2},
      ]);
      expect(sent['metodos_pago'], [
        {'tipo': 'transferencia', 'moneda': 's', 'monto': 200.0},
      ]);
      expect(sent['metodo_pago_preferido'], 'transferencia');
      expect(sent['forma_envio'], 'delivery');
      expect(sent['costo_envio'], 0);
      expect(sent['departamento_id'], '15');
      expect(sent['provincia_id'], '1501');
      expect(sent['distrito_id'], '150122');
      expect(sent['ubicacion_completa'], 'MIRAFLORES, LIMA, LIMA');
      // La cotización no admite cupón.
      expect(sent.containsKey('cupon_codigo'), isFalse);
      expect(quotes.single.code, '2026-00001');
      expect(quotes.single.total, 100);
    });

    test('el pago envía solo token, marca y últimos 4 de la tarjeta', () async {
      final remote = source((_) => json({
            'aprobado': true,
            'mensaje': 'Pago aprobado',
            'pago': {
              'codigo': 'PAGO-1',
              'estado_proceso': 'pendiente_facturar',
              'total': 100,
              'simulado': true,
              'referencia_pasarela': 'SIM-1',
              'tarjeta_marca': 'Visa',
              'tarjeta_ultimos4': '1111',
              'items': [],
            },
          }));

      final result = await remote.pay(PaymentOrder(
        delivery: _delivery(),
        currency: 'd',
        couponCode: 'PROMO10',
        card: const CardPayment(
          token: 'tok_test_aprobado',
          brand: 'Visa',
          last4: '1111',
        ),
      ));

      expect(sentPath, endsWith('/pago-en-linea/pagar'));
      expect(sent['token'], 'tok_test_aprobado');
      expect(sent['tarjeta_marca'], 'Visa');
      expect(sent['tarjeta_ultimos4'], '1111');
      expect(sent['moneda'], 'd');
      expect(sent['cupon_codigo'], 'PROMO10');
      expect(sent['departamento_nombre'], 'LIMA');
      expect(sent['distrito_nombre'], 'MIRAFLORES');
      // Ni el número, ni el vencimiento, ni el CVV viajan.
      final body = jsonEncode(sent);
      expect(body.contains('4111111111111111'), isFalse);
      expect(sent.keys.where((k) => RegExp(r'numero_tarjeta|cvv|venc|titular|^numero$').hasMatch(k)),
          isEmpty);
      expect(result.approved, isTrue);
      expect(result.simulated, isTrue);
      expect(result.purchase?.code, 'PAGO-1');
    });

    test('un pago rechazado es una respuesta, no un error', () async {
      final remote = source((_) => json({
            'aprobado': false,
            'mensaje': 'La tarjeta fue rechazada: fondos insuficientes.',
            'pago': {'codigo': 'PAGO-2', 'estado_proceso': 'pendiente_facturar', 'total': 100, 'items': []},
          }));

      final result = await remote.pay(PaymentOrder(
        delivery: _delivery(),
        card: const CardPayment(token: 'tok_test_rechazado', brand: 'Tarjeta', last4: '0002'),
      ));

      expect(result.approved, isFalse);
      expect(result.message, contains('rechazada'));
    });

    test('un cupón inválido se convierte en el mensaje del servidor', () async {
      final remote = source(
        (_) => json({'valido': false, 'mensaje': 'Cupón no válido o expirado'}),
      );

      expect(
        () => remote.validateCoupon('XX', 100),
        throwsA(isA<ValidationException>()
            .having((e) => e.message, 'message', 'Cupón no válido o expirado')),
      );
    });

    test('un cupón válido trae descuento y total', () async {
      final remote = source((_) => json({
            'valido': true,
            'cupon': {'id': 1, 'codigo': 'PROMO10', 'titulo': '10%'},
            'descuento': 10,
            'total_con_descuento': 90,
          }));

      final coupon = await remote.validateCoupon('PROMO10', 100);

      expect(sent['codigo'], 'PROMO10');
      expect(sent['total'], 100);
      expect(coupon.discount, 10);
      expect(coupon.totalWithDiscount, 90);
    });

    test('el crédito es 0 si la cuenta no está vinculada', () async {
      final unlinked = source((_) => json({'vinculado': false, 'credito_disponible': 0}));
      expect(await unlinked.getCreditAvailable(), 0);

      final linked = source((_) => json({'vinculado': true, 'credito_disponible': '250.50'}));
      expect(await linked.getCreditAvailable(), 250.5);
    });

    test('el tipo de cambio es null si no hay', () async {
      final none = source((_) => json({'disponible': false}));
      expect(await none.getExchangeRate(), isNull);

      final some = source((_) => json({'disponible': true, 'valor_final': 3.775}));
      expect(await some.getExchangeRate(), 3.775);
    });

    test('verificar stock lista lo que falta', () async {
      final remote = source((_) => json({
            'hay_stock': false,
            'faltantes': [
              {'producto_id': 7, 'nombre': 'Driver', 'solicitado': 5, 'disponible': 2},
            ],
          }));

      final check = await remote.verifyStock(const [
        CartItemModel(productId: 7, name: 'Driver', price: 1, quantity: 5, stock: 9),
      ]);

      expect(check.hasStock, isFalse);
      expect(check.shortages.single.available, 2);
    });

    test('un 500 muestra el motivo real que viene en `error`', () async {
      final remote = source((_) => json({
            'status': 'error',
            'message': 'Error al crear cotización',
            'error': 'Los métodos de pago en soles suman 90.00 y el total es 100.00',
          }, 500));

      expect(
        () => remote.createQuotes(QuoteOrder(
          items: const [CartItemModel(productId: 1, name: 'x', price: 1, quantity: 1, stock: 1)],
          delivery: _delivery(),
          payments: const [],
        )),
        throwsA(isA<ServerException>()
            .having((e) => e.message, 'message', contains('suman 90.00'))),
      );
    });
  });

  group('Casos de uso', () {
    const card = CardPayment(token: 't', brand: 'Visa', last4: '1111');

    test('no se paga sin ubicación completa en la dirección', () async {
      final remote = FakeCheckoutRemote();
      final useCase = PayOnlineUseCase(CheckoutRepositoryImpl(remote));

      final result = await useCase(PaymentOrder(
        delivery: _delivery(address: _address(deptName: null)),
        card: card,
      ));

      expect(result.isLeft, isTrue);
      expect(result.left.message, contains('departamento, provincia y distrito'));
      expect(remote.lastPayment, isNull);
    });

    test('no se paga sin teléfono válido', () async {
      final remote = FakeCheckoutRemote();
      final useCase = PayOnlineUseCase(CheckoutRepositoryImpl(remote));

      final result =
          await useCase(PaymentOrder(delivery: _delivery(phone: '1'), card: card));

      expect(result.left.message, contains('teléfono'));
      expect(remote.lastPayment, isNull);
    });

    test('no se cotiza con el carrito vacío', () async {
      final remote = FakeCheckoutRemote();
      final useCase = CreateQuotesUseCase(CheckoutRepositoryImpl(remote));

      final result = await useCase(
        QuoteOrder(items: const [], delivery: _delivery(), payments: const []),
      );

      expect(result.left.message, 'Tu carrito está vacío');
      expect(remote.lastQuote, isNull);
    });

    test('un cupón vacío no llama al servidor', () async {
      final remote = FakeCheckoutRemote();
      final useCase = ValidateCouponUseCase(CheckoutRepositoryImpl(remote));

      final result = await useCase('  ', 100);

      expect(result.isLeft, isTrue);
      expect(remote.couponsAsked, isEmpty);
    });

    test('los datos auxiliares que fallan no impiden comprar', () async {
      final repo = CheckoutRepositoryImpl(_ThrowingRemote());

      expect(await repo.isGatewayInTestMode(), isTrue); // por defecto, prueba
      expect(await repo.getCreditAvailable(), 0); // sin dato, sin crédito
      expect(await repo.getHolderPhone(), isNull);
      expect(await repo.getExchangeRate(), isNull);
    });
  });

  group('Pantallas', () {
    testWidgets('como invitado, Pagar y Cotizar piden iniciar sesión',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await _context(tester)
          .read<CartProvider>()
          .add(product(1, 'Driver', price: 25, stock: 9));

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Pagar'), findsOneWidget);
      expect(find.text('Cotizar'), findsOneWidget);

      await tester.tap(find.text('Cotizar'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsWidgets);
      expect(env.checkoutRemote.lastQuote, isNull);
    });

    testWidgets('la entrega elige la predeterminada y muestra la forma de envío',
        (tester) async {
      final env = await _openCart(tester, addresses: [
        _address(id: 1, isDefault: false, dept: '04', deptName: 'AREQUIPA'),
        _address(id: 2),
      ]);
      expect(env, isNotNull);

      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();

      expect(find.text('Dirección de entrega'), findsOneWidget);
      // Elige la predeterminada (Lima): delivery.
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.textContaining('confirmamos'), findsOneWidget);

      // Al elegir la de Arequipa cambia a envío a provincia.
      await tester.tap(find.text('Av. Larco 123').first);
      await tester.pumpAndSettle();
      expect(find.text('Envío a provincia'), findsOneWidget);
    });

    testWidgets('sin aceptar los términos no avanza', (tester) async {
      await _openCart(tester);
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();

      await _enter(tester, 'Teléfono de contacto', '951127833');
      await _reveal(tester, find.text('Continuar al pago'));
      await tester.tap(find.text('Continuar al pago'));
      await tester.pumpAndSettle();

      expect(find.text('Debes aceptar los términos y condiciones'), findsOneWidget);
      expect(find.text('Tarjeta'), findsNothing);
    });

    testWidgets('el teléfono de contacto es obligatorio al pagar',
        (tester) async {
      await _openCart(tester);
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();

      await _reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await _reveal(tester, find.text('Continuar al pago'));
      await tester.tap(find.text('Continuar al pago'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un teléfono válido'), findsOneWidget);
    });

    testWidgets('sin direcciones se ofrece agregar una y no se avanza',
        (tester) async {
      await _openCart(tester, addresses: []);
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Aún no tienes direcciones'), findsOneWidget);
      expect(find.text('Agregar dirección'), findsOneWidget);

      await _enter(tester, 'Teléfono de contacto', '951127833');
      await _reveal(tester, find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await _reveal(tester, find.text('Continuar al pago'));
      await tester.tap(find.text('Continuar al pago'));
      await tester.pumpAndSettle();

      expect(find.text('Elige una dirección de entrega'), findsOneWidget);
    });

    testWidgets('pago aprobado: muestra la compra y recarga el carrito',
        (tester) async {
      final env = await _openCart(tester);
      env.checkoutRemote.holderPhone = '951127833';
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester);

      expect(find.textContaining('Modo de prueba'), findsOneWidget);
      await _reveal(tester, find.text('Pagar S/ 100.00'));
      expect(find.text('Pagar S/ 100.00'), findsOneWidget);

      await _enter(tester, 'Titular de la tarjeta', 'ANA PEREZ');
      await _enter(tester, 'Número de tarjeta', '4111111111111111');
      await _enter(tester, 'Vencimiento (MM/AA)', '1230');
      await _enter(tester, 'CVV', '123');
      await _reveal(tester, find.text('Pagar S/ 100.00'));
      await tester.tap(find.text('Pagar S/ 100.00'));
      await tester.pumpAndSettle();

      final order = env.checkoutRemote.lastPayment!;
      expect(order.card.token, 'tok_test_aprobado');
      expect(order.card.brand, 'Visa');
      expect(order.card.last4, '1111');
      expect(order.currency, isNull); // carrito de una sola moneda
      expect(order.delivery.address.fullAddress, 'Av. Larco 123');

      expect(find.text('¡Compra realizada!'), findsOneWidget);
      expect(find.text('PAGO-2026-00001'), findsOneWidget);
      expect(find.text('Visa •••• 1111'), findsOneWidget);
      expect(find.textContaining('no se realizó ningún cobro'), findsOneWidget);
    });

    testWidgets('pago rechazado: avisa y se queda en el formulario',
        (tester) async {
      final env = await _openCart(tester);
      env.checkoutRemote.declineMessage =
          'La tarjeta fue rechazada: fondos insuficientes.';
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester);

      await _enter(tester, 'Titular de la tarjeta', 'ANA PEREZ');
      await _enter(tester, 'Número de tarjeta', '4000000000000002');
      await _enter(tester, 'Vencimiento (MM/AA)', '1230');
      await _enter(tester, 'CVV', '123');
      await _reveal(tester, find.text('Pagar S/ 100.00'));
      await tester.tap(find.text('Pagar S/ 100.00'));
      await tester.pumpAndSettle();

      expect(env.checkoutRemote.lastPayment!.card.token, 'tok_test_rechazado');
      expect(find.text('Pago rechazado'), findsOneWidget);
      expect(find.textContaining('fondos insuficientes'), findsOneWidget);

      await tester.tap(find.text('Intentar con otra tarjeta'));
      await tester.pumpAndSettle();
      expect(find.text('¡Compra realizada!'), findsNothing);
      await _reveal(tester, find.text('Pagar S/ 100.00'));
      expect(find.text('Pagar S/ 100.00'), findsOneWidget);
    });

    testWidgets('valida la tarjeta: vencimiento vencido y CVV', (tester) async {
      final env = await _openCart(tester);
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester);

      await _enter(tester, 'Titular de la tarjeta', 'ANA PEREZ');
      await _enter(tester, 'Número de tarjeta', '4111111111111111');
      await _enter(tester, 'Vencimiento (MM/AA)', '0120');
      await _enter(tester, 'CVV', '12');
      await _reveal(tester, find.text('Pagar S/ 100.00'));
      await tester.tap(find.text('Pagar S/ 100.00'));
      await tester.pumpAndSettle();

      expect(find.text('La tarjeta está vencida'), findsOneWidget);
      expect(find.text('CVV no válido'), findsOneWidget);
      expect(env.checkoutRemote.lastPayment, isNull);
    });

    testWidgets('el cupón baja el total y se manda en el pago', (tester) async {
      final env = await _openCart(tester);
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester);

      await _enter(tester, 'Cupón de descuento', 'MALO');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(find.text('Cupón no válido o expirado'), findsOneWidget);

      await _enter(tester, 'Cupón de descuento', 'PROMO10');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('Cupón PROMO10 aplicado'), findsOneWidget);
      await _reveal(tester, find.text('Pagar S/ 90.00'));
      expect(find.text('Pagar S/ 90.00'), findsOneWidget);
      expect(env.checkoutRemote.couponsAsked, ['MALO', 'PROMO10']);
    });

    testWidgets('con soles y dólares se elige en qué moneda pagar',
        (tester) async {
      final env = await _openCart(tester, items: const [
        CartItemModel(productId: 1, name: 'En soles', price: 100, currency: 's', quantity: 1, stock: 9),
        CartItemModel(productId: 2, name: 'En dólares', price: 30, currency: 'd', quantity: 1, stock: 9),
      ]);
      expect(env.cartRemote.items, hasLength(2));
      await tester.tap(find.text('Pagar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester);

      await _reveal(tester, find.text('Pagar ahora en'));
      expect(find.text('Pagar ahora en'), findsOneWidget);

      // Con la pantalla arriba, donde el selector se ve completo.
      await tester.tap(find.text('Dólares'));
      await tester.pumpAndSettle();
      // El cupón solo vale en soles.
      await _reveal(tester, find.text('Pagar US\$ 30.00'));
      expect(find.text('Pagar US\$ 30.00'), findsOneWidget);
      expect(find.text('Cupón de descuento'), findsNothing);

      await _enter(tester, 'Titular de la tarjeta', 'ANA PEREZ');
      await _enter(tester, 'Número de tarjeta', '4111111111111111');
      await _enter(tester, 'Vencimiento (MM/AA)', '1230');
      await _enter(tester, 'CVV', '123');
      await _reveal(tester, find.text('Pagar US\$ 30.00'));
      await tester.tap(find.text('Pagar US\$ 30.00'));
      await tester.pumpAndSettle();

      expect(env.checkoutRemote.lastPayment!.currency, 'd');
    });

    testWidgets('cotizar: stock insuficiente ofrece ajustar el carrito',
        (tester) async {
      final env = await _openCart(tester, items: const [
        CartItemModel(productId: 1, name: 'Driver', price: 100, currency: 's', quantity: 5, stock: 9),
      ]);
      env.checkoutRemote.stock = const StockCheck(
        hasStock: false,
        shortages: [
          StockShortage(productId: 1, name: 'Driver', requested: 5, available: 2),
        ],
      );
      await tester.tap(find.text('Cotizar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester, quote: true);

      expect(find.text('Productos sin stock suficiente'), findsOneWidget);
      expect(find.textContaining('pediste 5, quedan 2'), findsOneWidget);

      await tester.tap(find.text('Ajustar'));
      await tester.pumpAndSettle();

      expect(env.cartRemote.items.single.quantity, 2);
    });

    testWidgets('cotizar: el botón se habilita cuando los montos cuadran',
        (tester) async {
      await _openCart(tester);
      await tester.tap(find.text('Cotizar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester, quote: true);

      expect(find.text('Forma de pago'), findsOneWidget);
      // El crédito no se ofrece sin crédito disponible.
      expect(find.text('Crédito'), findsNothing);
      FilledButton button() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Generar cotización'));
      expect(button().onPressed, isNull);
      expect(find.text('Falta S/ 100.00'), findsOneWidget);

      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      expect(find.text('Monto completo'), findsOneWidget);
      expect(button().onPressed, isNotNull);

      // Si se baja el monto vuelve a faltar.
      await tester.enterText(
          find.widgetWithText(TextField, 'Monto con Transferencia'), '60');
      await tester.pumpAndSettle();
      expect(find.text('Falta S/ 40.00'), findsOneWidget);
      expect(button().onPressed, isNull);
    });

    testWidgets('cotizar: crea la cotización, vacía el carrito y muestra el código',
        (tester) async {
      final env = await _openCart(tester);
      env.checkoutRemote.holderPhone = '951127833';
      await tester.tap(find.text('Cotizar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester, quote: true);

      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Generar cotización'));
      await tester.tap(find.text('Generar cotización'));
      await tester.pumpAndSettle();

      final order = env.checkoutRemote.lastQuote!;
      expect(order.items.single.productId, 1);
      expect(order.payments.single.type, 'transferencia');
      expect(order.payments.single.amount, 100);
      expect(order.delivery.phone, '951127833');
      expect(order.delivery.shippingMethod, 'delivery');

      expect(find.text('Cotización generada'), findsWidgets);
      expect(find.text('Cotización 2026-00001'), findsOneWidget);
      // El carrito del servidor quedó vacío.
      expect(env.cartRemote.items, isEmpty);
    });

    testWidgets('cotizar con el crédito disponible', (tester) async {
      final env = await _openCart(tester);
      env.checkoutRemote.credit = 40;
      await tester.tap(find.text('Cotizar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester, quote: true);

      expect(find.text('Crédito'), findsOneWidget);
      await tester.tap(find.text('Crédito'));
      await tester.pumpAndSettle();
      // El crédito cubre solo hasta lo disponible: falta el resto.
      expect(find.text('Falta S/ 60.00'), findsOneWidget);

      await tester.tap(find.text('Yape'));
      await tester.pumpAndSettle();
      expect(find.text('Monto completo'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza la cotización se muestra el motivo',
        (tester) async {
      final env = await _openCart(tester);
      env.checkoutRemote.quoteFailure = const ServerException(
        'Los métodos de pago en soles suman 90.00 y el total es 100.00',
        '500',
      );
      await tester.tap(find.text('Cotizar'));
      await tester.pumpAndSettle();
      await _goToPayment(tester, quote: true);
      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Generar cotización'));
      await tester.tap(find.text('Generar cotización'));
      await tester.pumpAndSettle();

      expect(find.textContaining('suman 90.00'), findsOneWidget);
      // No se vació el carrito: la cotización no se creó.
      expect(env.cartRemote.items, isNotEmpty);
    });
  });
}
