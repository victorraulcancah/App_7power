import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/data/datasources/auth_remote_datasource.dart';
import 'package:appecommerce/data/models/user_model.dart';
import 'package:appecommerce/domain/entities/company_info_entity.dart';
import 'package:appecommerce/presentation/pages/support/support_page.dart';
import 'package:appecommerce/presentation/providers/auth_provider.dart';
import 'package:appecommerce/presentation/utils/whatsapp_support.dart';
import 'package:appecommerce/presentation/widgets/profile_photo.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

void main() {
  group('WhatsApp: número y mensajes', () {
    test('saca el número de un enlace o de lo que escriba la empresa', () {
      for (final raw in [
        'https://wa.me/51951127833',
        'https://wa.me/51951127833?text=Hola',
        'https://api.whatsapp.com/send?phone=51951127833&text=Hola',
        '+51 951 127 833',
        '51951127833',
        // Un celular peruano de 9 dígitos lleva el código de país.
        '951127833',
        '951-127-833',
      ]) {
        expect(WhatsAppSupport.parseNumber(raw), '51951127833', reason: raw);
      }
    });

    test('sin un número válido no inventa uno', () {
      for (final raw in [null, '', '   ', 'sin número', '12345']) {
        expect(WhatsAppSupport.parseNumber(raw), isNull, reason: '$raw');
      }
    });

    test('usa el de la empresa y, si no hay, el de la tienda web', () {
      const conWhatsapp = CompanyInfoEntity(
        name: '7power',
        social: {SocialNetwork.whatsapp: 'https://wa.me/51999888777'},
      );
      const sin = CompanyInfoEntity(name: '7power');

      expect(WhatsAppSupport.number(conWhatsapp), '51999888777');
      expect(WhatsAppSupport.number(sin), '51951127833');
      expect(WhatsAppSupport.number(null), '51951127833');
    });

    test('el enlace lleva el mensaje codificado', () {
      expect(
        WhatsAppSupport.url('51951127833', 'Hola, ¿tienen stock? 100%'),
        'https://api.whatsapp.com/send?phone=51951127833'
        '&text=Hola%2C%20%C2%BFtienen%20stock%3F%20100%25',
      );
    });

    test('la consulta de un producto lleva nombre, código y enlace', () {
      final p = product(667, 'BATERIA DE LITIO 94AH');

      final message = WhatsAppSupport.productMessage(p);

      expect(message, contains('BATERIA DE LITIO 94AH'));
      expect(message, contains('https://7power.pe/product-details/667'));
    });
  });

  group('Ayuda por WhatsApp', () {
    String? opened;

    setUp(() {
      opened = null;
      WhatsAppSupport.opener = (_, url) async => opened = url;
    });
    tearDown(() => WhatsAppSupport.opener = (_, _) async {});

    testWidgets('el ícono de la barra lleva a la ayuda y abre el chat', (tester) async {
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ayuda'));
      await tester.pumpAndSettle();
      expect(find.text('¿Necesitas ayuda?'), findsOneWidget);

      await tester.tap(find.text('Hablar con un asesor'));
      await tester.pumpAndSettle();

      expect(opened, startsWith('https://api.whatsapp.com/send?phone=51951127833'));
      expect(Uri.decodeComponent(opened!), contains(WhatsAppSupport.greeting));
    });

    testWidgets('también se llega desde "Más"', (tester) async {
      tester.view.physicalSize = const Size(800, 2800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayuda y preguntas frecuentes'));
      await tester.pumpAndSettle();

      expect(find.text('Preguntas frecuentes'), findsOneWidget);
    });

    testWidgets('las preguntas se abren y los métodos de pago salen de la empresa',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ayuda'));
      await tester.pumpAndSettle();

      expect(find.text('¿Qué métodos de pago hay?'), findsOneWidget);
      await tester.tap(find.text('¿Qué métodos de pago hay?'));
      await tester.pumpAndSettle();
      // testCompany tiene "Plin" configurado.
      expect(find.textContaining('Aceptamos: Plin'), findsOneWidget);
    });

    testWidgets('una respuesta con acción lleva a la pantalla que lo resuelve',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ayuda'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿Los productos tienen garantía?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ir al Libro de reclamaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Libro de reclamaciones'), findsWidgets);
    });

    test('las preguntas sin métodos de pago configurados mandan al WhatsApp', () {
      final items = SupportPage.faq(const []);

      final payment = items.firstWhere((i) => i.question.contains('métodos de pago'));
      expect(payment.answer, contains('WhatsApp'));
      expect(items.length, greaterThanOrEqualTo(6));
    });

    testWidgets('la ficha del producto ya no ofrece preguntar por WhatsApp',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(5, 'Driver', stock: 9)]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tienda'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ProductCard'),
        matching: find.text('Driver'),
      ).first);
      await tester.pumpAndSettle();

      expect(find.text('Producto'), findsOneWidget);
      expect(find.text('Preguntar por WhatsApp'), findsNothing);
      expect(opened, isNull);
    });
  });

  group('Foto de perfil: datos', () {
    late File photo;

    setUp(() {
      photo = File('${Directory.systemTemp.path}/foto_prueba_7power.jpg')
        ..writeAsBytesSync(List.filled(64, 7));
    });
    tearDown(() {
      if (photo.existsSync()) photo.deleteSync();
    });

    test('se sube como formulario, con el campo "foto" y la sesión del cliente',
        () async {
      late http.BaseRequest sent;
      late List<int> body;
      final client = ApiClient(
        client: MockClient((r) async {
          sent = r;
          body = r.bodyBytes;
          return http.Response(
            jsonEncode({'status': 'success', 'foto_url': '/storage/clientes/1_7.jpg'}),
            200,
          );
        }),
      )..authToken = '5|secreto';

      final url = await AuthRemoteDataSourceImpl(client).uploadPhoto(photo.path);

      expect(url, '/storage/clientes/1_7.jpg');
      expect(sent.method, 'POST');
      expect(sent.url.path, endsWith('/cliente/upload-foto'));
      expect(sent.headers['authorization'], 'Bearer 5|secreto');
      // Es multipart (no JSON) y el archivo va en el campo "foto".
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      final text = latin1.decode(body);
      expect(text, contains('name="foto"'));
      expect(text, contains('foto_prueba_7power.jpg'));
    });

    test('quitar la foto es un DELETE', () async {
      late http.BaseRequest sent;
      final client = ApiClient(
        client: MockClient((r) async {
          sent = r;
          return http.Response('{"status":"success"}', 200);
        }),
      );

      await AuthRemoteDataSourceImpl(client).deletePhoto();

      expect(sent.method, 'DELETE');
      expect(sent.url.path, endsWith('/cliente/delete-foto'));
    });

    test('si el servidor rechaza la foto, muestra su motivo', () async {
      final client = ApiClient(
        // El servidor responde en UTF-8 (con tildes).
        client: MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'errors': {'foto': ['La foto no debe pesar más de 2048 KB.']},
              })),
              422,
            )),
      );

      await expectLater(
        AuthRemoteDataSourceImpl(client).uploadPhoto(photo.path),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('2048'),
        )),
      );
    });

    test('el cliente con foto nueva conserva el resto de sus datos', () {
      final updated = testUser.copyWith(photoUrl: 'https://x/a.jpg');

      expect(updated.photoUrl, 'https://x/a.jpg');
      expect(updated.fullName, testUser.fullName);
      expect(updated.copyWith(removePhoto: true).photoUrl, isNull);
      // Sin pedir nada, la foto no cambia.
      expect(updated.copyWith(phone: '911222333').photoUrl, 'https://x/a.jpg');
    });
  });

  group('Foto de perfil: pantalla', () {
    Future<TestEnv> openAccount(WidgetTester tester, {UserModel? user}) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      if (user != null) env.authRemote.loginUser = user;
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      return env;
    }

    AuthProvider auth(WidgetTester tester) =>
        tester.element(find.byType(ProfileAvatar)).read<AuthProvider>();

    setUp(() => ProfilePhotoPicker.pick = (_) async => null);

    testWidgets('el avatar ofrece cámara y galería, y sin foto no ofrece quitar',
        (tester) async {
      await openAccount(tester);

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();

      expect(find.text('Tomar foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Quitar foto'), findsNothing);
    });

    testWidgets('elegir una foto la sube y la deja puesta', (tester) async {
      PhotoSource? asked;
      ProfilePhotoPicker.pick = (source) async {
        asked = source;
        return '/tmp/mi_foto.jpg';
      };
      final env = await openAccount(tester);

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();

      expect(asked, PhotoSource.gallery);
      expect(env.authRemote.uploadedPhotos, ['/tmp/mi_foto.jpg']);
      expect(find.text('Foto de perfil actualizada'), findsOneWidget);
      expect(auth(tester).user?.photoUrl, endsWith('/storage/clientes/1_7.jpg'));
      // Queda guardada en el equipo para el próximo arranque.
      expect(env.authLocal.session?.user.photoUrl, endsWith('/storage/clientes/1_7.jpg'));
    });

    testWidgets('la cámara pide la cámara', (tester) async {
      PhotoSource? asked;
      ProfilePhotoPicker.pick = (source) async {
        asked = source;
        return null;
      };
      await openAccount(tester);

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomar foto'));
      await tester.pumpAndSettle();

      expect(asked, PhotoSource.camera);
    });

    testWidgets('si se cancela la elección no se sube nada', (tester) async {
      final env = await openAccount(tester);

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();

      expect(env.authRemote.uploadedPhotos, isEmpty);
      expect(find.text('Foto de perfil actualizada'), findsNothing);
    });

    testWidgets('si el servidor la rechaza, se avisa y la foto no cambia',
        (tester) async {
      ProfilePhotoPicker.pick = (_) async => '/tmp/grande.jpg';
      final env = await openAccount(tester);
      env.authRemote.photoFailure =
          const ServerException('La foto no debe pesar más de 2048 KB.', '422');

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();

      expect(find.text('La foto no debe pesar más de 2048 KB.'), findsOneWidget);
      expect(auth(tester).user?.photoUrl, isNull);
    });

    testWidgets('si la cámara o la galería fallan, se avisa', (tester) async {
      ProfilePhotoPicker.pick = (_) async => throw Exception('sin permiso');
      await openAccount(tester);

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo abrir la cámara o la galería.'), findsOneWidget);
    });

    testWidgets('con foto se ofrece quitarla y se quita', (tester) async {
      final env = await openAccount(
        tester,
        user: const UserModel(
          id: 7,
          fullName: 'Ana Pérez',
          email: 'ana@correo.com',
          photoUrl: 'https://api.7power.pe/storage/clientes/vieja.jpg',
        ),
      );
      expect(auth(tester).user?.photoUrl, isNotNull);

      await tester.tap(find.byType(ProfileAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar foto'));
      await tester.pumpAndSettle();

      expect(env.authRemote.deletedPhotos, 1);
      expect(find.text('Quitaste tu foto de perfil'), findsOneWidget);
      expect(auth(tester).user?.photoUrl, isNull);
    });
  });
}
