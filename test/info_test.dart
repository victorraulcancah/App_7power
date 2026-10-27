import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/info_remote_datasource.dart';
import 'package:appecommerce/data/models/info_model.dart';
import 'package:appecommerce/domain/entities/info_entity.dart';
import 'package:appecommerce/domain/usecases/info_usecases.dart';
import 'package:appecommerce/theme/app_theme.dart';

import 'support/fakes.dart';

/// Pantalla alta, para que las listas largas muestren todo sin desplazarse.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openMore(WidgetTester tester, TestEnv env) async {
  _tall(tester);
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Más'));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
}

ClaimDraft _claim({
  String documentType = 'DNI',
  String documentNumber = '12345678',
  bool isMinor = false,
  DateTime? purchaseDate,
  String? expectedSolution,
  String? otherSolution,
}) =>
    ClaimDraft(
      consumerName: 'Ana Pérez',
      documentType: documentType,
      documentNumber: documentNumber,
      address: 'Av. Larco 123, Miraflores',
      phone: '951127833',
      email: 'ana@correo.com',
      isMinor: isMinor,
      goodType: 'producto',
      amount: 120,
      goodDescription: 'Driver 400W que dejó de funcionar',
      requestType: 'reclamo',
      detail: 'El producto dejó de funcionar a los dos días de uso.',
      consumerRequest: 'Quiero que me lo cambien',
      purchaseDate: purchaseDate,
      expectedSolution: expectedSolution,
      otherSolution: otherSolution,
    );

void main() {
  group('Tema', () {
    test('los grises no toman el tinte del color de marca', () {
      // Con un navbar negro, el tema anterior pintaba la barra inferior de rosa.
      for (final brand in [Colors.black, const Color(0xFF9B1C1C), Colors.blue]) {
        final scheme = AppTheme.build(brand).colorScheme;
        for (final c in [scheme.surfaceContainerHighest, scheme.outlineVariant]) {
          final channels = [c.r, c.g, c.b];
          final spread = channels.reduce((a, b) => a > b ? a : b) -
              channels.reduce((a, b) => a < b ? a : b);
          expect(spread, lessThan(0.06), reason: '$brand $c');
        }
      }
    });

    test('la marca es el color primario y se lee sobre él', () {
      final dark = AppTheme.build(Colors.black).colorScheme;
      expect(dark.primary, Colors.black);
      expect(dark.onPrimary, Colors.white);

      final light = AppTheme.build(Colors.yellow).colorScheme;
      expect(light.onPrimary, Colors.black);
    });

    test('la barra inferior es blanca y marca la pestaña con la marca', () {
      final nav = AppTheme.build(const Color(0xFF112233)).navigationBarTheme;

      expect(nav.backgroundColor, Colors.white);
      expect(nav.indicatorColor, const Color(0xFF112233).withValues(alpha: 0.12));
    });
  });

  group('Modelos', () {
    test('Sobre nosotros: ordena y filtra los valores, y arregla los saltos', () {
      final about = AboutModel.fromJson({
        'nombre_empresa': '7power',
        'descripcion': 'Línea 1\r\n\r\nLínea 2',
        'imagen_descripcion_url': 'https://api.test/a.png',
        'valores': [
          {'titulo': 'Visión', 'descripcion': 'B', 'orden': 2, 'activo': true},
          {'titulo': 'Oculto', 'descripcion': 'X', 'orden': 3, 'activo': false},
          {'titulo': 'Misión', 'descripcion': 'A\r\nA2', 'orden': 1},
        ],
      });

      expect(about.description, 'Línea 1\n\nLínea 2');
      expect(about.values.map((v) => v.title), ['Misión', 'Visión']);
      expect(about.values.first.description, 'A\nA2');
    });

    test('un paso de envío y las constancias de reclamo', () {
      final step = shippingStepFromJson({
        'orden': 2,
        'titulo': 'Espera su transporte',
        'descripcion': '  ',
        'imagen': 'https://api.test/p.png',
      });
      expect(step.order, 2);
      expect(step.description, isNull);

      final receipt = claimReceiptFromJson({
        'numero_reclamo': 'REC-1',
        'fecha_limite_respuesta': '2026-11-20T00:00:00Z',
      });
      expect(receipt.number, 'REC-1');
      expect(receipt.deadline?.year, 2026);

      final status = claimStatusFromJson({
        'numero_reclamo': 'REC-1',
        'estado': 'en_proceso',
        'respuesta_proveedor': null,
      });
      expect(status.status, 'en_proceso');
      expect(status.response, isNull);
    });
  });

  group('Validaciones', () {
    test('el documento se valida según su tipo', () {
      expect(validateDocument('DNI', '12345678'), isNull);
      expect(validateDocument('DNI', '1234'), contains('8 dígitos'));
      expect(validateDocument('RUC', '20123456789'), isNull);
      expect(validateDocument('RUC', '30123456789'), contains('empezar con'));
      expect(validateDocument('Pasaporte', 'AB1234'), isNull);
      expect(validateDocument('Pasaporte', 'AB1'), contains('entre 6 y 12'));
      expect(validateDocument('Carné de extranjería', '123456789'), isNull);
      expect(validateDocument('Carné de extranjería', '123'), contains('entre 9 y 12'));
    });

    test('un reclamo correcto no tiene errores', () {
      expect(validateClaim(_claim()), isNull);
    });

    test('un reclamo se revisa como lo hace el backend', () {
      expect(validateClaim(_claim(documentNumber: '12')), contains('DNI'));
      expect(
        validateClaim(_claim(purchaseDate: DateTime.now().add(const Duration(days: 2)))),
        'La fecha de compra no puede ser futura',
      );
      expect(
        validateClaim(_claim(expectedSolution: 'Otro')),
        'Escribe la solución que esperas',
      );
      expect(
        validateClaim(_claim(expectedSolution: 'Otro', otherSolution: 'Un repuesto')),
        isNull,
      );
    });

    test('un menor de edad necesita los datos del apoderado', () {
      expect(validateClaim(_claim(isMinor: true)), contains('apoderado'));
    });

    test('el mensaje de contacto exige nombre, correo, asunto y mensaje', () {
      const ok = ContactMessage(
        name: 'Ana',
        email: 'ana@correo.com',
        subject: 'Consulta',
        message: 'Hola',
      );
      expect(validateContact(ok), isNull);
      expect(
        validateContact(const ContactMessage(
          name: 'Ana', email: 'mal', subject: 'x', message: 'y',
        )),
        'Ingresa un correo válido',
      );
      expect(
        validateContact(ContactMessage(
          name: 'Ana', email: 'a@a.com', subject: 'x', message: 'y' * 2001,
        )),
        contains('2000'),
      );
    });
  });

  group('InfoRemoteDataSource', () {
    late Map<String, dynamic> sent;
    late String path;

    InfoRemoteDataSourceImpl source(http.Response Function(http.Request) handler) =>
        InfoRemoteDataSourceImpl(ApiClient(
          client: MockClient((r) async {
            path = r.url.path;
            if (r.body.isNotEmpty) sent = jsonDecode(r.body) as Map<String, dynamic>;
            return handler(r);
          }),
          isConnected: () async => true,
        ));

    http.Response json(Object body, [int status = 200]) =>
        http.Response.bytes(utf8.encode(jsonEncode(body)), status);

    test('el reclamo manda la fecha como AAAA-MM-DD y omite al apoderado', () async {
      final remote = source((_) => json({
            'reclamo': {'numero_reclamo': 'REC-9', 'fecha_limite_respuesta': '2026-11-20'},
          }, 201));

      final receipt = await remote.submitClaim(
        _claim(purchaseDate: DateTime(2026, 10, 5)),
      );

      expect(path, endsWith('/reclamos/crear'));
      expect(sent['fecha_compra'], '2026-10-05');
      expect(sent['consumidor_telefono'], '951127833');
      expect(sent['es_menor_edad'], false);
      expect(sent.containsKey('apoderado_nombre'), isFalse);
      expect(sent['monto_reclamado'], 120);
      expect(sent['tipo_documento'], 'DNI');
      expect(receipt.number, 'REC-9');
    });

    test('el mensaje de contacto se recorta y viaja con los campos del backend',
        () async {
      final remote = source((_) => json({'message': 'Mensaje recibido'}, 201));

      await remote.sendContact(const ContactMessage(
        name: ' Ana ',
        email: 'ana@correo.com',
        subject: ' Consulta ',
        message: ' Hola ',
      ));

      expect(path, endsWith('/contacto'));
      expect(sent['nombre'], 'Ana');
      expect(sent['asunto'], 'Consulta');
      expect(sent['mensaje'], 'Hola');
    });

    test('un reclamo se busca por su número, codificado', () async {
      final remote = source((_) => json({
            'reclamo': {'numero_reclamo': 'REC/1', 'estado': 'pendiente'},
          }));

      await remote.findClaim('REC/1');

      expect(path, contains('REC%2F1'));
    });

    test('los pasos de envío salen ordenados y solo los activos', () async {
      final remote = source((_) => json({
            'data': [
              {'orden': 2, 'titulo': 'Dos', 'activo': true},
              {'orden': 3, 'titulo': 'Oculto', 'activo': false},
              {'orden': 1, 'titulo': 'Uno'},
            ],
          }));

      final steps = await remote.getShippingSteps();

      expect(steps.map((s) => s.title), ['Uno', 'Dos']);
    });
  });

  group('Pestaña Más', () {
    testWidgets('lista nosotros, atención al cliente y lo legal', (tester) async {
      await _openMore(tester, TestEnv());

      for (final entry in [
        'Sobre nosotros',
        'Cómo funciona el envío',
        'Contáctanos',
        'Libro de reclamaciones',
        'Consultar un reclamo',
        'Información legal',
        'Términos y condiciones',
        'Cambios y devoluciones',
        'Política de privacidad',
        'Síguenos',
        'Medios de pago',
      ]) {
        expect(find.text(entry), findsOneWidget, reason: entry);
      }
      // La portada usa los datos de la empresa.
      expect(find.text('CERCADO DE LIMA'), findsOneWidget);
    });

    testWidgets('Sobre nosotros muestra la descripción y los valores',
        (tester) async {
      await _openMore(tester, TestEnv());
      await tester.tap(find.text('Sobre nosotros'));
      await tester.pumpAndSettle();

      expect(find.textContaining('empresa peruana de audio automotriz'),
          findsOneWidget);
      expect(find.text('Misión'), findsOneWidget);
      expect(find.text('Visión'), findsOneWidget);
    });

    testWidgets('Sobre nosotros muestra el error y reintenta', (tester) async {
      final env = TestEnv();
      env.infoRemote.failure = const NetworkException('Sin conexión');
      await _openMore(tester, env);
      await tester.tap(find.text('Sobre nosotros'));
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);

      env.infoRemote.failure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Misión'), findsOneWidget);
    });

    testWidgets('Cómo funciona el envío lista los pasos', (tester) async {
      await _openMore(tester, TestEnv());
      await tester.tap(find.text('Cómo funciona el envío'));
      await tester.pumpAndSettle();

      expect(find.text('Paso 1'), findsOneWidget);
      expect(find.text('Realiza el pedido'), findsOneWidget);
      expect(find.text('Paso 2'), findsOneWidget);
    });

    testWidgets('Contacto: muestra los datos y envía el mensaje', (tester) async {
      final env = TestEnv();
      await _openMore(tester, env);
      await tester.tap(find.text('Contáctanos'));
      await tester.pumpAndSettle();

      expect(find.text('ventas@7power.pe'), findsOneWidget);

      await _enter(tester, 'Nombre', 'Ana Pérez');
      await _enter(tester, 'Correo electrónico', 'ana@correo.com');
      await _enter(tester, 'Asunto', 'Consulta de envío');
      await _enter(tester, 'Mensaje', 'Quiero saber cuánto demora un envío a Arequipa.');
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();

      final sent = env.infoRemote.contacts.single;
      expect(sent.subject, 'Consulta de envío');
      expect(sent.phone, isNull);
      expect(find.text('Mensaje enviado. Te responderemos pronto.'), findsOneWidget);
    });

    testWidgets('Contacto: pide los datos obligatorios', (tester) async {
      final env = TestEnv();
      await _openMore(tester, env);
      await tester.tap(find.text('Contáctanos'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu nombre'), findsOneWidget);
      expect(find.text('Ingresa el asunto'), findsOneWidget);
      expect(env.infoRemote.contacts, isEmpty);
    });
  });

  group('Libro de reclamaciones', () {
    Future<void> openBook(WidgetTester tester, TestEnv env) async {
      await _openMore(tester, env);
      await tester.tap(find.text('Libro de reclamaciones'));
      await tester.pumpAndSettle();
    }

    Future<void> fillValid(WidgetTester tester) async {
      await _enter(tester, 'Nombre completo *', 'Ana Pérez');
      await _enter(tester, 'Número de documento *', '12345678');
      await _enter(tester, 'Dirección *', 'Av. Larco 123, Miraflores');
      await _enter(tester, 'Teléfono (9 dígitos) *', '951127833');
      await _enter(tester, 'Correo electrónico *', 'ana@correo.com');
      await _enter(tester, 'Monto reclamado (S/) *', '120.50');
      await _enter(tester, 'Descripción del producto o servicio *',
          'Driver 400W que dejó de funcionar');
      await _enter(tester, 'Detalle del reclamo *',
          'El producto dejó de funcionar a los dos días de uso.');
      await _enter(tester, 'Tu pedido al proveedor *', 'Quiero que me lo cambien');
    }

    testWidgets('con sesión los datos del cliente vienen llenos', (tester) async {
      final env = TestEnv();
      await env.authRepo.login('ana@correo.com', 'secreto');
      await openBook(tester, env);

      expect(find.widgetWithText(TextFormField, 'Nombre completo *'), findsOneWidget);
      final name = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Nombre completo *'));
      expect(name.controller?.text, 'Ana Pérez');
      final doc = tester.widget<TextFormField>(
          find.widgetWithText(TextFormField, 'Número de documento *'));
      expect(doc.controller?.text, '12345678');
    });

    testWidgets('no envía con datos inválidos y marca los campos', (tester) async {
      final env = TestEnv();
      await openBook(tester, env);

      await tester.ensureVisible(find.text('Enviar reclamo'));
      await tester.tap(find.text('Enviar reclamo'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu nombre completo'), findsOneWidget);
      expect(find.text('Mínimo 10 caracteres'), findsWidgets);
      expect(find.text('Debe ser mayor a 0'), findsOneWidget);
      expect(env.infoRemote.claims, isEmpty);
    });

    testWidgets('envía el reclamo y muestra el número', (tester) async {
      final env = TestEnv();
      await openBook(tester, env);
      await fillValid(tester);

      await tester.ensureVisible(find.text('Enviar reclamo'));
      await tester.tap(find.text('Enviar reclamo'));
      await tester.pumpAndSettle();

      final claim = env.infoRemote.claims.single;
      expect(claim.consumerName, 'Ana Pérez');
      expect(claim.amount, 120.5);
      expect(claim.goodType, 'producto');
      expect(claim.requestType, 'reclamo');
      expect(claim.isMinor, isFalse);

      expect(find.text('Recibimos tu reclamo'), findsOneWidget);
      expect(find.text('REC-2026-00001'), findsOneWidget);
      expect(find.textContaining('20/11/2026'), findsOneWidget);
    });

    testWidgets('el documento se valida según el tipo elegido', (tester) async {
      final env = TestEnv();
      await openBook(tester, env);
      await fillValid(tester);
      await _enter(tester, 'Número de documento *', '1234');

      await tester.ensureVisible(find.text('Enviar reclamo'));
      await tester.tap(find.text('Enviar reclamo'));
      await tester.pumpAndSettle();

      expect(find.text('El DNI debe tener 8 dígitos'), findsOneWidget);
      expect(env.infoRemote.claims, isEmpty);
    });

    testWidgets('si es menor de edad aparecen los datos del apoderado',
        (tester) async {
      final env = TestEnv();
      await openBook(tester, env);
      expect(find.text('Nombre del apoderado *'), findsNothing);

      await tester.ensureVisible(find.text('Soy menor de edad'));
      await tester.tap(find.text('Soy menor de edad'));
      await tester.pumpAndSettle();

      expect(find.text('Nombre del apoderado *'), findsOneWidget);
      expect(find.text('DNI del apoderado *'), findsOneWidget);
    });

    testWidgets('muestra el error del servidor al enviar', (tester) async {
      final env = TestEnv();
      env.infoRemote.failure = const ServerException('Datos inválidos', '422');
      await openBook(tester, env);
      await fillValid(tester);

      await tester.ensureVisible(find.text('Enviar reclamo'));
      await tester.tap(find.text('Enviar reclamo'));
      await tester.pumpAndSettle();

      expect(find.text('Datos inválidos'), findsOneWidget);
      expect(find.text('Recibimos tu reclamo'), findsNothing);
    });

    testWidgets('consulta el estado de un reclamo por su número', (tester) async {
      final env = TestEnv();
      env.infoRemote.claimToFind = ClaimStatus(
        number: 'REC-2026-00001',
        status: 'resuelto',
        deadline: DateTime(2026, 11, 20),
        response: 'Cambiamos tu producto.',
      );
      await _openMore(tester, env);
      await tester.tap(find.text('Consultar un reclamo'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de reclamo'), 'REC-2026-00001');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();

      expect(find.text('Resuelto'), findsOneWidget);
      expect(find.text('Cambiamos tu producto.'), findsOneWidget);
    });

    testWidgets('un número inexistente muestra el mensaje del servidor',
        (tester) async {
      final env = TestEnv();
      await _openMore(tester, env);
      await tester.tap(find.text('Consultar un reclamo'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Número de reclamo'), 'NO-EXISTE');
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no encontrado'), findsOneWidget);
    });
  });

  group('Cuenta', () {
    testWidgets('también ofrece libro de reclamaciones, contacto y nosotros',
        (tester) async {
      final env = TestEnv();
      await env.authRepo.login('ana@correo.com', 'secreto');
      _tall(tester);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Libro de reclamaciones'), findsOneWidget);
      await tester.tap(find.text('Libro de reclamaciones'));
      await tester.pumpAndSettle();
      expect(find.text('1. Tus datos'), findsOneWidget);
    });
  });
}
