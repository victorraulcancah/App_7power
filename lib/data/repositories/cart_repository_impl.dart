import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_local_datasource.dart';
import '../datasources/cart_remote_datasource.dart';
import '../models/cart_item_model.dart';

class CartRepositoryImpl implements CartRepository {
  final CartRemoteDataSource remote;
  final CartLocalDataSource local;

  /// Si hay sesión iniciada el carrito va al servidor; si no, al dispositivo.
  final bool Function() isLoggedIn;

  CartRepositoryImpl({
    required this.remote,
    required this.local,
    required this.isLoggedIn,
  });

  @override
  Future<Either<Failure, List<CartItemEntity>>> getCart() => guardRequest(
        () async => isLoggedIn() ? await remote.getCart() : await local.read(),
      );

  @override
  Future<Either<Failure, List<CartItemEntity>>> add(
    ProductEntity product,
    int quantity,
  ) =>
      guardRequest(() async {
        if (isLoggedIn()) {
          await remote.add(product.id, quantity);
          return remote.getCart();
        }

        final items = await local.read();
        final index = items.indexWhere((i) => i.productId == product.id);
        final newQuantity = (index >= 0 ? items[index].quantity : 0) + quantity;
        _checkStock(product.stock, newQuantity);

        final updated = CartItemModel.fromProduct(product, newQuantity);
        if (index >= 0) {
          items[index] = updated;
        } else {
          items.add(updated);
        }
        await local.write(items);
        return items;
      });

  @override
  Future<Either<Failure, List<CartItemEntity>>> updateQuantity(
    int productId,
    int quantity,
  ) =>
      guardRequest(() async {
        if (isLoggedIn()) {
          await remote.updateQuantity(productId, quantity);
          return remote.getCart();
        }

        final items = await local.read();
        final index = items.indexWhere((i) => i.productId == productId);
        if (index < 0) return items;

        _checkStock(items[index].stock, quantity);
        items[index] = CartItemModel.fromEntity(
          items[index].copyWith(quantity: quantity),
        );
        await local.write(items);
        return items;
      });

  @override
  Future<Either<Failure, List<CartItemEntity>>> remove(int productId) =>
      guardRequest(() async {
        if (isLoggedIn()) {
          await remote.remove(productId);
          return remote.getCart();
        }

        final items = await local.read()
          ..removeWhere((i) => i.productId == productId);
        await local.write(items);
        return items;
      });

  @override
  Future<Either<Failure, List<CartItemEntity>>> clear() =>
      guardRequest(() async {
        if (isLoggedIn()) {
          await remote.clear();
        } else {
          await local.clear();
        }
        return <CartItemEntity>[];
      });

  @override
  Future<Either<Failure, List<CartItemEntity>>> syncGuestCart() =>
      guardRequest(() async {
        final guestItems = await local.read();
        if (guestItems.isEmpty) return remote.getCart();

        final merged = await remote.sync(guestItems);
        // Solo se vacía el carrito local cuando el servidor ya lo tiene.
        await local.clear();
        return merged;
      });

  /// Un producto con stock 0 no se puede agregar; uno con stock, hasta ese tope.
  void _checkStock(int stock, int quantity) {
    if (quantity > stock) {
      throw ValidationException(
        stock > 0
            ? 'Solo quedan $stock unidades disponibles.'
            : 'Producto sin stock.',
      );
    }
  }
}
