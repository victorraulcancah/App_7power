import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/info_entity.dart';

/// Información pública de la empresa y canales de atención.
abstract class InfoRepository {
  Future<Either<Failure, AboutEntity>> getAbout();

  Future<Either<Failure, List<ShippingStepEntity>>> getShippingSteps();

  Future<Either<Failure, void>> sendContact(ContactMessage message);

  Future<Either<Failure, ClaimReceipt>> submitClaim(ClaimDraft claim);

  Future<Either<Failure, ClaimStatus>> findClaim(String number);
}
