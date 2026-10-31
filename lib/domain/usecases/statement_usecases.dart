import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/statement_entity.dart';
import '../repositories/statement_repository.dart';

class GetStatementUseCase {
  final StatementRepository repository;
  GetStatementUseCase(this.repository);

  Future<Either<Failure, AccountStatementPage>> call({
    required String? erpCode,
    required DateTime from,
    required DateTime to,
    int page = 1,
  }) {
    final code = erpCode?.trim() ?? '';
    if (code.isEmpty) {
      return Future.value(Either.left(const ValidationFailure(
        'Tu cuenta aún no está vinculada con tu historial en 7Power.',
      )));
    }
    if (to.isBefore(from)) {
      return Future.value(Either.left(const ValidationFailure(
        'La fecha final no puede ser anterior a la inicial.',
      )));
    }
    return repository.getStatement(
      erpCode: code,
      from: from,
      to: to,
      page: page,
    );
  }
}
