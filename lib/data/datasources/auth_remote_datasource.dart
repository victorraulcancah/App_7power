import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

class LoginResult {
  /// "cliente", "admin" o "motorizado": el endpoint es compartido.
  final String userType;
  final String token;
  final UserModel? client;

  const LoginResult({required this.userType, required this.token, this.client});
}

abstract class AuthRemoteDataSource {
  Future<LoginResult> login(String email, String password);

  /// Revoca [token] en el servidor.
  Future<void> logout(String token);

  Future<UserModel> getProfile();

  Future<void> updatePhone(String phone);

  Future<void> changePassword({
    required String current,
    required String next,
    required String confirmation,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient client;

  AuthRemoteDataSourceImpl(this.client);

  @override
  Future<LoginResult> login(String email, String password) async {
    final response = await client.post(
      ApiConstants.loginEndpoint,
      body: {'email': email, 'password': password},
    );
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final type = body['tipo_usuario']?.toString() ?? '';

    return LoginResult(
      userType: type,
      token: body['token'].toString(),
      // Solo se interpreta el usuario si es un cliente: el de un admin tiene
      // otra forma.
      client: type == 'cliente'
          ? UserModel.fromJson(body['user'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Future<void> logout(String token) async {
    await client.post(
      ApiConstants.logoutEndpoint,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  @override
  Future<UserModel> getProfile() async {
    final response = await client.get(ApiConstants.profileEndpoint);
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return UserModel.fromJson(body['user'] as Map<String, dynamic>);
  }

  @override
  Future<void> updatePhone(String phone) async {
    await client.patch(ApiConstants.phoneEndpoint, body: {'telefono': phone});
  }

  @override
  Future<void> changePassword({
    required String current,
    required String next,
    required String confirmation,
  }) async {
    await client.post(ApiConstants.changePasswordEndpoint, body: {
      'current_password': current,
      'new_password': next,
      'new_password_confirmation': confirmation,
    });
  }
}
