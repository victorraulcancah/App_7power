import '../errors/exceptions.dart';
import '../errors/failures.dart';
import '../utils/either.dart';

/// Ejecuta una llamada de la capa de datos y traduce sus excepciones a
/// fallos del dominio. Lo usan todos los repositorios.
Future<Either<Failure, T>> guardRequest<T>(Future<T> Function() call) async {
  try {
    return Either.right(await call());
  } on NetworkException catch (e) {
    return Either.left(NetworkFailure(e.message));
  } on AuthException catch (e) {
    return Either.left(AuthenticationFailure(e.message));
  } on AppException catch (e) {
    return Either.left(ServerFailure(e.message));
  } catch (_) {
    return Either.left(const ServerFailure('Respuesta inválida del servidor'));
  }
}
