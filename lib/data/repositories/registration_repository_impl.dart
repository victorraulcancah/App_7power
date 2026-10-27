import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/register_entity.dart';
import '../../domain/repositories/registration_repository.dart';
import '../datasources/registration_remote_datasource.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  final RegistrationRemoteDataSource remote;

  RegistrationRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<DocumentTypeEntity>>> getDocumentTypes() =>
      guardRequest(remote.getDocumentTypes);

  @override
  Future<Either<Failure, CaptchaChallenge>> getCaptcha() =>
      guardRequest(remote.getCaptcha);

  @override
  Future<Either<Failure, void>> verifyCaptcha(String token, List<int> order) =>
      guardRequest(() => remote.verifyCaptcha(token, order));

  @override
  Future<Either<Failure, String>> register(
    RegisterDraft draft,
    String captchaToken,
  ) =>
      guardRequest(() => remote.register(draft, captchaToken));

  @override
  Future<Either<Failure, String>> forgotPassword(String email) =>
      guardRequest(() => remote.forgotPassword(email));
}
