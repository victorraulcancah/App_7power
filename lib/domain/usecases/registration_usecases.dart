import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/register_entity.dart';
import '../repositories/registration_repository.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Formato del número de documento según el tipo (ids de `/document-types`).
String? validateRegisterDocument(int typeId, String value) {
  final v = value.trim();
  if (v.isEmpty) return 'Ingresa tu número de documento';
  return switch (typeId) {
    1 => RegExp(r'^\d{8}$').hasMatch(v) ? null : 'El DNI debe tener 8 dígitos',
    6 => RegExp(r'^(10|15|17|20)\d{9}$').hasMatch(v)
        ? null
        : 'El RUC debe tener 11 dígitos y empezar con 10, 15, 17 o 20',
    3 => RegExp(r'^[A-Za-z0-9]{9,12}$').hasMatch(v)
        ? null
        : 'El carné de extranjería debe tener entre 9 y 12 caracteres',
    2 => RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(v)
        ? null
        : 'El pasaporte debe tener entre 6 y 12 caracteres',
    _ => v.length > 20 ? 'Máximo 20 caracteres' : null,
  };
}

/// Primer problema del formulario, o null si se puede continuar. Repite las
/// reglas del backend para avisar antes del captcha.
String? validateRegister(RegisterDraft d) {
  if (d.firstNames.trim().isEmpty) return 'Ingresa tus nombres';
  if (d.lastNames.trim().isEmpty) return 'Ingresa tus apellidos';
  if (!_emailRegex.hasMatch(d.email.trim())) return 'Ingresa un correo válido';

  final phone = d.phone?.trim() ?? '';
  if (phone.isNotEmpty && !RegExp(r'^9\d{8}$').hasMatch(phone)) {
    return 'El celular debe tener 9 dígitos y empezar con 9';
  }

  final document = validateRegisterDocument(d.documentTypeId, d.documentNumber);
  if (document != null) return document;

  if (d.password.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres';
  }
  if (d.password != d.passwordConfirmation) {
    return 'Las contraseñas no coinciden';
  }
  return null;
}

class GetDocumentTypesUseCase {
  final RegistrationRepository repository;
  GetDocumentTypesUseCase(this.repository);

  Future<Either<Failure, List<DocumentTypeEntity>>> call() =>
      repository.getDocumentTypes();
}

class GetCaptchaUseCase {
  final RegistrationRepository repository;
  GetCaptchaUseCase(this.repository);

  Future<Either<Failure, CaptchaChallenge>> call() => repository.getCaptcha();
}

class VerifyCaptchaUseCase {
  final RegistrationRepository repository;
  VerifyCaptchaUseCase(this.repository);

  Future<Either<Failure, void>> call(String token, List<int> order) =>
      repository.verifyCaptcha(token, order);
}

class RegisterUseCase {
  final RegistrationRepository repository;
  RegisterUseCase(this.repository);

  Future<Either<Failure, String>> call(RegisterDraft draft, String captchaToken) {
    final error = validateRegister(draft);
    if (error != null) {
      return Future.value(Either.left(ValidationFailure(error)));
    }
    return repository.register(draft, captchaToken);
  }
}

class ForgotPasswordUseCase {
  final RegistrationRepository repository;
  ForgotPasswordUseCase(this.repository);

  Future<Either<Failure, String>> call(String email) {
    if (!_emailRegex.hasMatch(email.trim())) {
      return Future.value(Either.left(
        const ValidationFailure('Ingresa un correo válido'),
      ));
    }
    return repository.forgotPassword(email.trim());
  }
}
