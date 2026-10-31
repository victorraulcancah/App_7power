import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/statement_entity.dart';
import '../../domain/repositories/statement_repository.dart';
import '../datasources/statement_remote_datasource.dart';

class StatementRepositoryImpl implements StatementRepository {
  final StatementRemoteDataSource remote;

  StatementRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, AccountStatementPage>> getStatement({
    required String erpCode,
    required DateTime from,
    required DateTime to,
    int page = 1,
  }) =>
      guardRequest(() => remote.getStatement(
            erpCode: erpCode,
            from: from,
            to: to,
            page: page,
          ));
}
