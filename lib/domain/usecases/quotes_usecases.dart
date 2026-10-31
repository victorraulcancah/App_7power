import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/quote_entity.dart';
import '../repositories/quotes_repository.dart';

class GetQuotesUseCase {
  final QuotesRepository repository;
  GetQuotesUseCase(this.repository);

  Future<Either<Failure, List<QuoteEntity>>> call() => repository.getQuotes();
}

class CancelQuoteUseCase {
  final QuotesRepository repository;
  CancelQuoteUseCase(this.repository);

  Future<Either<Failure, void>> call(int id, {String? reason}) =>
      repository.cancel(id, reason: reason);
}

class ConvertQuoteToPurchaseUseCase {
  final QuotesRepository repository;
  ConvertQuoteToPurchaseUseCase(this.repository);

  Future<Either<Failure, String>> call(int id) =>
      repository.convertToPurchase(id);
}
