import 'package:provider/provider.dart';

// Core
import 'core/network/api_client.dart';

// Data Layer
import 'data/datasources/product_remote_datasource.dart';
import 'data/repositories/product_repository_impl.dart';

// Domain Layer
import 'domain/repositories/product_repository.dart';
import 'domain/usecases/get_categories_usecase.dart';
import 'domain/usecases/get_products_usecase.dart';

// Presentation Layer
import 'presentation/providers/products_provider.dart';

class DependencyInjection {
  static final ApiClient _apiClient = ApiClient();

  /// Providers globales de la app. Cada feature nueva registra aquí su
  /// provider con sus casos de uso (datasource -> repository -> usecase).
  static List<ChangeNotifierProvider> get providers => [
        ChangeNotifierProvider<ProductsProvider>(
          create: (_) {
            final repo = _productRepo();
            return ProductsProvider(
              getProductsUseCase: GetProductsUseCase(repo),
              getCategoriesUseCase: GetCategoriesUseCase(repo),
            );
          },
        ),
      ];

  static ProductRepository _productRepo() => ProductRepositoryImpl(
        ProductRemoteDataSourceImpl(_apiClient),
      );
}
