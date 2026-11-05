import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/core/push/push_messaging.dart';
import 'package:appecommerce/data/datasources/push_remote_datasource.dart';
import 'package:appecommerce/presentation/pages/account/purchases_page.dart';
import 'package:appecommerce/presentation/pages/account/quotes_page.dart';
import 'package:appecommerce/presentation/pages/promotions/offers_page.dart';
import 'package:appecommerce/presentation/utils/push_route.dart';

import 'support/fakes.dart';

void main() {
  group('Datos: registrar el teléfono', () {
    test('registrar manda el token con la sesión del cliente', () async {
      late http.Request sent;
      final client = ApiClient(
        client: MockClient((r) async {
          sent = r;
          return http.Response('{"status":"success"}', 200);
        }),
      )..authToken = '5|secreto';

      await PushRemoteDataSourceImpl(client).register('tok-1');

      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/cliente/dispositivos'));
      expect(sent.headers['authorization'], 'Bearer 5|secreto');
      expect(jsonDecode(sent.body), {'token': 'tok-1', 'plataforma': 'android'});
    });

    test('quitar es un DELETE con el token en la dirección', () async {
      late http.Request sent;
      final client = ApiClient(
        client: MockClient((r) async {
          sent = r;
          return http.Response('{"status":"success"}', 200);
        }),
      );

      await PushRemoteDataSourceImpl(client).unregister('tok con/símbolos');

      expect(sent.method, 'DELETE');
      expect(sent.url.path, endsWith('/cliente/dispositivos'));
      expect(sent.url.queryParameters['token'], 'tok con/símbolos');
    });
  });

  group('A dónde lleva cada aviso', () {
    PushMessage message(String? type) =>
        PushMessage(title: 'x', data: {'tipo': ?type});

    test('compras, cotizaciones y ofertas abren su pantalla', () {
      expect(PushRoute.pageFor(message('compra')), isA<PurchasesPage>());
      expect(PushRoute.pageFor(message('cotizacion')), isA<QuotesPage>());
      expect(PushRoute.pageFor(message('oferta')), isA<OffersPage>());
    });

    test('un tipo desconocido o sin tipo no abre nada', () {
      expect(PushRoute.pageFor(message('otra-cosa')), isNull);
      expect(PushRoute.pageFor(message(null)), isNull);
    });
  });

  group('Notificaciones push', () {
    late TestEnv env;

    Future<void> openApp(WidgetTester tester, {bool loggedIn = false}) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      if (loggedIn) await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
    }

    Future<void> login(WidgetTester tester) async {
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'ana@correo.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'secreto');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();
    }

    testWidgets('sin Firebase configurado no pasa nada y el app funciona igual',
        (tester) async {
      await openApp(tester);
      env.pushMessaging.configured = false;

      await login(tester);

      expect(env.pushMessaging.initCalls, greaterThan(0));
      expect(env.pushRemote.registered, isEmpty);
    });

    testWidgets('al iniciar sesión se registra el teléfono del cliente', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      // Sin sesión todavía no se registra nada.
      expect(env.pushRemote.registered, isEmpty);

      await login(tester);

      expect(env.pushRemote.registered, ['tok-telefono-1']);
    });

    testWidgets('con la sesión restaurada al abrir también se registra',
        (tester) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      expect(env.pushRemote.registered, ['tok-telefono-1']);
    });

    testWidgets('si Firebase renueva el identificador, se registra el nuevo',
        (tester) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      env.pushMessaging.refreshController.add('tok-nuevo');
      await tester.pumpAndSettle();

      expect(env.pushRemote.registered, ['tok-telefono-1', 'tok-nuevo']);
    });

    testWidgets('si no hay red al registrar, el app sigue sin errores', (tester) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      env.pushRemote.failure = Exception('sin red');
      await env.authRepo.login('ana@correo.com', 'secreto');

      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('al cerrar sesión se quita el teléfono antes de salir', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();

      expect(env.pushRemote.unregistered, ['tok-telefono-1']);
      expect(env.pushMessaging.deletedTokens, 1);
      expect(env.authLocal.session, isNull);
    });

    testWidgets('un aviso con el app abierta se muestra con "Ver" y lleva a la compra',
        (tester) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      env.pushMessaging.foregroundController.add(const PushMessage(
        title: 'Tu pedido va en camino',
        body: 'Tu compra PE-15 salió a entrega.',
        data: {'tipo': 'compra', 'compra_id': '15'},
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu pedido va en camino: Tu compra PE-15'), findsOneWidget);
      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();

      expect(find.byType(PurchasesPage), findsOneWidget);
    });

    testWidgets('un aviso sin destino se muestra pero no ofrece "Ver"', (tester) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      env.pushMessaging.foregroundController
          .add(const PushMessage(title: 'Novedades', body: 'Mira la tienda'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Novedades: Mira la tienda'), findsOneWidget);
      expect(find.text('Ver'), findsNothing);
    });

    testWidgets('tocar la notificación abre la pantalla del aviso', (tester) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      env.pushMessaging.openedController
          .add(const PushMessage(data: {'tipo': 'cotizacion'}));
      await tester.pumpAndSettle();

      expect(find.byType(QuotesPage), findsOneWidget);
    });

    testWidgets('si el app se abrió desde una notificación, va directo a su pantalla',
        (tester) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      env.pushMessaging.initial = const PushMessage(data: {'tipo': 'compra'});
      await env.authRepo.login('ana@correo.com', 'secreto');

      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      expect(find.byType(PurchasesPage), findsOneWidget);
    });

    testWidgets('sin sesión no se escucha ningún aviso', (tester) async {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      env.pushMessaging.configured = true;
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      env.pushMessaging.openedController
          .add(const PushMessage(data: {'tipo': 'compra'}));
      await tester.pumpAndSettle();

      expect(find.byType(PurchasesPage), findsNothing);
    });
  });
}
