import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/info_remote_datasource.dart';
import 'package:appecommerce/domain/entities/info_entity.dart';

import 'support/fakes.dart';

Future<void> _openMyClaims(WidgetTester tester, TestEnv env) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await env.authRepo.login('ana@correo.com', 'secreto');
  await tester.pumpWidget(env.app());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mis reclamos'));
  await tester.pumpAndSettle();
}

void main() {
  group('Datos del servidor', () {
    InfoRemoteDataSourceImpl source(Object body, {int status = 200, void Function(http.Request)? onRequest}) =>
        InfoRemoteDataSourceImpl(ApiClient(
          client: MockClient((r) async {
            onRequest?.call(r);
            return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
          }),
          isConnected: () async => true,
        ));

    test('lee la lista de reclamos del cliente', () async {
      late http.Request request;
      final remote = source({
        'status': 'success',
        'reclamos': [
          {
            'numero_reclamo': 'REC-2026-00007',
            'estado': 'resuelto',
            'tipo_solicitud': 'reclamo',
            'tipo_bien': 'producto',
            'nombre_producto': 'Driver 400W',
            'detalle_reclamo': 'No funciona a los dos días',
            'fecha_limite_respuesta': '2026-11-20T00:00:00.000000Z',
            'respuesta_proveedor': 'Lo cambiamos sin costo',
            'fecha_respuesta': '2026-10-25T00:00:00.000000Z',
            'created_at': '2026-10-21T15:00:00.000000Z',
          },
          {
            'numero_reclamo': 'REC-2026-00008',
            'estado': 'pendiente',
            'tipo_solicitud': 'queja',
            'descripcion_bien': 'Atención en tienda',
            'respuesta_proveedor': null,
          },
        ],
        'debug': {'user_id': 7, 'user_email': 'ana@correo.com'},
      }, onRequest: (r) => request = r);

      final claims = await remote.getMyClaims();

      expect(request.url.path, '/api/reclamos/mis-reclamos');
      expect(claims, hasLength(2));
      expect(claims[0].number, 'REC-2026-00007');
      expect(claims[0].status, 'resuelto');
      expect(claims[0].productName, 'Driver 400W');
      expect(claims[0].detail, 'No funciona a los dos días');
      expect(claims[0].response, 'Lo cambiamos sin costo');
      expect(claims[0].responseDate, DateTime.utc(2026, 10, 25));
      expect(claims[1].requestType, 'queja');
      expect(claims[1].productName, 'Atención en tienda');
      expect(claims[1].response, isNull);
    });

    test('sin reclamos devuelve una lista vacía', () async {
      expect(await source({'status': 'success', 'reclamos': []}).getMyClaims(), isEmpty);
    });
  });

  group('Pantalla', () {
    testWidgets('muestra cada reclamo con su estado y la respuesta', (tester) async {
      final env = TestEnv();
      env.infoRemote.myClaims = [
        ClaimStatus(
          number: 'REC-2026-00007',
          status: 'resuelto',
          requestType: 'reclamo',
          productName: 'Driver 400W',
          detail: 'No funciona a los dos días',
          response: 'Lo cambiamos sin costo',
          responseDate: DateTime(2026, 10, 25),
          createdAt: DateTime(2026, 10, 21),
        ),
        ClaimStatus(
          number: 'REC-2026-00008',
          status: 'pendiente',
          requestType: 'queja',
          deadline: DateTime(2026, 11, 20),
        ),
      ];
      await _openMyClaims(tester, env);

      expect(find.text('REC-2026-00007'), findsOneWidget);
      expect(find.text('Resuelto'), findsOneWidget);
      expect(find.text('Driver 400W'), findsOneWidget);
      expect(find.text('Respuesta de la empresa'), findsOneWidget);
      expect(find.text('Lo cambiamos sin costo'), findsOneWidget);

      expect(find.text('REC-2026-00008'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.textContaining('Respuesta hasta el'), findsOneWidget);
    });

    testWidgets('sin reclamos lleva al libro de reclamaciones', (tester) async {
      final env = TestEnv();
      await _openMyClaims(tester, env);

      expect(find.text('Aún no tienes reclamos'), findsOneWidget);
      await tester.tap(find.text('Ir al libro de reclamaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Libro de reclamaciones'), findsWidgets);
    });

    testWidgets('si falla muestra el motivo y permite reintentar', (tester) async {
      final env = TestEnv();
      env.infoRemote.failure = const ServerException('No se pudo cargar', '500');
      await _openMyClaims(tester, env);

      expect(find.text('No se pudo cargar'), findsOneWidget);

      env.infoRemote.failure = null;
      env.infoRemote.myClaims = [
        const ClaimStatus(number: 'REC-2026-00009', status: 'en_proceso'),
      ];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('REC-2026-00009'), findsOneWidget);
      expect(find.text('En proceso'), findsOneWidget);
    });
  });
}
