import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/data/models/address_model.dart';
import 'package:appecommerce/data/models/product_model.dart';
import 'package:appecommerce/data/models/purchase_model.dart';
import 'package:appecommerce/data/models/quote_model.dart';
import 'package:appecommerce/data/models/user_model.dart';
import 'package:appecommerce/domain/entities/purchase_entity.dart';
import 'package:appecommerce/presentation/providers/auth_provider.dart';

import 'support/fakes.dart';

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar, skipOffstage: false));

/// App con una sesión iniciada, en la pestaña Cuenta.
Future<void> _openAccount(WidgetTester tester, TestEnv env) async {
  await env.authRepo.login('ana@correo.com', 'secreto');
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
}

Future<void> _openSection(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

ProductModel _favorite(int id, String name, {int stock = 5}) => ProductModel(
      id: id,
      name: name,
      price: 25,
      currency: 's',
      stock: stock,
    );

AddressModel _address(
  int id,
  String text, {
  bool isDefault = false,
}) =>
    AddressModel(
      id: id,
      recipient: 'ANA PEREZ',
      fullAddress: text,
      ubigeoId: '150122',
      isDefault: isDefault,
      departmentCode: '15',
      provinceCode: '01',
      districtCode: '22',
      department: 'LIMA',
      province: 'LIMA',
      district: 'MIRAFLORES',
    );

QuoteModel _quote(
  int id, {
  String status = 'En espera',
  bool editable = true,
}) =>
    QuoteModel(
      id: id,
      code: '2026-0000$id',
      status: status,
      total: 150,
      currency: 's',
      editable: editable,
      items: const [],
    );

void main() {
  group('Modelos', () {
    test('la foto del cliente se normaliza a una URL absoluta', () {
      UserModel user(Object? foto, {String key = 'foto'}) => UserModel.fromJson({
            'id': 1,
            'nombre_completo': 'Ana',
            'email': 'a@a.com',
            key: foto,
          });

      expect(user(null).photoUrl, isNull);
      expect(user('').photoUrl, isNull);
      expect(user('/storage/clientes/a.jpg').photoUrl,
          endsWith('/storage/clientes/a.jpg'));
      expect(user('/storage/clientes/a.jpg').photoUrl, startsWith('http'));
      // El login la devuelve duplicada.
      expect(
        user('https://api.test/storage/clientes//storage/clientes/a.jpg',
                key: 'foto_url')
            .photoUrl,
        'https://api.test/storage/clientes/a.jpg',
      );
    });

    test('el cliente guarda su código del ERP', () {
      final u = UserModel.fromJson({
        'id': 1,
        'nombre_completo': 'Ana',
        'email': 'a@a.com',
        'codigo_erp': 'CLI00001',
      });

      expect(u.erpCode, 'CLI00001');
      expect(UserModel.decode(u.encode()).erpCode, 'CLI00001');
    });

    test('un favorito usa el precio ya resuelto para el cliente', () {
      final p = ProductModel.fromFavoriteJson({
        'id': 3,
        'nombre': 'DRIVER',
        'precio_venta': '0.00',
        'precio': 80,
        'moneda': 'd',
        'stock': 7,
        'imagen_url': 'https://api.test/storage/productos/a.png',
        'precio_visible': true,
      });

      expect(p.price, 80);
      expect(p.currency, 'd');
      expect(p.stock, 7);
    });

    test('la compra en línea interpreta estado, dirección y productos', () {
      final p = PurchaseModel.fromJson({
        'codigo': 'PAGO-2026-00001',
        'estado_proceso': 'en_delivery',
        'fecha': '2026-10-20T15:30:00Z',
        'moneda': 's',
        'subtotal': 100,
        'igv': '18.00',
        'descuento': 0,
        'costo_envio': 10,
        'total': 128,
        'cupon_codigo': null,
        'comprobante_erp': 'B001-123',
        'comprobante_enviado_at': '2026-10-21T10:00:00Z',
        'cliente_email': 'ana@correo.com',
        'direccion_envio': 'Av. Larco 123',
        'distrito_nombre': 'MIRAFLORES',
        'provincia_nombre': 'LIMA',
        'departamento_nombre': 'LIMA',
        'items': [
          {
            'producto_id': 1,
            'nombre': 'Driver',
            'cantidad': 2,
            'precio_unitario': 50,
            'subtotal': 100,
          },
        ],
      });

      expect(p.stage, PurchaseStage.inDelivery);
      expect(p.deliveryAddress, 'Av. Larco 123, MIRAFLORES, LIMA, LIMA');
      expect(p.igv, 18);
      expect(p.items.single.quantity, 2);
      expect(p.invoiceNumber, 'B001-123');
    });

    test('un estado desconocido cuenta como el primer paso', () {
      expect(PurchaseStage.fromApi('algo_raro'), PurchaseStage.pendingInvoice);
      expect(PurchaseStage.fromApi(null), PurchaseStage.pendingInvoice);
      expect(PurchaseStage.fromApi('cancelado').step, -1);
      expect(PurchaseStage.fromApi('entregado').step, 3);
    });

    test('las compras en tienda indican si la cuenta está vinculada', () {
      final unlinked = StorePurchasesModel.fromJson(
          {'status': 'success', 'vinculado': false, 'compras': []});
      expect(unlinked.linked, isFalse);

      final linked = StorePurchasesModel.fromJson({
        'vinculado': true,
        'compras': [
          {
            'id': 9,
            'documento': 'BOL001-0123',
            'fecha': '2026-10-01',
            'moneda': 's',
            'total': 59,
            'anulada': true,
            'productos': [
              {'codigo': 'X', 'nombre': 'Cable', 'cantidad': 2.0, 'precio': 29.5, 'subtotal': 59},
            ],
          },
        ],
      });
      expect(linked.sales.single.cancelled, isTrue);
      expect(linked.sales.single.items.single.quantity, 2);
    });

    test('la dirección interpreta la ubicación y los códigos', () {
      final a = AddressModel.fromJson({
        'id': 4,
        'nombre_destinatario': 'ANA',
        'direccion_completa': 'Av. Larco 123',
        'referencia': '  ',
        'id_ubigeo': 150122,
        'predeterminada': 1,
        'ubigeo': {
          'departamento': '15',
          'provincia': '01',
          'distrito': '22',
          'departamento_nombre': 'LIMA',
          'provincia_nombre': 'LIMA',
          'distrito_nombre': 'N/A',
        },
      });

      expect(a.isDefault, isTrue);
      expect(a.reference, isNull);
      expect(a.ubigeoId, '150122');
      expect(a.districtCode, '22');
      // "N/A" del servidor no se muestra.
      expect(a.location, 'LIMA, LIMA');
    });

    test('la cotización muestra el estado del pedido y sus reglas', () {
      final q = QuoteModel.fromJson({
        'id': 1,
        'codigo_cotizacion': '2026-00001',
        'estado_actual': {'nombre': 'Pendiente'},
        'estado_pedido': {'nombre_estado': 'En preparación'},
        'editable': false,
        'total': '99.5',
        'forma_envio': 'recojo_tienda',
        'direccion_envio': 'Tienda',
        'ubicacion_completa': 'LIMA',
      });

      expect(q.status, 'En preparación');
      expect(q.inAttention, isTrue);
      expect(q.canCancel, isFalse);
      expect(q.shippingLabel, 'Recojo en tienda');
      expect(q.deliveryAddress, 'Tienda - LIMA');

      // Sin estado del pedido se usa el de la cotización; sin ninguno, "En espera".
      expect(
        QuoteModel.fromJson({
          'id': 2,
          'codigo_cotizacion': 'x',
          'estado_actual': {'nombre': 'Pendiente'},
          'total': 1,
        }).status,
        'Pendiente',
      );
      final waiting = QuoteModel.fromJson(
          {'id': 3, 'codigo_cotizacion': 'x', 'total': 1, 'editable': true});
      expect(waiting.status, 'En espera');
      expect(waiting.canCancel, isTrue);

      final cancelled = QuoteModel.fromJson({
        'id': 4,
        'codigo_cotizacion': 'x',
        'total': 1,
        'editable': true,
        'estado_pedido': {'nombre_estado': 'Cancelado'},
      });
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.canCancel, isFalse);
    });
  });

  group('Mi cuenta', () {
    testWidgets('muestra el saludo, el código vinculado y el menú',
        (tester) async {
      final env = TestEnv();
      env.authRemote.profile = testUser;
      await _openAccount(tester, env);

      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      // El menú es una lista: se baja hasta cada entrada.
      for (final entry in [
        'Datos personales',
        'Direcciones',
        'Mis cotizaciones',
        'Mis compras',
        'Mis listas',
        'Mi carrito',
        'Cerrar sesión',
      ]) {
        await tester.scrollUntilVisible(
          find.text(entry),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(entry), findsOneWidget, reason: entry);
      }
    });

    testWidgets('datos personales: el celular se edita con su validación',
        (tester) async {
      final env = TestEnv();
      await _openAccount(tester, env);
      await _openSection(tester, 'Datos personales');

      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('12345678'), findsOneWidget);
      expect(find.text('Sin registrar'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('celular peruano válido'), findsOneWidget);
      expect(env.authRemote.savedPhone, isNull);

      await tester.enterText(find.byType(TextFormField), '951127833');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(env.authRemote.savedPhone, '951127833');
      expect(find.text('951127833'), findsOneWidget);
      expect(_context(tester).read<AuthProvider>().user?.phone, '951127833');
    });
  });

  group('Mis listas', () {
    testWidgets('lista los favoritos con sus reglas de precio y stock',
        (tester) async {
      final env = TestEnv();
      env.favoritesRemote.items = [
        _favorite(1, 'Driver 400W'),
        _favorite(2, 'Parlante', stock: 0),
      ];
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis listas');

      expect(find.text('Driver 400W'), findsOneWidget);
      expect(find.text('Parlante'), findsOneWidget);
      expect(find.text('Stock: 5 unidades'), findsOneWidget);
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('Sin stock'), findsOneWidget);
    });

    testWidgets('sin favoritos muestra el estado vacío', (tester) async {
      final env = TestEnv();
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis listas');

      expect(find.text('Aún no tienes favoritos'), findsOneWidget);
    });

    testWidgets('quitar un favorito pide confirmación y usa el id del producto',
        (tester) async {
      final env = TestEnv();
      env.favoritesRemote.items = [_favorite(11, 'Driver 400W')];
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis listas');

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();

      expect(env.favoritesRemote.removed, [11]);
      expect(find.text('Driver 400W'), findsNothing);
    });

    testWidgets('el corazón de la ficha guarda el producto', (tester) async {
      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driver').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(env.favoritesRemote.added, [5]);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('Guardado en mis listas'), findsOneWidget);
    });

    testWidgets('sin sesión el corazón pide iniciar sesión', (tester) async {
      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driver').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(env.favoritesRemote.added, isEmpty);
      expect(find.text('Iniciar sesión'), findsWidgets);
    });

    testWidgets('si el servidor falla al guardar, el corazón no cambia',
        (tester) async {
      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      env.favoritesRemote.failure = const ServerException('Error al agregar favorito');
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driver').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(find.text('Error al agregar favorito'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });
  });

  group('Mis compras', () {
    PurchaseModel purchase(String stage) => PurchaseModel.fromJson({
          'codigo': 'PAGO-1',
          'estado_proceso': stage,
          'fecha': '2026-10-20T15:30:00Z',
          'moneda': 's',
          'subtotal': 100,
          'igv': 18,
          'descuento': 5,
          'cupon_codigo': 'PROMO5',
          'costo_envio': 10,
          'total': 123,
          'comprobante_erp': 'B001-9',
          'comprobante_enviado_at': '2026-10-21T10:00:00Z',
          'cliente_email': 'ana@correo.com',
          'direccion_envio': 'Av. Larco 123',
          'distrito_nombre': 'MIRAFLORES',
          'items': [
            {'producto_id': 1, 'nombre': 'Driver', 'cantidad': 2, 'precio_unitario': 50, 'subtotal': 100},
          ],
        });

    testWidgets('lista las compras y abre el detalle con el seguimiento',
        (tester) async {
      final env = TestEnv();
      env.purchasesRemote.online = [purchase('facturado')];
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis compras');

      expect(find.text('PAGO-1'), findsOneWidget);
      expect(find.text('Facturado'), findsOneWidget);
      expect(find.text('S/ 123.00'), findsOneWidget);

      await tester.tap(find.text('PAGO-1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Emitimos tu comprobante'), findsOneWidget);
      // Los 4 pasos del seguimiento.
      for (final step in [
        'Pendiente de facturar',
        'En delivery',
        'Entregado',
      ]) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
      expect(find.text('B001-9'), findsOneWidget);
      expect(find.text('Enviado a ana@correo.com'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Descuento (PROMO5)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Descuento (PROMO5)'), findsOneWidget);
    });

    testWidgets('una compra cancelada no muestra el seguimiento',
        (tester) async {
      final env = TestEnv();
      env.purchasesRemote.online = [purchase('cancelado')];
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis compras');
      await tester.tap(find.text('PAGO-1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('fue cancelada'), findsOneWidget);
      expect(find.text('En delivery'), findsNothing);
    });

    testWidgets('sin compras ni cuenta vinculada se explica en cada pestaña',
        (tester) async {
      final env = TestEnv();
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis compras');

      expect(find.text('Aún no tienes compras en línea'), findsOneWidget);

      await tester.tap(find.text('En tienda'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta sin vincular'), findsOneWidget);
    });

    testWidgets('las compras en tienda se ven si la cuenta está vinculada',
        (tester) async {
      final env = TestEnv();
      env.purchasesRemote.store = StorePurchasesModel.fromJson({
        'vinculado': true,
        'compras': [
          {
            'id': 1,
            'documento': 'BOL001-0123',
            'fecha': '2026-10-01',
            'moneda': 's',
            'total': 59,
            'anulada': false,
            'productos': [],
          },
        ],
      });
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis compras');
      await tester.tap(find.text('En tienda'));
      await tester.pumpAndSettle();

      expect(find.text('BOL001-0123'), findsOneWidget);
      expect(find.text('Emitida'), findsOneWidget);
    });
  });

  group('Direcciones', () {
    testWidgets('lista las direcciones y marca la predeterminada',
        (tester) async {
      final env = TestEnv();
      env.addressesRemote.items = [
        _address(1, 'Av. Larco 123', isDefault: true),
        _address(2, 'Jr. Unión 45'),
      ];
      await _openAccount(tester, env);
      await _openSection(tester, 'Direcciones');

      expect(find.text('Av. Larco 123'), findsOneWidget);
      expect(find.text('Predeterminada'), findsOneWidget);
      expect(find.text('MIRAFLORES, LIMA, LIMA'), findsNWidgets(2));
      // Solo la que no es predeterminada ofrece serlo.
      expect(find.text('Establecer predeterminada'), findsOneWidget);
    });

    testWidgets('establecer predeterminada y eliminar llaman al servidor',
        (tester) async {
      final env = TestEnv();
      env.addressesRemote.items = [
        _address(1, 'Av. Larco 123', isDefault: true),
        _address(2, 'Jr. Unión 45'),
      ];
      await _openAccount(tester, env);
      await _openSection(tester, 'Direcciones');

      await tester.tap(find.text('Establecer predeterminada'));
      await tester.pumpAndSettle();
      expect(env.addressesRemote.madeDefault, [2]);

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      expect(env.addressesRemote.deleted, [2]);
    });

    testWidgets(
        'crear una dirección: ubicación en cascada y id del distrito como texto',
        (tester) async {
      final env = TestEnv();
      await _openAccount(tester, env);
      await _openSection(tester, 'Direcciones');
      expect(find.text('Aún no tienes direcciones'), findsOneWidget);

      await tester.tap(find.text('Nueva dirección'));
      await tester.pumpAndSettle();

      // Las provincias y distritos esperan a que se elija el nivel anterior.
      await tester.tap(find.text('Departamento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIMA').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Provincia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIMA').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Distrito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MIRAFLORES'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Dirección'), 'Av. Larco 123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Indicaciones (opcional)'),
          'Frente al parque');
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final draft = env.addressesRemote.saved.single;
      expect(draft.ubigeoId, '150122');
      expect(draft.ubigeoId, isA<String>());
      expect(draft.fullAddress, 'Av. Larco 123');
      expect(draft.reference, 'Frente al parque');
      expect(draft.isDefault, isTrue);
      expect(env.addressesRemote.savedIds.single, isNull);
    });

    testWidgets('no guarda sin elegir la ubicación', (tester) async {
      final env = TestEnv();
      await _openAccount(tester, env);
      await _openSection(tester, 'Direcciones');
      await tester.tap(find.text('Nueva dirección'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Dirección'), 'Av. Larco 123');
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Elige departamento'), findsOneWidget);
      expect(env.addressesRemote.saved, isEmpty);
    });

    testWidgets('al editar se precarga la ubicación y se conserva la marca',
        (tester) async {
      final env = TestEnv();
      env.addressesRemote.items = [
        _address(3, 'Av. Larco 123', isDefault: true),
      ];
      await _openAccount(tester, env);
      await _openSection(tester, 'Direcciones');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar dirección'), findsOneWidget);
      expect(find.text('MIRAFLORES'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Dirección'), 'Av. Larco 999');
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final draft = env.addressesRemote.saved.single;
      expect(env.addressesRemote.savedIds.single, 3);
      expect(draft.fullAddress, 'Av. Larco 999');
      expect(draft.ubigeoId, '150122');
      // El servidor pone `false` si falta: siempre se envía la marca actual.
      expect(draft.isDefault, isTrue);
    });
  });

  group('Cotizaciones', () {
    testWidgets('lista el estado y avisa cuando ya la atiende un vendedor',
        (tester) async {
      final env = TestEnv();
      env.quotesRemote.items = [
        _quote(1),
        _quote(2, status: 'En preparación', editable: false),
        _quote(3, status: 'Cancelado', editable: false),
      ];
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis cotizaciones');

      expect(find.text('Cotización 2026-00001'), findsOneWidget);
      expect(find.text('En espera'), findsOneWidget);
      expect(find.text('En preparación'), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget);
      // Solo la que está en preparación muestra "En atención".
      expect(find.text('En atención'), findsOneWidget);
    });

    testWidgets('cancela una cotización en espera', (tester) async {
      final env = TestEnv();
      env.quotesRemote.items = [_quote(1)];
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis cotizaciones');
      await tester.tap(find.text('Cotización 2026-00001'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cancelar cotización').last);
      await tester.tap(find.text('Cancelar cotización').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(env.quotesRemote.cancelled, [1]);
      expect(find.text('La cotización quedó cancelada.'), findsOneWidget);
    });

    testWidgets('una cotización en atención no se puede cancelar',
        (tester) async {
      final env = TestEnv();
      env.quotesRemote.items = [
        _quote(2, status: 'En preparación', editable: false),
      ];
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis cotizaciones');
      await tester.tap(find.text('Cotización 2026-00002'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Un vendedor ya está atendiendo'),
          findsOneWidget);
      expect(find.text('Cancelar cotización'), findsNothing);
    });

    testWidgets('muestra el mensaje del servidor si no se pudo cancelar',
        (tester) async {
      final env = TestEnv();
      env.quotesRemote.items = [_quote(1)];
      env.quotesRemote.cancelFailure = const ServerException(
        'Un vendedor ya está atendiendo tu pedido, así que no se puede cancelar.',
        '422',
      );
      await _openAccount(tester, env);
      await _openSection(tester, 'Mis cotizaciones');
      await tester.tap(find.text('Cotización 2026-00001'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cancelar cotización').last);
      await tester.tap(find.text('Cancelar cotización').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no se puede cancelar'), findsOneWidget);
    });
  });
}
