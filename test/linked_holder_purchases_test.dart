import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/auth_local_datasource.dart';
import 'package:appecommerce/data/datasources/auth_remote_datasource.dart';
import 'package:appecommerce/data/models/product_model.dart';
import 'package:appecommerce/data/models/purchase_model.dart';
import 'package:appecommerce/data/models/user_model.dart';
import 'package:appecommerce/presentation/components/components.dart';

import 'support/fakes.dart';

/// Cliente registrado en la tienda como "grupo" y vinculado al ERP como empresa.
const _linkedUser = UserModel(
  id: 7,
  fullName: 'grupo',
  email: 'adelinamarquina77@gmail.com',
  firstNames: 'grupo',
  documentType: 'DNI',
  documentNumber: '12345678',
  erpCode: 'CLI00264',
);

const _erpHolder = HolderModel(
  linked: true,
  name: 'GRUPO MARQUINA E.I.R.L.',
  document: '20601234567',
);

Future<TestEnv> _openAccount(
  WidgetTester tester, {
  UserModel user = testUser,
  HolderModel holder = const HolderModel(linked: false),
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final env = TestEnv(catalog: [product(1, 'Driver')]);
  env.authRemote
    ..loginUser = user
    ..profile = user
    ..holder = holder;
  await env.authRepo.login('ana@correo.com', 'secreto');
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Cuenta'));
  await tester.pumpAndSettle();
  return env;
}

void main() {
  group('Qué nombre y documento se muestran', () {
    test('con la cuenta vinculada, los del cliente del ERP', () {
      final user = _linkedUser.copyWith(
        holderName: 'GRUPO MARQUINA E.I.R.L.',
        holderDocument: '20601234567',
      );

      expect(user.displayName, 'GRUPO MARQUINA E.I.R.L.');
      expect(user.displayDocument, '20601234567');
      expect(user.displayDocumentLabel, 'RUC');
    });

    test('sin vincular, los del cliente registrado en la tienda', () {
      const user = UserModel(
        id: 1,
        fullName: 'Ana Pérez',
        email: 'ana@correo.com',
        documentType: 'DNI',
        documentNumber: '12345678',
      );

      expect(user.displayName, 'Ana Pérez');
      expect(user.displayDocument, '12345678');
      expect(user.displayDocumentLabel, 'DNI');
    });

    test('un titular guardado pero sin código ERP no se usa', () {
      const user = UserModel(
        id: 1,
        fullName: 'Ana Pérez',
        email: 'ana@correo.com',
        holderName: 'DE OTRO',
      );

      expect(user.displayName, 'Ana Pérez');
    });

    test('vinculada pero sin datos del ERP todavía, usa los del registro', () {
      expect(_linkedUser.displayName, 'grupo');
      expect(_linkedUser.displayDocument, '12345678');
    });

    test('el documento provisional de una cuenta de Google no se muestra', () {
      const user = UserModel(
        id: 1,
        fullName: 'Ana Google',
        email: 'ana@gmail.com',
        documentNumber: 'GOOGLE_1762300000',
      );

      expect(user.displayDocument, isNull);
    });

    test('la etiqueta depende de los dígitos: 8 DNI, 11 RUC, otro el tipo', () {
      UserModel conDocumento(String? doc, {String? type}) => UserModel(
            id: 1,
            fullName: 'X',
            email: 'x@x.com',
            documentType: type,
            documentNumber: doc,
          );

      expect(conDocumento('12345678').displayDocumentLabel, 'DNI');
      expect(conDocumento('20123456789').displayDocumentLabel, 'RUC');
      expect(conDocumento('A1234', type: 'CE').displayDocumentLabel, 'CE');
      expect(conDocumento(null).displayDocumentLabel, 'Documento');
    });

    test('las iniciales salen del nombre que se muestra', () {
      final user = _linkedUser.copyWith(holderName: 'MARQUINA SAC');

      expect(_linkedUser.initials, 'G');
      expect(user.initials, 'MS');
    });

    test('copyWith conserva el titular y clearHolder lo quita', () {
      final user = _linkedUser.copyWith(holderName: 'EMPRESA', holderDocument: '2060');

      expect(user.copyWith(phone: '911222333').holderName, 'EMPRESA');
      expect(user.copyWith(clearHolder: true).holderName, isNull);
      expect(user.copyWith(clearHolder: true).holderDocument, isNull);
    });

    test('el titular se guarda en el equipo y se recupera', () {
      final user = UserModel.fromEntity(
        _linkedUser.copyWith(holderName: 'EMPRESA SAC', holderDocument: '20601234567'),
      );

      final copy = UserModel.decode(user.encode());

      expect(copy.holderName, 'EMPRESA SAC');
      expect(copy.holderDocument, '20601234567');
    });
  });

  group('Datos: el titular', () {
    test('lee al cliente del ERP de /cliente/titular', () async {
      late http.Request sent;
      final client = ApiClient(
        client: MockClient((r) async {
          sent = r;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'vinculado': true,
              'origen': 'erp',
              'codigo_erp': 'CLI00264',
              'nombre': 'GRUPO MARQUINA E.I.R.L.',
              'documento': '20601234567',
            })),
            200,
          );
        }),
      )..authToken = '1|x';

      final holder = await AuthRemoteDataSourceImpl(client).getHolder();

      expect(sent.url.path, endsWith('/cliente/titular'));
      expect(holder.linked, isTrue);
      expect(holder.name, 'GRUPO MARQUINA E.I.R.L.');
      expect(holder.document, '20601234567');
    });

    test('sin vincular el servidor responde con los datos del registro', () {
      final holder = HolderModel.fromJson({
        'vinculado': false,
        'nombre': 'Ana Pérez',
        'documento': '  ',
      });

      expect(holder.linked, isFalse);
      expect(holder.name, 'Ana Pérez');
      expect(holder.document, isNull);
    });
  });

  group('Cabecera de la cuenta', () {
    testWidgets('vinculada: muestra el nombre y el documento del cliente del ERP',
        (tester) async {
      await _openAccount(tester, user: _linkedUser, holder: _erpHolder);

      expect(find.text('Hola, Grupo Marquina E.i.r.l.'), findsOneWidget);
      expect(find.text('RUC: 20601234567'), findsOneWidget);
      expect(find.text('Cuenta vinculada · CLI00264'), findsOneWidget);
      // Ya no sale el nombre con que se registró.
      expect(find.text('Hola, Grupo'), findsNothing);
    });

    testWidgets('sin vincular: muestra el nombre del cliente registrado',
        (tester) async {
      await _openAccount(tester, holder: const HolderModel(linked: false));

      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      expect(find.text('DNI: 12345678'), findsOneWidget);
      expect(find.textContaining('Cuenta vinculada'), findsNothing);
    });

    testWidgets('si no se puede leer al titular, usa lo registrado y no falla',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.authRemote
        ..loginUser = _linkedUser
        ..holderFailure = Exception('sin red');
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Grupo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al iniciar sesión se pide el titular una vez', (tester) async {
      final env = await _openAccount(tester, user: _linkedUser, holder: _erpHolder);

      // Al abrir con la sesión ya iniciada se lee al restaurarla.
      expect(env.authRemote.holderCalls, greaterThanOrEqualTo(1));
      expect(env.authLocal.session?.user.holderName, 'GRUPO MARQUINA E.I.R.L.');
    });

    testWidgets('si la cuenta deja de estar vinculada, el nombre vuelve al registrado',
        (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.authRemote
        ..loginUser = _linkedUser
        ..holder = const HolderModel(linked: false);
      await env.authRepo.login('ana@correo.com', 'secreto');
      // Se guardó antes un titular que ya no existe.
      env.authLocal.session = StoredSession(
        env.authLocal.session!.token,
        UserModel.fromEntity(_linkedUser.copyWith(holderName: 'EMPRESA VIEJA')),
      );

      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Grupo'), findsOneWidget);
      expect(find.textContaining('Empresa Vieja'), findsNothing);
    });

    testWidgets('Datos personales también muestra los del cliente vinculado',
        (tester) async {
      await _openAccount(tester, user: _linkedUser, holder: _erpHolder);

      await tester.tap(find.text('Datos personales'));
      await tester.pumpAndSettle();

      expect(find.text('GRUPO MARQUINA E.I.R.L.'), findsOneWidget);
      expect(find.text('RUC'), findsOneWidget);
      expect(find.text('20601234567'), findsOneWidget);
    });
  });

  group('Compras con imagen, marca y código', () {
    PurchaseModel online() => PurchaseModel.fromJson({
          'codigo': 'PAGO-1',
          'estado_proceso': 'facturado',
          'fecha': '2026-10-20T15:30:00Z',
          'moneda': 's',
          'subtotal': 100,
          'total': 100,
          'items': [
            {
              'producto_id': 1,
              'codigo_producto': 'DRV2',
              'nombre': '1.5" DRIVER 2VC',
              'marca': '7POWER',
              'imagen_url': 'http://api.test/storage/productos/d.jpg',
              'cantidad': 2,
              'precio_unitario': 50,
              'subtotal': 100,
            },
          ],
        });

    test('los productos de una compra en línea traen la marca', () {
      final item = online().items.single;

      expect(item.brand, '7POWER');
      expect(item.code, 'DRV2');
      expect(item.imageUrl, contains('d.jpg'));
    });

    test('los de una compra en tienda traen foto y marca del catálogo', () {
      final store = StorePurchasesModel.fromJson({
        'vinculado': true,
        'compras': [
          {
            'id': 1,
            'documento': 'V001-7262',
            'moneda': 's',
            'total': 25,
            'productos': [
              {
                'codigo': 'CAR1',
                'nombre': 'CARGADOR DE CELULAR PARED',
                'cantidad': 1,
                'precio': 11,
                'subtotal': 11,
                'imagen_url': 'http://api.test/storage/productos/c.jpg',
                'marca': '7POWER',
              },
              {
                'codigo': 'MERCH',
                'nombre': 'MERCHANDISING',
                'cantidad': 3,
                'precio': 50,
                'subtotal': 0,
                'imagen_url': null,
                'marca': null,
              },
            ],
          },
        ],
      });

      final items = store.sales.single.items;
      expect(items[0].brand, '7POWER');
      expect(items[0].imageUrl, contains('c.jpg'));
      expect(items[1].brand, isNull);
      expect(items[1].imageUrl, isNull);
    });

    testWidgets('el detalle de una compra en línea muestra marca, código y unidades',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.purchasesRemote.online = [online()];
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compras'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PAGO-1'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(PurchaseItemTile),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('7POWER'), findsOneWidget);
      expect(find.text('1.5" DRIVER 2VC'), findsOneWidget);
      expect(find.text('Código: DRV2'), findsOneWidget);
      expect(find.text('2 un.'), findsOneWidget);
      expect(find.text('S/ 50.00 c/u'), findsOneWidget);
      expect(find.byType(ProductImage), findsWidgets);
    });

    testWidgets(
        'si el servidor no manda marca ni foto, se completan con el catálogo por código',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [
        const ProductModel(
          id: 9,
          name: 'CARGADOR DE CELULAR PARED',
          price: 11,
          stock: 5,
          brand: 'PIONEER',
          code: 'CAR1',
          imageUrl: 'http://api.test/storage/productos/c.jpg',
        ),
        product(3, 'Cable', brand: 'JBL'),
      ]);
      env.purchasesRemote.store = StorePurchasesModel.fromJson({
        'vinculado': true,
        'compras': [
          {
            'id': 1,
            'documento': 'V001-7310',
            'moneda': 's',
            'total': 14,
            'productos': [
              // Como viene del ERP: solo el código.
              {'codigo': 'CAR1', 'nombre': 'CARGADOR', 'cantidad': 1, 'precio': 11, 'subtotal': 11},
              // Un código que no está en el catálogo: se queda sin marca.
              {'codigo': 'MERCH', 'nombre': 'MERCHANDISING', 'cantidad': 1, 'precio': 3, 'subtotal': 3},
            ],
          },
        ],
      });
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compras'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('En tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('V001-7310'));
      await tester.pumpAndSettle();

      expect(find.text('PIONEER'), findsOneWidget);
      expect(find.text('Código: CAR1'), findsOneWidget);
      // El que no está en el catálogo se muestra igual, sin marca.
      expect(find.text('MERCHANDISING'), findsOneWidget);
      expect(find.text('Código: MERCH'), findsOneWidget);
      // Cada código se pidió una sola vez.
      expect(
        env.products.searchRequests.where((r) => r.$1 == 'CAR1'),
        hasLength(1),
      );
    });

    testWidgets('si la compra ya trae marca y foto no se consulta el catálogo',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(3, 'Cable', brand: 'JBL')]);
      env.purchasesRemote.store = StorePurchasesModel.fromJson({
        'vinculado': true,
        'compras': [
          {
            'id': 1,
            'documento': 'V001-1',
            'moneda': 's',
            'total': 11,
            'productos': [
              {
                'codigo': 'CAR1',
                'nombre': 'CARGADOR',
                'cantidad': 1,
                'precio': 11,
                'subtotal': 11,
                'marca': '7POWER',
                'imagen_url': 'http://api.test/storage/productos/c.jpg',
              },
            ],
          },
        ],
      });
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compras'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('En tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('V001-1'));
      await tester.pumpAndSettle();

      expect(find.text('7POWER'), findsOneWidget);
      expect(env.products.searchRequests, isEmpty);
    });

    testWidgets('el detalle de una compra en tienda también', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      env.purchasesRemote.store = StorePurchasesModel.fromJson({
        'vinculado': true,
        'compras': [
          {
            'id': 1,
            'documento': 'V001-7262',
            'fecha': '2026-11-06 14:42:09',
            'moneda': 's',
            'total': 11,
            'productos': [
              {
                'codigo': 'CAR1',
                'nombre': 'CARGADOR DE CELULAR PARED',
                'cantidad': 1,
                'precio': 11,
                'subtotal': 11,
                'imagen_url': 'http://api.test/storage/productos/c.jpg',
                'marca': '7POWER',
              },
              {
                'codigo': 'MERCH',
                'nombre': 'MERCHANDISING',
                'cantidad': 3,
                'precio': 50,
                'subtotal': 0,
              },
            ],
          },
        ],
      });
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compras'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('En tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('V001-7262'));
      await tester.pumpAndSettle();

      // Con marca, código y foto.
      expect(find.text('7POWER'), findsOneWidget);
      expect(find.text('Código: CAR1'), findsOneWidget);
      expect(find.text('1 un.'), findsOneWidget);
      // Sin marca ni foto en el catálogo: se muestra igual, solo con lo que hay.
      expect(find.text('MERCHANDISING'), findsOneWidget);
      expect(find.text('Código: MERCH'), findsOneWidget);
      expect(find.text('3 un.'), findsOneWidget);
      expect(find.text('S/ 50.00 c/u'), findsOneWidget);
      expect(find.byType(PurchaseItemTile), findsNWidgets(2));
    });
  });
}
