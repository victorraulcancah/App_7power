import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/cart_usecases.dart';

class CartProvider extends ChangeNotifier {
  final GetCartUseCase getCartUseCase;
  final AddToCartUseCase addToCartUseCase;
  final UpdateCartQuantityUseCase updateQuantityUseCase;
  final RemoveFromCartUseCase removeFromCartUseCase;
  final ClearCartUseCase clearCartUseCase;
  final SyncGuestCartUseCase syncGuestCartUseCase;

  CartProvider({
    required this.getCartUseCase,
    required this.addToCartUseCase,
    required this.updateQuantityUseCase,
    required this.removeFromCartUseCase,
    required this.clearCartUseCase,
    required this.syncGuestCartUseCase,
  });

  List<CartItemEntity> _items = const [];
  bool _busy = false;
  bool? _lastAuthenticated;

  List<CartItemEntity> get items => _items;
  bool get isBusy => _busy;
  bool get isEmpty => _items.isEmpty;

  /// Unidades en total (el número de la insignia del carrito).
  int get totalUnits => _items.fold(0, (sum, i) => sum + i.quantity);

  /// Total por moneda: un carrito puede mezclar productos en soles y dólares,
  /// y no se pueden sumar entre sí. Los productos sin precio no cuentan.
  Map<String?, double> get totalsByCurrency {
    final totals = <String?, double>{};
    for (final item in _items.where((i) => i.hasPrice)) {
      totals[item.currency] = (totals[item.currency] ?? 0) + item.subtotal;
    }
    return totals;
  }

  bool get hasItemsWithoutPrice => _items.any((i) => !i.hasPrice);

  /// Reacciona a los cambios de sesión: al iniciar sesión el carrito de
  /// invitado pasa al servidor; al cerrarla se vuelve al carrito local.
  void onAuthChanged({required bool known, required bool authenticated}) {
    if (!known || _lastAuthenticated == authenticated) return;
    _lastAuthenticated = authenticated;

    // Se difiere para no notificar mientras el árbol de widgets se construye.
    Future.microtask(
      () => _run(
        authenticated ? syncGuestCartUseCase.call : getCartUseCase.call,
      ),
    );
  }

  Future<void> load() => _run(getCartUseCase.call);

  /// Devuelve null si se agregó, o el motivo por el que no se pudo.
  Future<String?> add(ProductEntity product, {int quantity = 1}) =>
      _runForResult(() => addToCartUseCase(product, quantity: quantity));

  Future<String?> setQuantity(int productId, int quantity) =>
      _runForResult(() => updateQuantityUseCase(productId, quantity));

  Future<String?> remove(int productId) =>
      _runForResult(() => removeFromCartUseCase(productId));

  Future<String?> clear() => _runForResult(clearCartUseCase.call);

  Future<void> _run(
    Future<Either<Failure, List<CartItemEntity>>> Function() action,
  ) async {
    await _runForResult(action);
  }

  Future<String?> _runForResult(
    Future<Either<Failure, List<CartItemEntity>>> Function() action,
  ) async {
    _busy = true;
    notifyListeners();

    final result = await action();
    final error = result.fold<String?>(
      (failure) => failure.message,
      (items) {
        _items = items;
        return null;
      },
    );

    _busy = false;
    notifyListeners();
    return error;
  }
}
