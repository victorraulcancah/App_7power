import 'dart:async';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final ApiClient apiClient;

  final StreamController<void> _expired = StreamController<void>.broadcast();

  AuthRepositoryImpl({
    required this.remote,
    required this.local,
    required this.apiClient,
  }) {
    apiClient.onUnauthorized = () async {
      apiClient.authToken = null;
      await local.clearSession();
      _expired.add(null);
    };
  }

  @override
  Stream<void> get onSessionExpired => _expired.stream;

  @override
  Future<Either<Failure, UserEntity>> login(String email, String password) =>
      guardRequest(() async {
        final result = await remote.login(email, password);

        if (result.userType != 'cliente' || result.client == null) {
          // El servidor ya abrió una sesión para esa cuenta: se cierra para no
          // dejar un token activo que esta app no va a usar.
          try {
            await remote.logout(result.token);
          } catch (_) {}
          throw const ValidationException(
            'Esta app es solo para clientes de la tienda.',
          );
        }

        await local.saveSession(result.token, result.client!);
        apiClient.authToken = result.token;
        return result.client!;
      });

  @override
  Future<Either<Failure, UserEntity?>> restoreSession() =>
      guardRequest(() async {
        final session = await local.readSession();
        if (session == null) return null;
        apiClient.authToken = session.token;
        return session.user;
      });

  @override
  Future<Either<Failure, UserEntity>> refreshProfile() => guardRequest(() async {
        final user = await remote.getProfile();
        await _saveUser(user);
        return user;
      });

  @override
  Future<Either<Failure, UserEntity>> updatePhone(String phone) =>
      guardRequest(() async {
        await remote.updatePhone(phone);
        final session = await local.readSession();
        // Se conserva el resto de los datos guardados y se cambia el celular.
        final current = session?.user ?? await remote.getProfile();
        final updated = UserModel.fromEntity(current.copyWith(phone: phone));
        await _saveUser(updated);
        return updated;
      });

  Future<void> _saveUser(UserModel user) async {
    final token = apiClient.authToken;
    if (token != null) await local.saveSession(token, user);
  }

  @override
  Future<void> logout() async {
    final token = apiClient.authToken;
    // Primero se olvida la sesión en el dispositivo: aunque no haya red, el
    // usuario queda fuera. La revocación en el servidor es en el mejor esfuerzo.
    apiClient.authToken = null;
    await local.clearSession();
    if (token != null) {
      try {
        await remote.logout(token);
      } catch (_) {}
    }
  }
}
