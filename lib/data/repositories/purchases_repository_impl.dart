import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/purchase_entity.dart';
import '../../domain/repositories/purchases_repository.dart';
import '../datasources/purchases_remote_datasource.dart';

class PurchasesRepositoryImpl implements PurchasesRepository {
  final PurchasesRemoteDataSource remote;

  PurchasesRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<PurchaseEntity>>> getOnlinePurchases() =>
      guardRequest(remote.getOnlinePurchases);

  @override
  Future<Either<Failure, StorePurchasesResult>> getStorePurchases() =>
      guardRequest(remote.getStorePurchases);
}
