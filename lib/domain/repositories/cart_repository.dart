import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/cart_item_entity.dart';
import '../entities/product_entity.dart';

/// Carrito de compras. Con sesión iniciada vive en el servidor; como invitado
/// se guarda en el dispositivo y se pasa al servidor al iniciar sesión.
/// Todas las operaciones devuelven el carrito ya actualizado.
abstract class CartRepository {
  Future<Either<Failure, List<CartItemEntity>>> getCart();

  Future<Either<Failure, List<CartItemEntity>>> add(
    ProductEntity product,
    int quantity,
  );

  Future<Either<Failure, List<CartItemEntity>>> updateQuantity(
    int productId,
    int quantity,
  );

  Future<Either<Failure, List<CartItemEntity>>> remove(int productId);

  Future<Either<Failure, List<CartItemEntity>>> clear();

  /// Pasa el carrito de invitado al servidor y lo vacía localmente.
  Future<Either<Failure, List<CartItemEntity>>> syncGuestCart();
}
