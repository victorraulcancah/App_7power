import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Una notificación push, con los datos que manda el servidor para saber qué
/// abrir (`tipo` y, por ejemplo, `compra_id`).
class PushMessage {
  final String? title;
  final String? body;
  final Map<String, String> data;

  const PushMessage({this.title, this.body, this.data = const {}});

  /// Lo que sirve para decidir a dónde lleva: "compra", "cotizacion", "oferta".
  String? get type => data['tipo'];
}

/// El servicio de notificaciones push del teléfono. Es una interfaz para poder
/// sustituirlo en las pruebas: Firebase solo existe en un teléfono con el app
/// configurada.
abstract class PushMessaging {
  /// Prepara las notificaciones y pide el permiso. Devuelve false si no se pueden
  /// usar: el app no está configurada con Firebase o el cliente no dio permiso.
  Future<bool> init();

  /// El identificador de este teléfono para recibir notificaciones.
  Future<String?> token();

  /// Cuando Firebase renueva el identificador.
  Stream<String> get onTokenRefresh;

  /// Llegó una notificación con el app abierta.
  Stream<PushMessage> get onForeground;

  /// El cliente tocó una notificación y el app estaba en segundo plano.
  Stream<PushMessage> get onOpened;

  /// La notificación que abrió el app si estaba cerrada, o null.
  Future<PushMessage?> initialMessage();

  /// Olvida el identificador (al cerrar sesión).
  Future<void> deleteToken();
}

/// Notificaciones con Firebase Cloud Messaging.
///
/// Necesita el archivo `android/app/google-services.json` del proyecto de
/// Firebase (ver docs/NOTIFICACIONES.md). Sin él [init] devuelve false y el app
/// funciona igual, sin notificaciones.
class FirebasePushMessaging implements PushMessaging {
  bool _ready = false;

  static PushMessage _convert(RemoteMessage m) => PushMessage(
        title: m.notification?.title,
        body: m.notification?.body,
        data: {
          for (final e in m.data.entries) e.key: e.value?.toString() ?? '',
        },
      );

  @override
  Future<bool> init() async {
    if (_ready) return true;
    try {
      await Firebase.initializeApp();
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return false;
      _ready = true;
      return true;
    } catch (_) {
      // Sin configuración de Firebase (o sin Google Play Services): sin push.
      return false;
    }
  }

  // getToken/onTokenRefresh/deleteToken están marcados como obsoletos a favor de
  // `register()` y `onRegistered`, que entregan un "Firebase Installation ID"
  // pensado para otro tipo de envío. El servidor manda con la API HTTP v1 a un
  // token de registro de FCM, que es lo que devuelven estos tres.
  @override
  // ignore: deprecated_member_use
  Future<String?> token() => FirebaseMessaging.instance.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushMessage> get onForeground =>
      FirebaseMessaging.onMessage.map(_convert);

  @override
  Stream<PushMessage> get onOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_convert);

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _convert(message);
  }

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();
}
