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

class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<void> call() => repository.logout();
}
