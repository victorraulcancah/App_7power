import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/purchase_entity.dart';

abstract class PurchasesRepository {
  /// Compras pagadas en la tienda en línea, más recientes primero.
  Future<Either<Failure, List<PurchaseEntity>>> getOnlinePurchases();

  /// Compras en tienda física (ERP). Vacío si la cuenta no está vinculada.
  Future<Either<Failure, StorePurchasesResult>> getStorePurchases();
}
