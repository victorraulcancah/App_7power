import '../../core/errors/failures.dart';
import '../../core/network/request_guard.dart';
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
    int? limit,
  }) =>
      guardRequest(() => remoteDataSource.getProducts(
            page: page,
            search: search,
            categoryId: categoryId,
            limit: limit,
          ));

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() =>
      guardRequest(remoteDataSource.getCategories);
}
