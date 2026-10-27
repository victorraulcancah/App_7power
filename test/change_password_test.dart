import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/auth_remote_datasource.dart';
import 'package:appecommerce/domain/usecases/auth_usecases.dart';

import 'support/fakes.dart';

Future<void> _openChangePassword(WidgetTester tester, TestEnv env) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await env.authRepo.login('ana@correo.com', 'secreto');
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Datos personales'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cambiar contraseña'));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
}

Future<void> _save(WidgetTester tester) async {
  final button = find.text('Guardar contraseña');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('Reglas de la contraseña nueva', () {
    test('pide 8 caracteres, mayúscula, minúscula y número', () {
      expect(validateNewPassword('Ab1'), contains('8 caracteres'));
      expect(validateNewPassword('abcdefg1'), contains('mayúscula'));
      expect(validateNewPassword('ABCDEFG1'), contains('minúscula'));
      expect(validateNewPassword('Abcdefgh'), contains('número'));
      expect(validateNewPassword('Abcdefg1'), isNull);
    });
  });

  group('Datos enviados al servidor', () {
    test('usa los nombres de campo del backend', () async {
      late String path;
      late Map<String, dynamic> sent;
      final remote = AuthRemoteDataSourceImpl(ApiClient(
        client: MockClient((r) async {
          path = r.url.path;
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response.bytes(
            utf8.encode(jsonEncode({'success': true})),
            200,
          );
        }),
        isConnected: () async => true,
      ));

      await remote.changePassword(
        current: 'Actual123',
        next: 'Nueva1234',
        confirmation: 'Nueva1234',
      );

      expect(path, '/api/user/change-password');
      expect(sent, {
        'current_password': 'Actual123',
        'new_password': 'Nueva1234',
        'new_password_confirmation': 'Nueva1234',
      });
    });

    test('si la actual es incorrecta, muestra el motivo del servidor', () async {
      final remote = AuthRemoteDataSourceImpl(ApiClient(
        client: MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'success': false,
                'message': 'La contraseña actual es incorrecta',
                'errors': {
                  'current_password': ['La contraseña actual es incorrecta'],
                },
              })),
              422,
            )),
        isConnected: () async => true,
      ));

      expect(
        () => remote.changePassword(current: 'x', next: 'Nueva1234', confirmation: 'Nueva1234'),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'La contraseña actual es incorrecta',
        )),
      );
    });
  });

  group('Pantalla', () {
    testWidgets('cambia la contraseña y vuelve a Datos personales',
        (tester) async {
      final env = TestEnv();
      await _openChangePassword(tester, env);

      await _enter(tester, 'Contraseña actual', 'secreto');
      await _enter(tester, 'Contraseña nueva', 'Nueva1234');
      await _enter(tester, 'Confirmar contraseña nueva', 'Nueva1234');
      await _save(tester);

      expect(env.authRemote.passwordChanges, [
        {'current': 'secreto', 'next': 'Nueva1234', 'confirmation': 'Nueva1234'},
      ]);
      expect(find.text('Cambiar contraseña'), findsOneWidget); // fila de Datos personales
      expect(find.text('Guardar contraseña'), findsNothing);
    });

    testWidgets('una contraseña débil no llega al servidor', (tester) async {
      final env = TestEnv();
      await _openChangePassword(tester, env);

      await _enter(tester, 'Contraseña actual', 'secreto');
      await _enter(tester, 'Contraseña nueva', 'sololetras');
      await _enter(tester, 'Confirmar contraseña nueva', 'sololetras');
      await _save(tester);

      expect(env.authRemote.passwordChanges, isEmpty);
      expect(find.text('Debe incluir una mayúscula'), findsOneWidget);
    });

    testWidgets('si no coinciden no llega al servidor', (tester) async {
      final env = TestEnv();
      await _openChangePassword(tester, env);

      await _enter(tester, 'Contraseña actual', 'secreto');
      await _enter(tester, 'Contraseña nueva', 'Nueva1234');
      await _enter(tester, 'Confirmar contraseña nueva', 'Otra12345');
      await _save(tester);

      expect(env.authRemote.passwordChanges, isEmpty);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('con la actual incorrecta muestra el error y se queda',
        (tester) async {
      final env = TestEnv();
      await _openChangePassword(tester, env);

      await _enter(tester, 'Contraseña actual', 'equivocada');
      await _enter(tester, 'Contraseña nueva', 'Nueva1234');
      await _enter(tester, 'Confirmar contraseña nueva', 'Nueva1234');
      await _save(tester);

      expect(find.text('La contraseña actual es incorrecta'), findsOneWidget);
      expect(find.text('Guardar contraseña'), findsOneWidget);
      expect(env.authRemote.passwordChanges, isEmpty);
    });

    testWidgets('los requisitos se marcan mientras se escribe', (tester) async {
      final env = TestEnv();
      await _openChangePassword(tester, env);

      Finder icon(IconData data) => find.byIcon(data);
      expect(icon(Icons.check_circle), findsNothing);

      await _enter(tester, 'Contraseña nueva', 'Abcdefg1');
      await tester.pump();

      expect(icon(Icons.check_circle), findsNWidgets(4));
      expect(icon(Icons.radio_button_unchecked), findsNothing);
    });
  });
}
