import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/quote_entity.dart';
import '../../domain/repositories/quotes_repository.dart';
import '../datasources/quotes_remote_datasource.dart';

class QuotesRepositoryImpl implements QuotesRepository {
  final QuotesRemoteDataSource remote;

  QuotesRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<QuoteEntity>>> getQuotes() =>
      guardRequest(remote.getQuotes);

  @override
  Future<Either<Failure, void>> cancel(int id, {String? reason}) =>
      guardRequest(() => remote.cancel(id, reason: reason));
}
