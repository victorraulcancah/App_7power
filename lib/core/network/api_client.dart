import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';

class NetworkInfo {
  static Future<bool> get isConnected async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}

class ApiClient {
  final http.Client _client;

  /// Token del cliente con sesión iniciada. Lo fija `AuthProvider`; mientras
  /// sea null las peticiones salen sin autenticación (navegación como invitado).
  String? authToken;

  /// Se llama cuando el servidor rechaza un token que sí se envió (sesión
  /// vencida, o abierta en otro dispositivo: el backend solo permite una).
  void Function()? onUnauthorized;

  final Future<bool> Function() _isConnected;

  /// [isConnected] se puede sustituir en los tests para no depender de la red.
  ApiClient({http.Client? client, Future<bool> Function()? isConnected})
      : _client = client ?? http.Client(),
        _isConnected = isConnected ?? (() => NetworkInfo.isConnected);

  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) =>
      _send(
        (uri, h) => _client.get(uri, headers: h),
        endpoint,
        headers: headers,
        queryParameters: queryParameters,
      );

  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _send(
        (uri, h) => _client.post(uri, headers: h, body: _encode(body)),
        endpoint,
        headers: headers,
      );

  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _send(
        (uri, h) => _client.put(uri, headers: h, body: _encode(body)),
        endpoint,
        headers: headers,
      );

  Future<http.Response> patch(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      _send(
        (uri, h) => _client.patch(uri, headers: h, body: _encode(body)),
        endpoint,
        headers: headers,
      );

  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) =>
      _send(
        (uri, h) => _client.delete(uri, headers: h),
        endpoint,
        headers: headers,
      );

  Future<http.Response> _send(
    Future<http.Response> Function(Uri uri, Map<String, String> headers) call,
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
  }) async {
    if (!await _isConnected()) {
      throw const NetworkException('Sin conexión a internet');
    }

    final token = authToken;
    final mergedHeaders = {
      ...ApiConstants.defaultHeaders,
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    try {
      final response = await call(_buildUri(endpoint, queryParameters), mergedHeaders)
          .timeout(ApiConstants.connectionTimeout);
      return _handleResponse(response, hadToken: token != null);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Los mapas y listas se envían como JSON; el resto, tal cual.
  Object? _encode(Object? body) =>
      (body is Map || body is List) ? jsonEncode(body) : body;

  Uri _buildUri(String endpoint, [Map<String, String>? queryParameters]) {
    final fullUrl = ApiConstants.baseUrl + endpoint;

    if (queryParameters != null && queryParameters.isNotEmpty) {
      return Uri.parse(fullUrl).replace(queryParameters: queryParameters);
    }

    return Uri.parse(fullUrl);
  }

  http.Response _handleResponse(http.Response response, {required bool hadToken}) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;

    // Laravel devuelve `message` y, en validaciones, `errors`: se muestra el
    // texto del servidor en vez de un genérico "Error 422".
    final message = _serverMessage(response);

    if (status == 401) {
      if (hadToken) {
        onUnauthorized?.call();
        throw AuthException(message ?? 'Sesión expirada', '401');
      }
      throw AuthException(message ?? 'Credenciales incorrectas', '401');
    }
    if (status >= 400 && status < 500) {
      throw ServerException(message ?? 'Error del cliente: $status', '$status');
    }
    throw ServerException(message ?? 'Error del servidor: $status', '$status');
  }

  String? _serverMessage(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map) return null;

      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      // Algunos endpoints usan `error` en lugar de `message`. En un 500 el
      // `message` es genérico ("Error al crear cotización") y el motivo real
      // (stock, montos que no cuadran...) viene en `error`, como lo muestra la
      // web; se recorta para no enseñar un volcado largo.
      final error = body['error'];
      if (response.statusCode >= 500 && error is String && error.isNotEmpty) {
        return error.length > 240 ? '${error.substring(0, 240)}…' : error;
      }
      final message = body['message'] ?? error;
      return message is String && message.isNotEmpty ? message : null;
    } catch (_) {
      return null;
    }
  }

  Exception _handleError(dynamic error) {
    if (error is AppException) {
      return error;
    } else if (error is SocketException) {
      return const NetworkException('Error de conexión');
    } else if (error is HttpException) {
      return NetworkException('Error HTTP: ${error.message}');
    } else {
      return AppException('Error inesperado: $error');
    }
  }

  void dispose() {
    _client.close();
  }
}
