import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/registration_remote_datasource.dart';
import 'package:appecommerce/domain/entities/register_entity.dart';
import 'package:appecommerce/domain/usecases/registration_usecases.dart';
import 'package:appecommerce/presentation/widgets/captcha_puzzle.dart';

import 'support/fakes.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Cuenta > "Crear una cuenta".
Future<void> _openRegister(WidgetTester tester, TestEnv env) async {
  _tall(tester);
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
  final button = find.text('Crear una cuenta');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
}

Future<void> _fillForm(WidgetTester tester) async {
  await _enter(tester, 'Nombres', 'Ana');
  await _enter(tester, 'Apellidos', 'Pérez');
  await _enter(tester, 'Correo electrónico', 'ana@correo.com');
  await tester.ensureVisible(find.byKey(const Key('register-document-type')));
  await tester.tap(find.byKey(const Key('register-document-type')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('DNI').last);
  await tester.pumpAndSettle();
  await _enter(tester, 'Número de documento', '12345678');
  await _enter(tester, 'Contraseña', 'secreto123');
  await _enter(tester, 'Confirmar contraseña', 'secreto123');
}

Future<void> _continue(WidgetTester tester) async {
  final button = find.text('Continuar');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

RegisterDraft _draft({
  int type = 1,
  String document = '12345678',
  String password = 'secreto123',
  String confirmation = 'secreto123',
  String? phone,
}) =>
    RegisterDraft(
      firstNames: 'Ana',
      lastNames: 'Pérez',
      email: 'ana@correo.com',
      password: password,
      passwordConfirmation: confirmation,
      phone: phone,
      documentTypeId: type,
      documentNumber: document,
    );

void main() {
  group('Validación del registro', () {
    test('acepta datos correctos', () {
      expect(validateRegister(_draft()), isNull);
    });

    test('el documento se valida según el tipo', () {
      expect(validateRegisterDocument(1, '1234567'), contains('8 dígitos'));
      expect(validateRegisterDocument(1, '12345678'), isNull);
      expect(validateRegisterDocument(6, '12345678901'), contains('RUC'));
      expect(validateRegisterDocument(6, '20123456789'), isNull);
      expect(validateRegisterDocument(3, 'abc'), contains('carné'));
      expect(validateRegisterDocument(2, 'A123'), isNotNull);
      expect(validateRegisterDocument(2, 'AB123456'), isNull);
      expect(validateRegisterDocument(1, ''), isNotNull);
    });

    test('la contraseña pide 8 caracteres y que coincidan', () {
      expect(validateRegister(_draft(password: 'corta', confirmation: 'corta')),
          contains('8 caracteres'));
      expect(validateRegister(_draft(confirmation: 'otra-clave')),
          contains('no coinciden'));
    });

    test('el celular es opcional pero, si se escribe, empieza con 9', () {
      expect(validateRegister(_draft(phone: '')), isNull);
      expect(validateRegister(_draft(phone: '951127833')), isNull);
      expect(validateRegister(_draft(phone: '851127833')), contains('9 dígitos'));
    });
  });

  group('Datos enviados al servidor', () {
    Map<String, dynamic>? sent;
    late String path;

    RegistrationRemoteDataSourceImpl source(Object body, [int status = 200]) =>
        RegistrationRemoteDataSourceImpl(ApiClient(
          client: MockClient((r) async {
            path = r.url.path;
            if (r.body.isNotEmpty) sent = jsonDecode(r.body) as Map<String, dynamic>;
            return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
          }),
          isConnected: () async => true,
        ));

    test('el registro manda los campos del backend y el token del captcha', () async {
      final remote = source({'message': 'Usuario registrado exitosamente.'}, 201);
      final message = await remote.register(_draft(phone: ' 951127833 '), 'tok-1');

      expect(path, '/api/register');
      expect(message, 'Usuario registrado exitosamente.');
      expect(sent, {
        'nombres': 'Ana',
        'apellidos': 'Pérez',
        'email': 'ana@correo.com',
        'password': 'secreto123',
        'password_confirmation': 'secreto123',
        'telefono': '951127833',
        'tipo_documento_id': 1,
        'numero_documento': '12345678',
        'captcha_token': 'tok-1',
      });
    });

    test('sin celular se envía null', () async {
      await source({'message': 'ok'}, 201).register(_draft(phone: ' '), 't');
      expect(sent!['telefono'], isNull);
    });

    test('lee el desafío y manda el orden al verificarlo', () async {
      final challenge = await source({
        'status': 'success',
        'token': 'abc',
        'imagen': 'storage/captcha/x.png',
        'piezas': [1, 0, 2, 3],
        'total_piezas': 4,
        'columnas': 2,
        'filas': 2,
      }).getCaptcha();
      expect(path, '/api/captcha/desafio');
      expect(challenge.token, 'abc');
      expect(challenge.order, [1, 0, 2, 3]);
      expect([challenge.columns, challenge.rows], [2, 2]);

      await source({'status': 'success'}).verifyCaptcha('abc', [0, 1, 2, 3]);
      expect(path, '/api/captcha/verificar');
      expect(sent, {'token': 'abc', 'orden': [0, 1, 2, 3]});
    });

    test('recuperar contraseña manda solo el correo', () async {
      final message =
          await source({'message': 'Enlace enviado'}).forgotPassword('ana@correo.com');
      expect(path, '/api/forgot-password');
      expect(sent, {'email': 'ana@correo.com'});
      expect(message, 'Enlace enviado');
    });
  });

  group('Rompecabezas', () {
    testWidgets('dos toques intercambian las piezas y avisan el nuevo orden',
        (tester) async {
      List<int>? order;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CaptchaPuzzle(
            challenge: const CaptchaChallenge(
              token: 't',
              imagePath: 'x.png',
              order: [2, 0, 1],
              columns: 3,
              rows: 1,
            ),
            onChanged: (o) => order = o,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('captcha-slot-0')));
      await tester.pump();
      expect(order, isNull);

      await tester.tap(find.byKey(const Key('captcha-slot-2')));
      await tester.pump();
      expect(order, [1, 0, 2]);

      // Tocar dos veces el mismo hueco solo cancela la selección.
      await tester.tap(find.byKey(const Key('captcha-slot-1')));
      await tester.tap(find.byKey(const Key('captcha-slot-1')));
      await tester.pump();
      expect(order, [1, 0, 2]);
    });
  });

  group('Pantalla de registro', () {
    testWidgets('con datos incompletos no pide el captcha', (tester) async {
      final env = TestEnv();
      await _openRegister(tester, env);

      await _continue(tester);

      expect(find.text('Verificación'), findsNothing);
      expect(env.registrationRemote.captchasAsked, 0);
      expect(find.text('Elige el tipo de documento'), findsOneWidget);
    });

    testWidgets('resuelve el captcha, crea la cuenta y deja el correo escrito',
        (tester) async {
      final env = TestEnv();
      await _openRegister(tester, env);
      await _fillForm(tester);
      await _continue(tester);

      expect(find.text('Verificación'), findsOneWidget);

      // El desafío llega como [1, 0]: un intercambio lo deja en orden.
      await tester.tap(find.byKey(const Key('captcha-slot-0')));
      await tester.tap(find.byKey(const Key('captcha-slot-1')));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final remote = env.registrationRemote;
      expect(remote.verified, [
        [0, 1]
      ]);
      expect(remote.registered, hasLength(1));
      expect(remote.registered.single.documentTypeId, 1);
      expect(remote.registered.single.documentNumber, '12345678');
      expect(remote.registeredTokens, ['tok-1']);

      // De vuelta en el login, con el correo ya escrito.
      expect(find.text('Crear cuenta'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'ana@correo.com'), findsOneWidget);
    });

    testWidgets('con las piezas mal puestas no crea la cuenta y pide otro desafío',
        (tester) async {
      final env = TestEnv();
      await _openRegister(tester, env);
      await _fillForm(tester);
      await _continue(tester);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final remote = env.registrationRemote;
      expect(remote.registered, isEmpty);
      expect(remote.captchasAsked, 2);
      expect(find.text('Las piezas no están en el orden correcto.'), findsOneWidget);
      expect(find.text('Verificación'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza el registro se queda en el formulario',
        (tester) async {
      final env = TestEnv();
      env.registrationRemote.registerFailure =
          const ValidationException('El correo ya está registrado');
      await _openRegister(tester, env);
      await _fillForm(tester);
      await _continue(tester);

      await tester.tap(find.byKey(const Key('captcha-slot-0')));
      await tester.tap(find.byKey(const Key('captcha-slot-1')));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('El correo ya está registrado'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
    });
  });

  group('Recuperar contraseña', () {
    Future<void> open(WidgetTester tester, TestEnv env) async {
      _tall(tester);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      final link = find.text('¿Olvidaste tu contraseña?');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
    }

    testWidgets('pide el correo y confirma el envío', (tester) async {
      final env = TestEnv();
      await open(tester, env);

      await _enter(tester, 'Correo electrónico', 'ana@correo.com');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      expect(env.registrationRemote.forgotten, ['ana@correo.com']);
      expect(find.text('Te enviamos un correo para cambiar tu contraseña.'),
          findsOneWidget);
    });

    testWidgets('con un correo inválido no consulta al servidor', (tester) async {
      final env = TestEnv();
      await open(tester, env);

      await _enter(tester, 'Correo electrónico', 'no-es-correo');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      expect(env.registrationRemote.forgotten, isEmpty);
    });
  });
}
