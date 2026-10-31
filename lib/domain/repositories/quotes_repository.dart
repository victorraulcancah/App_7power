import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/quote_entity.dart';

abstract class QuotesRepository {
  Future<Either<Failure, List<QuoteEntity>>> getQuotes();

  /// Cancela la cotización (no la borra: queda como "Cancelado").
  Future<Either<Failure, void>> cancel(int id, {String? reason});

  /// Envía la cotización para convertirla en compra; devuelve el mensaje.
  Future<Either<Failure, String>> convertToPurchase(int id);
}
