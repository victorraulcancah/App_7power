import 'package:flutter/foundation.dart';

import '../../domain/entities/quote_entity.dart';
import '../../domain/usecases/quotes_usecases.dart';
import 'auth_aware_reload.dart';
import 'load_status.dart';

class QuotesProvider extends ChangeNotifier with AuthAwareReload {
  final GetQuotesUseCase getQuotesUseCase;
  final CancelQuoteUseCase cancelQuoteUseCase;

  QuotesProvider({
    required this.getQuotesUseCase,
    required this.cancelQuoteUseCase,
  });

  LoadStatus _status = LoadStatus.initial;
  List<QuoteEntity> _items = const [];
  String _errorMessage = '';

  LoadStatus get status => _status;
  List<QuoteEntity> get items => _items;
  String get errorMessage => _errorMessage;

  @override
  Future<void> reloadForAuthChange() async {
    _items = const [];
    _status = LoadStatus.initial;
    notifyListeners();
  }

  Future<void> load() async {
    _status = LoadStatus.loading;
    notifyListeners();

    final result = await getQuotesUseCase();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _status = LoadStatus.error;
      },
      (items) {
        _items = items;
        _status = LoadStatus.loaded;
      },
    );
    notifyListeners();
  }

  /// Devuelve null si se canceló, o el motivo por el que no se pudo (por
  /// ejemplo, que un vendedor ya la está atendiendo).
  Future<String?> cancel(QuoteEntity quote) async {
    final result = await cancelQuoteUseCase(quote.id);
    final error = result.fold<String?>((f) => f.message, (_) => null);
    if (error != null) return error;
    await load();
    return null;
  }
}
