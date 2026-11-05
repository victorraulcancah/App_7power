import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appecommerce/core/constants/api_constants.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/core/security/biometric_service.dart';
import 'package:appecommerce/data/datasources/auth_remote_datasource.dart';
import 'package:appecommerce/domain/usecases/auth_usecases.dart';
import 'package:appecommerce/presentation/providers/app_lock_provider.dart';
import 'package:appecommerce/presentation/providers/auth_provider.dart';
import 'package:appecommerce/presentation/utils/google_id_token.dart';
import 'package:appecommerce/presentation/widgets/lock_gate.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Login con Google: datos', () {
    test('manda el id_token y entiende la misma respuesta que /login', () async {
      late http.Request sent;
      final client = ApiClient(
        client: MockClient((r) async {
          sent = r;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'status': 'success',
              'tipo_usuario': 'cliente',
              'es_nuevo': true,
              'token': '9|abc',
              'user': {
                'id': 7,
                'nombre_completo': 'Ana Pérez',
                'email': 'ana@gmail.com',
                'foto_url': null,
              },
            })),
            200,
          );
        }),
      );

      final result = await AuthRemoteDataSourceImpl(client).loginWithGoogle('token-de-google');

      expect(sent.url.path, endsWith('/auth/google/token'));
      expect(jsonDecode(sent.body), {'id_token': 'token-de-google'});
      expect(result.userType, 'cliente');
      expect(result.token, '9|abc');
      expect(result.client?.email, 'ana@gmail.com');
    });
  });

  group('Login con Google: sesión', () {
    late TestEnv env;
    late AuthProvider auth;

    setUp(() {
      env = TestEnv(catalog: [product(1, 'Driver')]);
      auth = AuthProvider(
        loginUseCase: LoginUseCase(env.authRepo),
        logoutUseCase: LogoutUseCase(env.authRepo),
        restoreSessionUseCase: RestoreSessionUseCase(env.authRepo),
        refreshProfileUseCase: RefreshProfileUseCase(env.authRepo),
        updatePhoneUseCase: UpdatePhoneUseCase(env.authRepo),
        changePasswordUseCase: ChangePasswordUseCase(env.authRepo),
        repository: env.authRepo,
      );
    });
    tearDown(() {
      GoogleIdToken.fetch = () async => null;
    });

    test('con el token de Google se abre la sesión y queda guardada', () async {
      GoogleIdToken.fetch = () async => 'valido-123';

      final ok = await auth.loginWithGoogle();

      expect(ok, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.user?.email, testUser.email);
      expect(env.authRemote.googleTokens, ['valido-123']);
      expect(env.authLocal.session?.token, 'token-google');
    });

    test('si el cliente cancela no pasa nada y no hay mensaje de error', () async {
      GoogleIdToken.fetch = () async => null;

      final ok = await auth.loginWithGoogle();

      expect(ok, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, isEmpty);
      expect(env.authRemote.googleTokens, isEmpty);
    });

    test('si falla la hoja de Google se avisa', () async {
      GoogleIdToken.fetch = () async => throw Exception('sin servicios de Google');

      final ok = await auth.loginWithGoogle();

      expect(ok, isFalse);
      expect(auth.errorMessage, contains('Google'));
    });

    test('si el servidor rechaza el token se muestra su motivo', () async {
      GoogleIdToken.fetch = () async => 'falso';

      final ok = await auth.loginWithGoogle();

      expect(ok, isFalse);
      expect(auth.errorMessage, contains('No pudimos validar tu cuenta de Google'));
      expect(env.authLocal.session, isNull);
    });

    test('una cuenta que no es de cliente se rechaza', () async {
      env.authRemote.userType = 'admin';
      GoogleIdToken.fetch = () async => 'valido-123';

      final ok = await auth.loginWithGoogle();

      expect(ok, isFalse);
      expect(auth.errorMessage, contains('solo para clientes'));
    });
  });

  group('Login con Google: pantalla', () {
    tearDown(() {
      ApiConstants.googleLoginOverride = null;
      GoogleIdToken.fetch = () async => null;
    });

    Future<TestEnv> openLogin(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      return env;
    }

    testWidgets('sin el ID de cliente de Google el botón no aparece', (tester) async {
      ApiConstants.googleLoginOverride = false;
      await openLogin(tester);

      expect(find.text('Continuar con Google'), findsNothing);
    });

    testWidgets('con Google configurado se entra con un toque', (tester) async {
      ApiConstants.googleLoginOverride = true;
      GoogleIdToken.fetch = () async => 'valido-xyz';
      final env = await openLogin(tester);

      expect(find.text('Continuar con Google'), findsOneWidget);
      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(env.authRemote.googleTokens, ['valido-xyz']);
      expect(find.text('Continuar con Google'), findsNothing,
          reason: 'ya hay sesión: se ve la cuenta');
    });

    testWidgets('cancelar en la hoja de Google no muestra ningún error', (tester) async {
      ApiConstants.googleLoginOverride = true;
      GoogleIdToken.fetch = () async => null;
      await openLogin(tester);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('si Google falla se muestra el aviso', (tester) async {
      ApiConstants.googleLoginOverride = true;
      GoogleIdToken.fetch = () async => throw Exception('sin servicios');
      await openLogin(tester);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo iniciar sesión con Google. Intenta de nuevo.'),
          findsOneWidget);
    });
  });

  group('Bloqueo con huella', () {
    late bool supported;
    late bool fingerprintOk;
    late int prompts;
    late DateTime clock;

    AppLockProvider newLock() => AppLockProvider(now: () => clock);

    setUp(() {
      supported = true;
      fingerprintOk = true;
      prompts = 0;
      clock = DateTime(2026, 11, 5, 12);
      BiometricService.isSupported = () async => supported;
      BiometricService.authenticate = (_) async {
        prompts++;
        return fingerprintOk;
      };
    });
    tearDown(() {
      BiometricService.isSupported = () async => false;
      BiometricService.authenticate = (_) async => false;
    });

    test('sin nada guardado arranca desbloqueada y sin bloqueo', () async {
      final lock = newLock();
      await lock.load();

      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse);
      expect(lock.available, isTrue);
    });

    test('activarlo pide la huella y queda guardado', () async {
      final lock = newLock();
      await lock.load();

      final enabled = await lock.setEnabled(true);

      expect(enabled, isTrue);
      expect(prompts, 1);
      // Quien lo acaba de activar ya se identificó: no se bloquea al instante.
      expect(lock.locked, isFalse);

      // Al abrir el app otra vez arranca bloqueada.
      final next = newLock();
      await next.load();
      expect(next.enabled, isTrue);
      expect(next.locked, isTrue);
    });

    test('si la huella falla, el bloqueo no se activa', () async {
      fingerprintOk = false;
      final lock = newLock();
      await lock.load();

      expect(await lock.setEnabled(true), isFalse);
      expect(lock.enabled, isFalse);
    });

    test('apagarlo también pide la huella', () async {
      final lock = newLock();
      await lock.load();
      await lock.setEnabled(true);
      prompts = 0;

      fingerprintOk = false;
      expect(await lock.setEnabled(false), isTrue, reason: 'sin huella sigue activo');
      expect(prompts, 1);

      fingerprintOk = true;
      expect(await lock.setEnabled(false), isFalse);
    });

    test('desbloquear exige la huella', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_v1': true});
      final lock = newLock();
      await lock.load();
      expect(lock.locked, isTrue);

      fingerprintOk = false;
      expect(await lock.unlock(), isFalse);
      expect(lock.locked, isTrue);

      fingerprintOk = true;
      expect(await lock.unlock(), isTrue);
      expect(lock.locked, isFalse);
    });

    test('si el teléfono ya no puede identificar, el bloqueo se apaga solo', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_v1': true});
      supported = false;
      final lock = newLock();

      await lock.load();

      expect(lock.enabled, isFalse);
      expect(lock.locked, isFalse, reason: 'nadie queda fuera de su cuenta');
      expect((await SharedPreferences.getInstance()).getBool('biometric_lock_v1'), isFalse);
    });

    test('no se ofrece activarlo si el teléfono no puede', () async {
      supported = false;
      final lock = newLock();
      await lock.load();

      expect(await lock.setEnabled(true), isFalse);
      expect(lock.shouldOffer, isFalse);
    });

    test('al volver tras un rato fuera se bloquea; si fue poco, no', () async {
      SharedPreferences.setMockInitialValues({'biometric_lock_v1': true});
      final lock = newLock();
      await lock.load();
      await lock.unlock();

      // Un instante en segundo plano (por ejemplo, la hoja de la huella).
      lock.onBackgrounded();
      clock = clock.add(const Duration(seconds: 20));
      lock.onResumed();
      expect(lock.locked, isFalse);

      lock.onBackgrounded();
      clock = clock.add(AppLockProvider.relockAfter);
      lock.onResumed();
      expect(lock.locked, isTrue);
    });

    test('sin el bloqueo activo, salir un rato no bloquea', () async {
      final lock = newLock();
      await lock.load();

      lock.onBackgrounded();
      clock = clock.add(const Duration(hours: 1));
      lock.onResumed();

      expect(lock.locked, isFalse);
    });

    test('la oferta se hace una sola vez', () async {
      final lock = newLock();
      await lock.load();
      expect(lock.shouldOffer, isTrue);

      await lock.markOffered();
      expect(lock.shouldOffer, isFalse);

      final next = newLock();
      await next.load();
      expect(next.shouldOffer, isFalse, reason: 'queda guardado');
    });
  });

  group('Bloqueo con huella: pantalla', () {
    late bool fingerprintOk;
    late int prompts;

    setUp(() {
      fingerprintOk = true;
      prompts = 0;
      BiometricService.isSupported = () async => true;
      BiometricService.authenticate = (_) async {
        prompts++;
        return fingerprintOk;
      };
    });
    tearDown(() {
      BiometricService.isSupported = () async => false;
      BiometricService.authenticate = (_) async => false;
    });

    testWidgets('con el bloqueo activo y sesión, pide la huella al abrir y deja entrar',
        (tester) async {
      SharedPreferences.setMockInitialValues({'biometric_lock_v1': true});
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await env.authRepo.login('ana@correo.com', 'secreto');

      fingerprintOk = false;
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      // Bloqueada: se ve la pantalla de bloqueo y se pidió la huella sola.
      expect(find.text('La app está bloqueada'), findsOneWidget);
      expect(prompts, 1);

      // Reintentar con la huella buena.
      fingerprintOk = true;
      await tester.tap(find.text('Desbloquear'));
      await tester.pumpAndSettle();

      expect(find.text('La app está bloqueada'), findsNothing);
    });

    testWidgets('sin sesión no se bloquea nada', (tester) async {
      SharedPreferences.setMockInitialValues({'biometric_lock_v1': true});
      final env = TestEnv(catalog: [product(1, 'Driver')]);

      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();

      expect(find.text('La app está bloqueada'), findsNothing);
      expect(prompts, 0);
    });

    testWidgets('"Cerrar sesión y usar mi contraseña" sale de la cuenta', (tester) async {
      SharedPreferences.setMockInitialValues({'biometric_lock_v1': true});
      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await env.authRepo.login('ana@correo.com', 'secreto');

      fingerprintOk = false;
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión y usar mi contraseña'));
      await tester.pumpAndSettle();

      expect(find.text('La app está bloqueada'), findsNothing);
      expect(env.authLocal.session, isNull);
    });

    testWidgets('el interruptor de Mi cuenta activa el bloqueo con la huella',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Bloqueo con huella'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(env.lock.enabled, isTrue);
      expect(find.text('Bloqueo con huella activado'), findsOneWidget);
    });

    testWidgets('si el teléfono no puede identificar no aparece el interruptor',
        (tester) async {
      BiometricService.isSupported = () async => false;
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await env.authRepo.login('ana@correo.com', 'secreto');
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Bloqueo con huella'), findsNothing);
    });

    testWidgets('tras iniciar sesión se ofrece una vez entrar con la huella',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'ana@correo.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'secreto');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Entrar con tu huella?'), findsOneWidget);
      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();
      expect(env.lock.enabled, isTrue);

      // Cerrar sesión y volver a entrar: no se vuelve a preguntar.
      await env.authRepo.logout();
      expect(env.lock.shouldOffer, isFalse);
    });

    testWidgets('si se responde "Ahora no" tampoco se insiste', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final env = TestEnv(catalog: [product(1, 'Driver')]);
      await tester.pumpWidget(env.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'ana@correo.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'secreto');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(env.lock.enabled, isFalse);
      expect(env.lock.shouldOffer, isFalse);
      expect(LockGate.navigatorKey.currentContext, isNotNull);
      expect(
        tester.element(find.byType(LockGate)).read<AppLockProvider>().enabled,
        isFalse,
      );
    });
  });
}
