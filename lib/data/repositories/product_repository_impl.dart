import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/products_page_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource remoteDataSource;

  ProductRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, ProductsPageEntity>> getProducts({
    int page = 1,
    String? search,
    int? categoryId,
  }) =>
      _guard(() => remoteDataSource.getProducts(
            page: page,
            search: search,
            categoryId: categoryId,
          ));

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() =>
      _guard(remoteDataSource.getCategories);

  /// Traduce las excepciones de la capa de datos a fallos del dominio.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Either.right(await call());
    } on NetworkException catch (e) {
      return Either.left(NetworkFailure(e.message));
    } on AuthException catch (e) {
      return Either.left(AuthenticationFailure(e.message));
    } on AppException catch (e) {
      return Either.left(ServerFailure(e.message));
    } catch (_) {
      return Either.left(const ServerFailure('Respuesta inválida del servidor'));
    }
  }
}
