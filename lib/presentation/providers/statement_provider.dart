import 'package:flutter/foundation.dart';

import '../../data/datasources/statement_remote_datasource.dart';
import '../../domain/entities/statement_entity.dart';
import '../../domain/usecases/statement_usecases.dart';
import 'auth_aware_reload.dart';
import 'load_status.dart';

/// Estado de cuenta del cliente: resumen de crédito y deuda, y sus
/// movimientos de un rango de fechas (50 por página, se piden al bajar).
class StatementProvider extends ChangeNotifier with AuthAwareReload {
  final GetStatementUseCase getStatementUseCase;

  /// Si el ERP está configurado. Sin su dirección no se ofrece la pantalla.
  final bool available;

  StatementProvider({
    required this.getStatementUseCase,
    required this.available,
  });

  String? _erpCode;
  LoadStatus _status = LoadStatus.initial;
  String _errorMessage = '';
  AccountSummary _summary = const AccountSummary();
  List<AccountMovement> _movements = const [];
  int _total = 0;
  int _page = 1;
  bool _loadingMore = false;
  String _search = '';
  late DateTime _from;
  late DateTime _to;

  /// Identifica la última consulta: si llega una respuesta de otra anterior
  /// (se cambió el rango mientras cargaba), se ignora.
  int _requestId = 0;

  LoadStatus get status => _status;
  String get errorMessage => _errorMessage;
  AccountSummary get summary => _summary;
  int get total => _total;
  bool get isLoadingMore => _loadingMore;
  DateTime get from => _from;
  DateTime get to => _to;
  String get search => _search;

  /// Sin código de ERP el cliente no tiene su cuenta vinculada.
  bool get isLinked => (_erpCode ?? '').isNotEmpty;

  /// Movimientos ya cargados.
  int get loaded => _movements.length;
  bool get hasMore => _movements.length < _total;

  /// Los movimientos que coinciden con la búsqueda (por descripción).
  List<AccountMovement> get movements {
    final q = _search.trim().toLowerCase();
    return q.isEmpty
        ? _movements
        : _movements.where((m) => m.description.toLowerCase().contains(q)).toList();
  }

  @override
  Future<void> reloadForAuthChange() async {
    // Otra cuenta (o ninguna): no se conserva nada de la anterior.
    _requestId++;
    _erpCode = null;
    _status = LoadStatus.initial;
    _movements = const [];
    _summary = const AccountSummary();
    _total = 0;
    _search = '';
    notifyListeners();
  }

  /// Abre el estado de cuenta de [erpCode], con el mes en curso.
  Future<void> open(String? erpCode) {
    final now = DateTime.now();
    _erpCode = erpCode;
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _search = '';
    return _loadFirstPage();
  }

  Future<void> setRange(DateTime from, DateTime to) {
    _from = from;
    _to = to;
    return _loadFirstPage();
  }

  Future<void> reload() => _loadFirstPage();

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  Future<void> _loadFirstPage() async {
    final id = ++_requestId;
    _status = LoadStatus.loading;
    _loadingMore = false;
    _page = 1;
    notifyListeners();

    final result = await getStatementUseCase(
      erpCode: _erpCode,
      from: _from,
      to: _to,
    );
    if (id != _requestId) return;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _status = LoadStatus.error;
      },
      (page) {
        _summary = page.summary;
        _movements = page.movements;
        _total = page.total;
        _status = LoadStatus.loaded;
      },
    );
    notifyListeners();
  }

  /// Agrega la página siguiente al final de la lista.
  Future<void> loadMore() async {
    if (_loadingMore || !hasMore || _status != LoadStatus.loaded) return;

    final id = _requestId;
    _loadingMore = true;
    notifyListeners();

    final result = await getStatementUseCase(
      erpCode: _erpCode,
      from: _from,
      to: _to,
      page: _page + 1,
    );
    if (id != _requestId) return;

    result.fold(
      // Un fallo al paginar no tira lo ya cargado: se reintenta al volver a
      // llegar al final.
      (_) {},
      (page) {
        _page += 1;
        _movements = [..._movements, ...page.movements];
        _total = page.total;
      },
    );
    _loadingMore = false;
    notifyListeners();
  }

  /// Cantidad de movimientos por página (para quien arme la paginación).
  static const int pageSize = statementPageSize;
}
