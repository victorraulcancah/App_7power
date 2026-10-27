import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/purchase_entity.dart';
import '../repositories/purchases_repository.dart';

class GetOnlinePurchasesUseCase {
  final PurchasesRepository repository;
  GetOnlinePurchasesUseCase(this.repository);

  Future<Either<Failure, List<PurchaseEntity>>> call() =>
      repository.getOnlinePurchases();
}

class GetStorePurchasesUseCase {
  final PurchasesRepository repository;
  GetStorePurchasesUseCase(this.repository);

  Future<Either<Failure, StorePurchasesResult>> call() =>
      repository.getStorePurchases();
}
