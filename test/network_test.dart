import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';

void main() {
  test('por defecto pide directo, sin comprobar la conexión antes de cada petición',
      () async {
    var peticiones = 0;
    final client = ApiClient(
      client: MockClient((_) async {
        peticiones++;
        return http.Response('{}', 200);
      }),
    );

    await client.get('/banners/publicos');
    await client.get('/banners/publicos');

    expect(peticiones, 2);
  });

  test('sin red avisa "Sin conexión a internet"', () async {
    final client = ApiClient(
      client: MockClient((_) async => throw const SocketException('sin red')),
    );

    await expectLater(
      client.get('/banners/publicos'),
      throwsA(isA<NetworkException>()
          .having((e) => e.message, 'message', 'Sin conexión a internet')),
    );
  });

  test('un fallo de conexión del cliente HTTP también es "sin conexión"', () async {
    final client = ApiClient(
      client: MockClient(
          (_) async => throw http.ClientException('Failed host lookup')),
    );

    await expectLater(
      client.get('/banners/publicos'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('si el servidor tarda demasiado lo dice, en vez de un error genérico', () async {
    final client = ApiClient(
      client: MockClient((_) async => throw TimeoutException('lento')),
    );

    await expectLater(
      client.get('/banners/publicos'),
      throwsA(isA<NetworkException>()
          .having((e) => e.message, 'message', contains('tardó demasiado'))),
    );
  });

  test('los tests pueden simular que no hay conexión', () async {
    final client = ApiClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      isConnected: () async => false,
    );

    await expectLater(
      client.get('/banners/publicos'),
      throwsA(isA<NetworkException>()),
    );
  });
}
