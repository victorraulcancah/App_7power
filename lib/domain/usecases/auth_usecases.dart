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

class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<void> call() => repository.logout();
}
