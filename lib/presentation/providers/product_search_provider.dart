import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/search_products_usecase.dart';

enum SearchStatus {
  /// Sin nada que buscar todavía (menos de 2 letras y sin categoría).
  idle,
  loading,
  loaded,
  error,
}

/// Las sugerencias del buscador mientras se escribe, como el desplegable de la
/// web: espera un momento tras la última tecla, pide hasta 10 productos y
/// descarta las respuestas que llegan tarde.
class ProductSearchProvider extends ChangeNotifier {
  /// Letras mínimas para buscar por texto (igual que la web).
  static const int minLength = 2;

  final SearchProductsUseCase searchProductsUseCase;
  final Duration debounce;

  ProductSearchProvider({
    required this.searchProductsUseCase,
    this.debounce = const Duration(milliseconds: 300),
  });

  SearchStatus _status = SearchStatus.idle;
  List<ProductEntity> _results = const [];
  String _query = '';
  int? _categoryId;
  Timer? _timer;

  /// Identifica la última búsqueda lanzada: una respuesta que llega cuando ya
  /// hay otra más reciente se ignora.
  int _requestId = 0;

  SearchStatus get status => _status;
  List<ProductEntity> get results => _results;
  String get query => _query;
  int? get categoryId => _categoryId;

  /// Hay algo que buscar: texto de 2 letras o más, o una categoría elegida.
  static bool canSearch(String query, int? categoryId) =>
      query.trim().length >= minLength || categoryId != null;

  /// El texto o la categoría cambiaron. Busca tras la pausa de [debounce].
  void update(String query, {int? categoryId}) {
    _query = query.trim();
    _categoryId = categoryId;
    _timer?.cancel();

    if (!canSearch(_query, _categoryId)) {
      // Nada que buscar: se vacía y se ignora lo que estuviera en camino.
      _requestId++;
      _results = const [];
      _status = SearchStatus.idle;
      notifyListeners();
      return;
    }

    _status = SearchStatus.loading;
    notifyListeners();
    _timer = Timer(debounce, _search);
  }

  /// Busca ya, sin esperar la pausa (al elegir otra categoría, por ejemplo).
  Future<void> searchNow() {
    _timer?.cancel();
    if (!canSearch(_query, _categoryId)) return Future.value();
    return _search();
  }

  Future<void> _search() async {
    final id = ++_requestId;
    _status = SearchStatus.loading;
    notifyListeners();

    final result = await searchProductsUseCase(
      _query,
      categoryId: _categoryId,
    );
    if (id != _requestId) return;

    result.fold(
      (_) {
        _results = const [];
        _status = SearchStatus.error;
      },
      (products) {
        _results = products;
        _status = SearchStatus.loaded;
      },
    );
    notifyListeners();
  }

  final Map<String, Future<ProductEntity?>> _byCode = {};

  /// El producto del catálogo con ese código exacto. Sirve para completar la
  /// foto y la marca de lo comprado cuando el servidor no las manda (las
  /// compras en tienda vienen del ERP, que solo trae el código). Recuerda lo
  /// encontrado: cada código se pide una sola vez.
  Future<ProductEntity?> lookupByCode(String code) {
    final clean = code.trim();
    final key = clean.toUpperCase();
    if (clean.length < minLength) return Future.value(null);

    return _byCode.putIfAbsent(key, () async {
      final result = await searchProductsUseCase(clean);
      return result.fold((_) {
        // Si falló (sin red) se vuelve a intentar la próxima vez.
        _byCode.remove(key);
        return null;
      }, (products) {
        for (final p in products) {
          if ((p.code ?? '').trim().toUpperCase() == key) return p;
        }
        return null;
      });
    });
  }

  /// Vacía todo (al abrir o cerrar el buscador).
  void reset() {
    _timer?.cancel();
    _requestId++;
    _query = '';
    _categoryId = null;
    _results = const [];
    _status = SearchStatus.idle;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
