import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Inicia sesión. Solo se aceptan cuentas de cliente: las de administración
  /// o reparto pertenecen a otras apps y se rechazan.
  Future<Either<Failure, UserEntity>> login(String email, String password);

  /// Inicia sesión con el `id_token` de Google. Crea la cuenta si es la primera
  /// vez. Igual que [login], solo acepta clientes.
  Future<Either<Failure, UserEntity>> loginWithGoogle(String idToken);

  /// Recupera la sesión guardada en el dispositivo, o null si no hay.
  Future<Either<Failure, UserEntity?>> restoreSession();

  /// Vuelve a pedir los datos del cliente al servidor y los guarda.
  Future<Either<Failure, UserEntity>> refreshProfile();

  /// Cambia el celular del cliente (9 dígitos, empieza con 9).
  Future<Either<Failure, UserEntity>> updatePhone(String phone);

  /// Sube la foto de perfil del archivo [filePath] y devuelve el cliente con la
  /// foto nueva.
  Future<Either<Failure, UserEntity>> updatePhoto(String filePath);

  /// Quita la foto de perfil.
  Future<Either<Failure, UserEntity>> removePhoto();

  /// Cambia la contraseña. La sesión actual sigue abierta.
  Future<Either<Failure, void>> changePassword({
    required String current,
    required String next,
    required String confirmation,
  });

  Future<void> logout();

  /// Emite cuando el servidor rechaza el token guardado (venció o se abrió
  /// otra sesión con la misma cuenta).
  Stream<void> get onSessionExpired;
}
