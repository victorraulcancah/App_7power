import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/cart_usecases.dart';

/// Totales del carrito en una moneda ('s' o 'd').
class CartCurrencySummary {
  final String currency;
  final int units;
  final double total;

  const CartCurrencySummary({
    required this.currency,
    required this.units,
    required this.total,
  });
}

class CartProvider extends ChangeNotifier {
  final GetCartUseCase getCartUseCase;
  final AddToCartUseCase addToCartUseCase;
  final UpdateCartQuantityUseCase updateQuantityUseCase;
  final RemoveFromCartUseCase removeFromCartUseCase;
  final ClearCartUseCase clearCartUseCase;
  final SyncGuestCartUseCase syncGuestCartUseCase;
  final SaveForLaterUseCase saveForLaterUseCase;
  final MoveToCartUseCase moveToCartUseCase;

  CartProvider({
    required this.getCartUseCase,
    required this.addToCartUseCase,
    required this.updateQuantityUseCase,
    required this.removeFromCartUseCase,
    required this.clearCartUseCase,
    required this.syncGuestCartUseCase,
    required this.saveForLaterUseCase,
    required this.moveToCartUseCase,
  });

  /// Todo lo que hay en la cuenta: el carrito activo y lo guardado.
  List<CartItemEntity> _all = const [];
  bool _busy = false;
  bool? _lastAuthenticated;

  /// El carrito activo: lo que se paga o se cotiza.
  List<CartItemEntity> get items =>
      _all.where((i) => !i.savedForLater).toList();

  /// Lo que se dejó "guardado para después" (no cuenta en el pedido).
  List<CartItemEntity> get savedItems =>
      _all.where((i) => i.savedForLater).toList();

  bool get isBusy => _busy;
  bool get isEmpty => items.isEmpty;

  /// Unidades en total (el número de la insignia del carrito).
  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);

  /// Un resumen por moneda, soles primero (igual que la web): un carrito puede
  /// mezclar productos en soles y dólares, y no se pueden sumar entre sí.
  List<CartCurrencySummary> get summaries {
    final result = <CartCurrencySummary>[];
    for (final currency in const ['s', 'd']) {
      final inCurrency = items
          .where((i) => FormatUtils.normalizeCurrency(i.currency) == currency)
          .toList();
      if (inCurrency.isEmpty) continue;
      result.add(CartCurrencySummary(
        currency: currency,
        units: inCurrency.fold(0, (sum, i) => sum + i.quantity),
        total: inCurrency.fold(0.0, (sum, i) => sum + i.subtotal),
      ));
    }
    return result;
  }

  /// Todos los productos tienen precio: un invitado solo ve el total así.
  bool get allItemsPriced => !isEmpty && items.every((i) => i.hasPrice);

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

  /// Vacía el carrito activo; lo guardado para después se queda.
  Future<String?> clear() => _runForResult(clearCartUseCase.call);

  /// Pasa el producto a "guardados para después". Devuelve null si salió bien,
  /// o el motivo.
  Future<String?> saveForLater(int productId) =>
      _runForResult(() => saveForLaterUseCase(productId));

  /// Devuelve un guardado al carrito. Devuelve null si salió bien, o el motivo
  /// (por ejemplo, que ya no hay stock).
  Future<String?> moveToCart(int productId) =>
      _runForResult(() => moveToCartUseCase(productId));

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
        _all = items;
        return null;
      },
    );

    _busy = false;
    notifyListeners();
    return error;
  }
}
