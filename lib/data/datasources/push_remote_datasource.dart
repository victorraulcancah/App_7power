import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

/// Registra en el servidor el teléfono del cliente para las notificaciones push.
abstract class PushRemoteDataSource {
  /// Asocia [token] al cliente con sesión.
  Future<void> register(String token);

  /// Quita [token] (el cliente cerró sesión en este teléfono).
  Future<void> unregister(String token);
}

class PushRemoteDataSourceImpl implements PushRemoteDataSource {
  final ApiClient client;

  PushRemoteDataSourceImpl(this.client);

  @override
  Future<void> register(String token) async {
    await client.post(
      ApiConstants.devicesEndpoint,
      body: {'token': token, 'plataforma': 'android'},
    );
  }

  @override
  Future<void> unregister(String token) async {
    await client.delete(
      ApiConstants.devicesEndpoint,
      queryParameters: {'token': token},
    );
  }
}
