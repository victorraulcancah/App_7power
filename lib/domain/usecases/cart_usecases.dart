import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/cart_item_entity.dart';
import '../entities/product_entity.dart';
import '../repositories/cart_repository.dart';

typedef CartResult = Future<Either<Failure, List<CartItemEntity>>>;

class GetCartUseCase {
  final CartRepository repository;
  GetCartUseCase(this.repository);

  CartResult call() => repository.getCart();
}

class AddToCartUseCase {
  final CartRepository repository;
  AddToCartUseCase(this.repository);

  CartResult call(ProductEntity product, {int quantity = 1}) =>
      repository.add(product, quantity);
}

class UpdateCartQuantityUseCase {
  final CartRepository repository;
  UpdateCartQuantityUseCase(this.repository);

  CartResult call(int productId, int quantity) =>
      repository.updateQuantity(productId, quantity);
}

class RemoveFromCartUseCase {
  final CartRepository repository;
  RemoveFromCartUseCase(this.repository);

  CartResult call(int productId) => repository.remove(productId);
}

class ClearCartUseCase {
  final CartRepository repository;
  ClearCartUseCase(this.repository);

  CartResult call() => repository.clear();
}

class SyncGuestCartUseCase {
  final CartRepository repository;
  SyncGuestCartUseCase(this.repository);

  CartResult call() => repository.syncGuestCart();
}
