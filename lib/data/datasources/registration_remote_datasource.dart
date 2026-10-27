import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/register_entity.dart';

abstract class RegistrationRemoteDataSource {
  Future<List<DocumentTypeEntity>> getDocumentTypes();

  Future<CaptchaChallenge> getCaptcha();

  Future<void> verifyCaptcha(String token, List<int> order);

  Future<String> register(RegisterDraft draft, String captchaToken);

  Future<String> forgotPassword(String email);
}

class RegistrationRemoteDataSourceImpl implements RegistrationRemoteDataSource {
  final ApiClient client;

  RegistrationRemoteDataSourceImpl(this.client);

  dynamic _json(List<int> bytes) => jsonDecode(utf8.decode(bytes));

  @override
  Future<List<DocumentTypeEntity>> getDocumentTypes() async {
    final response = await client.get(ApiConstants.documentTypesEndpoint);
    return (_json(response.bodyBytes) as List)
        .cast<Map<String, dynamic>>()
        .map((t) => DocumentTypeEntity(
              id: (t['id'] as num).toInt(),
              name: t['nombre']?.toString() ?? '',
            ))
        .toList();
  }

  @override
  Future<CaptchaChallenge> getCaptcha() async {
    final response = await client.get(ApiConstants.captchaChallengeEndpoint);
    final body = _json(response.bodyBytes) as Map<String, dynamic>;
    return CaptchaChallenge(
      token: body['token'].toString(),
      imagePath: body['imagen'].toString(),
      order: (body['piezas'] as List).map((p) => (p as num).toInt()).toList(),
      columns: (body['columnas'] as num).toInt(),
      rows: (body['filas'] as num).toInt(),
    );
  }

  @override
  Future<void> verifyCaptcha(String token, List<int> order) async {
    await client.post(
      ApiConstants.captchaVerifyEndpoint,
      body: {'token': token, 'orden': order},
    );
  }

  @override
  Future<String> register(RegisterDraft d, String captchaToken) async {
    final response = await client.post(ApiConstants.registerEndpoint, body: {
      'nombres': d.firstNames.trim(),
      'apellidos': d.lastNames.trim(),
      'email': d.email.trim(),
      'password': d.password,
      'password_confirmation': d.passwordConfirmation,
      'telefono': (d.phone ?? '').trim().isEmpty ? null : d.phone!.trim(),
      'tipo_documento_id': d.documentTypeId,
      'numero_documento': d.documentNumber.trim(),
      'captcha_token': captchaToken,
    });
    return (_json(response.bodyBytes) as Map<String, dynamic>)['message']
            ?.toString() ??
        'Cuenta creada. Ya puedes iniciar sesión.';
  }

  @override
  Future<String> forgotPassword(String email) async {
    final response = await client.post(
      ApiConstants.forgotPasswordEndpoint,
      body: {'email': email},
    );
    return (_json(response.bodyBytes) as Map<String, dynamic>)['message']
            ?.toString() ??
        'Te enviamos un correo para cambiar tu contraseña.';
  }
}
