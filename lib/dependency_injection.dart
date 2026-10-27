import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Core
import 'core/network/api_client.dart';

// Data Layer
import 'data/datasources/auth_local_datasource.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/datasources/cart_local_datasource.dart';
import 'data/datasources/cart_remote_datasource.dart';
import 'data/datasources/product_remote_datasource.dart';
import 'data/datasources/store_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/cart_repository_impl.dart';
import 'data/repositories/product_repository_impl.dart';
import 'data/repositories/store_repository_impl.dart';

// Domain Layer
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/cart_repository.dart';
import 'domain/repositories/product_repository.dart';
import 'domain/repositories/store_repository.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/cart_usecases.dart';
import 'domain/usecases/get_banners_usecase.dart';
import 'domain/usecases/get_categories_usecase.dart';
import 'domain/usecases/get_company_info_usecase.dart';
import 'domain/usecases/get_product_detail_usecase.dart';
import 'domain/usecases/get_products_usecase.dart';

// Presentation Layer
import 'presentation/providers/auth_aware_reload.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/cart_provider.dart';
import 'presentation/providers/company_provider.dart';
import 'presentation/providers/home_provider.dart';
import 'presentation/providers/product_detail_provider.dart';
import 'presentation/providers/products_provider.dart';

class DependencyInjection {
  /// Cliente HTTP único: guarda el token de la sesión para todas las peticiones.
  static final ApiClient _apiClient = ApiClient();

  // Los repositorios se crean una sola vez: el de autenticación engancha el
  // aviso de "sesión vencida" en el cliente HTTP.
  static final AuthRepository _authRepository = AuthRepositoryImpl(
    remote: AuthRemoteDataSourceImpl(_apiClient),
    local: AuthLocalDataSourceImpl(),
    apiClient: _apiClient,
  );

  static final CartRepository _cartRepository = CartRepositoryImpl(
    remote: CartRemoteDataSourceImpl(_apiClient),
    local: CartLocalDataSourceImpl(),
    isLoggedIn: () => _apiClient.authToken != null,
    products: ProductRemoteDataSourceImpl(_apiClient),
  );

  static final ProductRepository _productRepository = ProductRepositoryImpl(
    ProductRemoteDataSourceImpl(_apiClient),
  );

  static final StoreRepository _storeRepository = StoreRepositoryImpl(
    StoreRemoteDataSourceImpl(_apiClient),
  );

  /// Providers globales de la app. Cada feature nueva registra aquí su
  /// provider con sus casos de uso (datasource -> repository -> usecase).
  static List<SingleChildWidget> get providers => [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            loginUseCase: LoginUseCase(_authRepository),
            logoutUseCase: LogoutUseCase(_authRepository),
            restoreSessionUseCase: RestoreSessionUseCase(_authRepository),
            refreshProfileUseCase: RefreshProfileUseCase(_authRepository),
            updatePhoneUseCase: UpdatePhoneUseCase(_authRepository),
            repository: _authRepository,
          )..restore(),
        ),
        // El carrito depende de la sesión: al iniciarla pasa el carrito de
        // invitado al servidor.
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) => CartProvider(
            getCartUseCase: GetCartUseCase(_cartRepository),
            addToCartUseCase: AddToCartUseCase(_cartRepository),
            updateQuantityUseCase: UpdateCartQuantityUseCase(_cartRepository),
            removeFromCartUseCase: RemoveFromCartUseCase(_cartRepository),
            clearCartUseCase: ClearCartUseCase(_cartRepository),
            syncGuestCartUseCase: SyncGuestCartUseCase(_cartRepository),
          ),
          update: (_, auth, cart) => cart!
            ..onAuthChanged(
              known: auth.status != AuthStatus.initial,
              authenticated: auth.isAuthenticated,
            ),
        ),
        ChangeNotifierProvider<CompanyProvider>(
          create: (_) => CompanyProvider(
            getCompanyInfoUseCase: GetCompanyInfoUseCase(_storeRepository),
          )..load(),
        ),
        // Estos tres muestran precios, que dependen del cliente logueado: se
        // recargan al iniciar o cerrar sesión.
        authAware<HomeProvider>(
          () => HomeProvider(
            getBannersUseCase: GetBannersUseCase(_storeRepository),
            getProductsUseCase: GetProductsUseCase(_productRepository),
          ),
        ),
        authAware<ProductsProvider>(
          () => ProductsProvider(
            getProductsUseCase: GetProductsUseCase(_productRepository),
            getCategoriesUseCase: GetCategoriesUseCase(_productRepository),
          ),
        ),
        authAware<ProductDetailProvider>(
          () => ProductDetailProvider(
            getProductDetailUseCase: GetProductDetailUseCase(_productRepository),
          ),
        ),
      ];

  /// Provider cuyos datos se recargan cuando cambia la sesión.
  static ChangeNotifierProxyProvider<AuthProvider, T>
      authAware<T extends AuthAwareReload>(T Function() create) =>
          ChangeNotifierProxyProvider<AuthProvider, T>(
            create: (_) => create(),
            update: (_, auth, provider) => provider!
              ..onAuthChanged(
                known: auth.status != AuthStatus.initial,
                authenticated: auth.isAuthenticated,
              ),
          );
}
