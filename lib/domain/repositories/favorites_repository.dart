import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/product_entity.dart';

/// "Mis listas" de la web: productos que el cliente guardó.
abstract class FavoritesRepository {
  Future<Either<Failure, List<ProductEntity>>> getFavorites();

  Future<Either<Failure, void>> add(int productId);

  Future<Either<Failure, void>> remove(int productId);
}
