import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/info_entity.dart';
import '../../domain/repositories/info_repository.dart';
import '../datasources/info_remote_datasource.dart';

class InfoRepositoryImpl implements InfoRepository {
  final InfoRemoteDataSource remote;

  InfoRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, AboutEntity>> getAbout() =>
      guardRequest(remote.getAbout);

  @override
  Future<Either<Failure, List<ShippingStepEntity>>> getShippingSteps() =>
      guardRequest(remote.getShippingSteps);

  @override
  Future<Either<Failure, void>> sendContact(ContactMessage message) =>
      guardRequest(() => remote.sendContact(message));

  @override
  Future<Either<Failure, ClaimReceipt>> submitClaim(ClaimDraft claim) =>
      guardRequest(() => remote.submitClaim(claim));

  @override
  Future<Either<Failure, ClaimStatus>> findClaim(String number) =>
      guardRequest(() => remote.findClaim(number));
}
