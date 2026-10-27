import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_local_datasource.dart';
import '../datasources/cart_remote_datasource.dart';
import '../datasources/product_remote_datasource.dart';
import '../models/cart_item_model.dart';

class CartRepositoryImpl implements CartRepository {
  final CartRemoteDataSource remote;
  final CartLocalDataSource local;

  /// Si hay sesión iniciada el carrito va al servidor; si no, al dispositivo.
  final bool Function() isLoggedIn;

  /// Para refrescar el carrito de invitado con los datos actuales de cada
  /// producto. Sin él, el carrito local se devuelve tal cual.
  final ProductRemoteDataSource? products;

  CartRepositoryImpl({
    required this.remote,
    required this.local,
    required this.isLoggedIn,
    this.products,
  });

  @override
  Future<Either<Failure, List<CartItemEntity>>> getCart() => guardRequest(
        () async => isLoggedIn() ? await remote.getCart() : _refreshGuestCart(),
      );

  /// El carrito de invitado guarda una copia de precio y stock que se queda
  /// vieja. Como la web, se vuelve a pedir cada producto al servidor; si uno
  /// falla se conserva su copia.
  Future<List<CartItemModel>> _refreshGuestCart() async {
    final items = await local.read();
    final source = products;
    if (items.isEmpty || source == null) return items;

    final refreshed = await Future.wait(items.map((item) async {
      try {
        final detail = await source.getProductDetail(item.productId);
        final p = detail.product;
        return CartItemModel(
          productId: item.productId,
          name: p.name.isEmpty ? item.name : p.name,
          imageUrl: p.imageUrl ?? item.imageUrl,
          code: p.code ?? item.code,
          price: p.price,
          currency: p.currency ?? item.currency,
          quantity: item.quantity,
          stock: p.stock,
        );
      } catch (_) {
        return item;
      }
    }));

    await local.write(refreshed);
    return refreshed;
  }

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
