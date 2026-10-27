import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/register_entity.dart';

abstract class RegistrationRepository {
  Future<Either<Failure, List<DocumentTypeEntity>>> getDocumentTypes();

  Future<Either<Failure, CaptchaChallenge>> getCaptcha();

  /// Comprueba el orden de las piezas. [order] es el índice de pieza que quedó
  /// en cada hueco.
  Future<Either<Failure, void>> verifyCaptcha(String token, List<int> order);

  /// Crea la cuenta. [captchaToken] es el de un desafío ya resuelto.
  Future<Either<Failure, String>> register(
    RegisterDraft draft,
    String captchaToken,
  );

  /// Envía el correo para cambiar la contraseña (el cambio se hace con el
  /// enlace del correo).
  Future<Either<Failure, String>> forgotPassword(String email);
}
