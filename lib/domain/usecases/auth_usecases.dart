import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call(String email, String password) {
    if (email.trim().isEmpty || password.isEmpty) {
      return Future.value(Either.left(
        const ValidationFailure('Ingresa tu correo y contraseña'),
      ));
    }
    return repository.login(email.trim(), password);
  }
}

class RestoreSessionUseCase {
  final AuthRepository repository;

  RestoreSessionUseCase(this.repository);

  Future<Either<Failure, UserEntity?>> call() => repository.restoreSession();
}

class RefreshProfileUseCase {
  final AuthRepository repository;

  RefreshProfileUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call() => repository.refreshProfile();
}

class UpdatePhoneUseCase {
  final AuthRepository repository;

  UpdatePhoneUseCase(this.repository);

  /// Valida el formato antes de llamar al servidor (mismas reglas que la web).
  Future<Either<Failure, UserEntity>> call(String phone) {
    final value = phone.trim();
    if (!RegExp(r'^9[0-9]{8}$').hasMatch(value)) {
      return Future.value(Either.left(const ValidationFailure(
        'Ingresa un celular peruano válido (9 dígitos, empieza con 9).',
      )));
    }
    return repository.updatePhone(value);
  }
}

/// Qué le falta a una contraseña nueva, con las reglas del backend: 8
/// caracteres, mayúscula, minúscula y número. Null si cumple.
String? validateNewPassword(String value) {
  if (value.length < 8) return 'Debe tener al menos 8 caracteres';
  if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Debe incluir una mayúscula';
  if (!RegExp(r'[a-z]').hasMatch(value)) return 'Debe incluir una minúscula';
  if (!RegExp(r'\d').hasMatch(value)) return 'Debe incluir un número';
  return null;
}

class ChangePasswordUseCase {
  final AuthRepository repository;

  ChangePasswordUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String current,
    required String next,
    required String confirmation,
  }) {
    if (current.isEmpty) {
      return Future.value(Either.left(
        const ValidationFailure('Ingresa tu contraseña actual'),
      ));
    }
    final weak = validateNewPassword(next);
    if (weak != null) {
      return Future.value(Either.left(ValidationFailure(weak)));
    }
    if (next != confirmation) {
      return Future.value(Either.left(
        const ValidationFailure('Las contraseñas no coinciden'),
      ));
    }
    return repository.changePassword(
      current: current,
      next: next,
      confirmation: confirmation,
    );
  }
}

class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<void> call() => repository.logout();
}
