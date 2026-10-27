import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

class StoredSession {
  final String token;
  final UserModel user;

  const StoredSession(this.token, this.user);
}

abstract class AuthLocalDataSource {
  Future<void> saveSession(String token, UserModel user);

  Future<StoredSession?> readSession();

  Future<void> clearSession();
}

/// Guarda el token en el almacén seguro del sistema (Keystore en Android,
/// Keychain en iOS).
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const _tokenKey = 'auth_token';

  final FlutterSecureStorage storage;

  AuthLocalDataSourceImpl([FlutterSecureStorage? storage])
      : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> saveSession(String token, UserModel user) async {
    await storage.write(key: _tokenKey, value: token);
    await storage.write(key: AppConstants.userStorageKey, value: user.encode());
  }

  @override
  Future<StoredSession?> readSession() async {
    final token = await storage.read(key: _tokenKey);
    final user = await storage.read(key: AppConstants.userStorageKey);
    if (token == null || user == null) return null;

    try {
      return StoredSession(token, UserModel.decode(user));
    } catch (_) {
      // Datos corruptos: es más seguro empezar sin sesión.
      await clearSession();
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    await storage.delete(key: _tokenKey);
    await storage.delete(key: AppConstants.userStorageKey);
  }
}
