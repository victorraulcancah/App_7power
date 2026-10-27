import 'package:flutter/foundation.dart';

import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/favorites_usecases.dart';
import 'auth_aware_reload.dart';

enum FavoritesStatus { initial, loading, loaded, error }

class FavoritesProvider extends ChangeNotifier with AuthAwareReload {
  final GetFavoritesUseCase getFavoritesUseCase;
  final AddFavoriteUseCase addFavoriteUseCase;
  final RemoveFavoriteUseCase removeFavoriteUseCase;

  FavoritesProvider({
    required this.getFavoritesUseCase,
    required this.addFavoriteUseCase,
    required this.removeFavoriteUseCase,
  });

  FavoritesStatus _status = FavoritesStatus.initial;
  List<ProductEntity> _items = const [];
  String _errorMessage = '';

  FavoritesStatus get status => _status;
  List<ProductEntity> get items => _items;
  String get errorMessage => _errorMessage;

  bool isFavorite(int productId) => _items.any((p) => p.id == productId);

  /// Con sesión se cargan los favoritos del cliente; al cerrarla se vacían.
  @override
  Future<void> reloadForAuthChange() async {
    if (!isAuthenticated) {
      _items = const [];
      _status = FavoritesStatus.initial;
      notifyListeners();
      return;
    }
    await load();
  }

  Future<void> load() async {
    _status = FavoritesStatus.loading;
    notifyListeners();

    final result = await getFavoritesUseCase();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _status = FavoritesStatus.error;
      },
      (items) {
        _items = items;
        _status = FavoritesStatus.loaded;
      },
    );
    notifyListeners();
  }

  /// Agrega o quita [product]. Devuelve null si salió bien, o el motivo.
  Future<String?> toggle(ProductEntity product) async {
    final adding = !isFavorite(product.id);
    final result = adding
        ? await addFavoriteUseCase(product.id)
        : await removeFavoriteUseCase(product.id);

    final error = result.fold<String?>((f) => f.message, (_) => null);
    if (error != null) return error;

    // Se actualiza la lista local para que el corazón responda al instante.
    _items = adding
        ? [product, ..._items]
        : _items.where((p) => p.id != product.id).toList();
    notifyListeners();
    return null;
  }

  Future<String?> remove(ProductEntity product) async =>
      isFavorite(product.id) ? toggle(product) : null;
}
