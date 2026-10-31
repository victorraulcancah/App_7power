import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/statement_remote_datasource.dart';
import 'package:appecommerce/data/models/user_model.dart';
import 'package:appecommerce/data/repositories/statement_repository_impl.dart';
import 'package:appecommerce/domain/entities/statement_entity.dart';
import 'package:appecommerce/domain/usecases/statement_usecases.dart';

import 'support/fakes.dart';

AccountMovement _row(Map<String, dynamic> json) => movementFromJson(json);

AccountMovement _sale(int n, {double amount = 100, String name = 'DRIVER'}) =>
    AccountMovement(
      id: 's-$n',
      date: DateTime(2026, 10, n),
      document: 'V001-000$n',
      description: 'COD$n | $name | 7POWER',
      quantity: 1,
      soles: amount,
      dollars: 0,
    );

Future<TestEnv> _openStatement(
  WidgetTester tester, {
  List<AccountMovement>? movements,
  String? erpCode = 'CLI00118',
  int pageSize = 10,

  /// Pantalla alta: la lista cabe entera. Con false se usa la de siempre y
  /// hay que bajar para ver más.
  bool tall = true,
}) async {
  if (tall) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  final env = TestEnv();
  env.authRemote.loginUser = UserModel(
    id: 7,
    fullName: 'Ana Pérez',
    email: 'ana@correo.com',
    erpCode: erpCode,
  );
  env.statementRemote.pageSize = pageSize;
  env.statementRemote.movements =
      movements ?? [_sale(1), _sale(2, name: 'PARLANTE'), _sale(3)];
  await env.authRepo.login('ana@correo.com', 'secreto');
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Estado de cuenta'));
  await tester.pumpAndSettle();
  return env;
}

void main() {
  group('Lectura de movimientos (reglas del ERP)', () {
    test('una venta en soles con boleta: documento con serie y número', () {
      final m = _row({
        'id': 's-1',
        'created_at': '2026-10-05T10:00:00Z',
        'cantidad': 4,
        'dolares': false,
        'subtotal_con_dto': '800.00',
        'sale': {
          'estado': true,
          'boleta': {'tipo': 'f', 'serie': 1, 'numero': 123},
        },
        'product': {
          'codigo': 'XR2500.4',
          'name': 'AMPLIFICADOR',
          'brand': {'name': '7POWER'},
        },
      });

      expect(m.document, 'F001-0123');
      expect(m.description, 'XR2500.4 | AMPLIFICADOR | 7POWER');
      expect(m.quantity, 4);
      expect([m.soles, m.dollars], [800, 0]);
      expect(m.isPayment, isFalse);
      expect(m.isRed, isFalse);
    });

    test('una venta sin comprobante es "V001-" con el número de 4 dígitos', () {
      final m = _row({
        'id': 's-2',
        'subtotal_con_dto': 50,
        'sale': {'nro_documento': 99, 'boleta': null, 'estado': true},
        'product': {'codigo': 'A', 'name': 'B'},
      });

      expect(m.document, 'V001-0099');
      // Sin marca se muestra "-".
      expect(m.description, 'A | B | -');
    });

    test('una venta en dólares va en la columna de dólares', () {
      final m = _row({
        'id': 's-3',
        'dolares': true,
        'subtotal_con_dto': 120,
        'sale': {'nro_documento': 1, 'estado': true},
        'product': {'codigo': 'A', 'name': 'B'},
      });

      expect([m.soles, m.dollars], [0, 120]);
    });

    test('un pago: "Pagó con", en rojo, y la moneda sale de la venta', () {
      final soles = _row({
        'id': 'p-1',
        'monto': 300,
        'payment_method': {'name': 'YAPE'},
        'sale': {'total_dolares': 0, 'nro_documento': 5},
      });
      final dolares = _row({
        'id': 'p-2',
        'monto': 80,
        'payment_method': {'name': 'BCP'},
        'sale': {'total_dolares': 200, 'nro_documento': 6},
      });

      expect(soles.description, 'Pagó con YAPE');
      expect(soles.isPayment, isTrue);
      expect(soles.isRed, isTrue);
      expect([soles.soles, soles.dollars], [300, 0]);
      expect([dolares.soles, dolares.dollars], [0, 80]);
    });

    test('un pago agregado no tiene documento y su moneda es "moneda"', () {
      final m = _row({
        'id': 'a-1',
        'type': 'payment_seller_aggregated',
        'total_sumado': '450.5',
        'moneda': 'dolares',
        'sale': {'nro_documento': 5},
      });

      expect(m.document, '-');
      expect(m.isPayment, isTrue);
      expect([m.soles, m.dollars], [0, 450.5]);
    });

    test('una venta anulada se marca', () {
      final m = _row({
        'id': 's-4',
        'subtotal_con_dto': 10,
        'sale': {'nro_documento': 2, 'estado': false},
        'product': {'codigo': 'A', 'name': 'B'},
      });

      expect(m.isVoided, isTrue);
      expect(m.isRed, isTrue);
    });

    test('el resumen lee crédito, deuda y deuda anterior', () {
      final page = statementFromJson({
        'codigo': 'CLI00118',
        'deudaTotalSoles': 7450,
        'deudaTotalDolares': '12.5',
        'deuda_anterior_soles': 300,
        'deuda_anterior_dolares': 0,
        'client': {
          'credito': 15000,
          'linea_utilizada': 7450,
          'credito_disponible': -339376.54,
        },
        'data': [],
        'total': 1313,
      });

      expect(page.total, 1313);
      expect(page.summary.creditLimit, 15000);
      expect(page.summary.creditUsed, 7450);
      expect(page.summary.creditAvailable, -339376.54);
      expect([page.summary.debtSoles, page.summary.debtDollars], [7450, 12.5]);
      expect(page.summary.hasPreviousDebt, isTrue);
    });
  });

  group('Consulta al ERP', () {
    test('usa el dominio del ERP y manda código, fechas y paginación', () async {
      late Uri uri;
      final remote = StatementRemoteDataSourceImpl(ApiClient(
        baseUrl: 'http://erp.test/api',
        client: MockClient((r) async {
          uri = r.url;
          return http.Response.bytes(
            utf8.encode(jsonEncode({'data': [], 'total': 0, 'client': {}})),
            200,
          );
        }),
        isConnected: () async => true,
      ));

      await remote.getStatement(
        erpCode: 'CLI00118',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        page: 2,
      );

      expect(uri.host, 'erp.test');
      expect(uri.path, '/api/ecommerce/estado-de-cuenta');
      expect(uri.queryParameters, {
        'codigo': 'CLI00118',
        'agrupado': 'false',
        'fechas[0]': '2026-10-01',
        'fechas[1]': '2026-10-31',
        'pagination[current]': '2',
        'pagination[pageSize]': '50',
      });
    });

    test('el mensaje de error del ERP llega al cliente', () async {
      final remote = StatementRemoteDataSourceImpl(ApiClient(
        baseUrl: 'http://erp.test/api',
        client: MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({'error': 'Código de cliente no encontrado'})),
              404,
            )),
        isConnected: () async => true,
      ));

      expect(
        remote.getStatement(erpCode: 'X', from: DateTime(2026), to: DateTime(2026)),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Código de cliente no encontrado',
        )),
      );
    });
  });

  group('Reglas', () {
    final useCase = GetStatementUseCase(StatementRepositoryImpl(FakeStatementRemote()));

    test('sin código de ERP no se consulta', () async {
      final result = await useCase(
        erpCode: null,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );

      expect(result.isLeft, isTrue);
      expect(result.left.message, contains('no está vinculada'));
    });

    test('el rango no puede terminar antes de empezar', () async {
      final result = await useCase(
        erpCode: 'CLI1',
        from: DateTime(2026, 10, 31),
        to: DateTime(2026, 10, 1),
      );

      expect(result.isLeft, isTrue);
    });
  });

  group('Pantalla', () {
    testWidgets('muestra el resumen y los movimientos del mes en curso', (tester) async {
      final env = await _openStatement(tester, pageSize: 2);

      expect(env.statementRemote.lastCode, 'CLI00118');
      final now = DateTime.now();
      expect(env.statementRemote.lastFrom, DateTime(now.year, now.month, 1));
      expect(env.statementRemote.lastTo, DateTime(now.year, now.month, now.day));

      expect(find.text('S/ 15,000.00'), findsOneWidget); // línea de crédito
      expect(find.text('S/ 7,550.00'), findsOneWidget); // disponible
      expect(find.text('COD1 | DRIVER | 7POWER'), findsOneWidget);
      expect(find.text('COD2 | PARLANTE | 7POWER'), findsOneWidget);
      // Como la pantalla es alta y lo cargado no la llena, sigue pidiendo
      // páginas hasta tener todo.
      expect(env.statementRemote.pagesAsked, [1, 2]);
      expect(find.text('COD3 | DRIVER | 7POWER'), findsOneWidget);
      expect(find.text('Mostrando 3 de 3 movimientos'), findsOneWidget);
    });

    testWidgets('al bajar pide la página siguiente', (tester) async {
      final env = await _openStatement(
        tester,
        movements: [for (var i = 1; i <= 40; i++) _sale(i)],
        pageSize: 15,
        tall: false,
      );
      // Con 15 filas ya hay scroll: no se piden más hasta bajar.
      expect(env.statementRemote.pagesAsked, [1]);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
      await tester.pumpAndSettle();

      // Pidió la 2 al llegar abajo y siguió (la 3) al volver a llegar.
      expect(env.statementRemote.pagesAsked.take(2), [1, 2]);
      expect(env.statementRemote.pagesAsked, isNot(contains(4)));
    });

    testWidgets('el buscador filtra por la descripción', (tester) async {
      await _openStatement(tester);

      await tester.enterText(find.byType(TextField), 'parlante');
      await tester.pumpAndSettle();

      expect(find.text('COD2 | PARLANTE | 7POWER'), findsOneWidget);
      expect(find.text('COD1 | DRIVER | 7POWER'), findsNothing);
    });

    testWidgets('los pagos y las ventas anuladas se marcan', (tester) async {
      await _openStatement(tester, movements: [
        const AccountMovement(
          id: 'p-1',
          document: '-',
          description: 'Pagó con YAPE',
          soles: 300,
          dollars: 0,
          isPayment: true,
        ),
        AccountMovement(
          id: 's-9',
          date: DateTime(2026, 10, 9),
          document: 'V001-0009',
          description: 'COD9 | X | -',
          soles: 10,
          dollars: 0,
          isVoided: true,
        ),
        const AccountMovement(
          id: 's-10',
          document: 'V001-0010',
          description: 'COD10 | EN DÓLARES | -',
          soles: 0,
          dollars: 120,
        ),
      ]);

      expect(find.text('Pagó con YAPE'), findsOneWidget);
      expect(find.textContaining('Anulada'), findsOneWidget);
      expect(find.text('US\$ 120.00'), findsOneWidget);
    });

    testWidgets('sin código de ERP avisa que la cuenta no está vinculada', (tester) async {
      final env = await _openStatement(tester, erpCode: null);

      expect(find.text('Tu cuenta aún no está vinculada'), findsOneWidget);
      expect(env.statementRemote.lastCode, isNull);
    });

    testWidgets('si el ERP falla muestra el motivo y permite reintentar', (tester) async {
      final env = TestEnv();
      env.authRemote.loginUser = const UserModel(
        id: 7,
        fullName: 'Ana Pérez',
        email: 'ana@correo.com',
        erpCode: 'CLI00118',
      );
      env.statementRemote.failure =
          const ServerException('Error interno del servidor', '500');
      env.statementRemote.movements = [_sale(1)];
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estado de cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Error interno del servidor'), findsOneWidget);

      env.statementRemote.failure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('COD1 | DRIVER | 7POWER'), findsOneWidget);
    });
  });
}
