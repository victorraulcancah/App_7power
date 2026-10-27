import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_entity.dart';
import '../repositories/favorites_repository.dart';

class GetFavoritesUseCase {
  final FavoritesRepository repository;
  GetFavoritesUseCase(this.repository);

  Future<Either<Failure, List<ProductEntity>>> call() =>
      repository.getFavorites();
}

class AddFavoriteUseCase {
  final FavoritesRepository repository;
  AddFavoriteUseCase(this.repository);

  Future<Either<Failure, void>> call(int productId) =>
      repository.add(productId);
}

class RemoveFavoriteUseCase {
  final FavoritesRepository repository;
  RemoveFavoriteUseCase(this.repository);

  Future<Either<Failure, void>> call(int productId) =>
      repository.remove(productId);
}
