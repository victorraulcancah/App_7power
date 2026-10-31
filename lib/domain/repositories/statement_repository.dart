import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/statement_entity.dart';

abstract class StatementRepository {
  /// Página [page] (de 50 movimientos) del estado de cuenta del cliente con
  /// código de ERP [erpCode] entre [from] y [to].
  Future<Either<Failure, AccountStatementPage>> getStatement({
    required String erpCode,
    required DateTime from,
    required DateTime to,
    int page = 1,
  });
}
