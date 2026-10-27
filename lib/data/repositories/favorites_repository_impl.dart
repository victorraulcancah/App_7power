import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_remote_datasource.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesRemoteDataSource remote;

  FavoritesRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<ProductEntity>>> getFavorites() =>
      guardRequest(remote.getFavorites);

  /// Agregar uno que ya está guardado (400) no es un error para el usuario.
  @override
  Future<Either<Failure, void>> add(int productId) => guardRequest(() async {
        try {
          await remote.add(productId);
        } on ServerException catch (e) {
          if (e.code != '400') rethrow;
        }
      });

  /// Quitar uno que ya no existe (404) tampoco: el resultado es el mismo.
  @override
  Future<Either<Failure, void>> remove(int productId) =>
      guardRequest(() async {
        try {
          await remote.remove(productId);
        } on ServerException catch (e) {
          if (e.code != '404') rethrow;
        }
      });
}
