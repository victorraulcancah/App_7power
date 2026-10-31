import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Core
import 'core/constants/api_constants.dart';
import 'core/network/api_client.dart';

// Data Layer
import 'data/datasources/addresses_remote_datasource.dart';
import 'data/datasources/promotions_remote_datasource.dart';
import 'data/datasources/statement_remote_datasource.dart';
import 'data/repositories/statement_repository_impl.dart';
import 'domain/repositories/statement_repository.dart';
import 'domain/usecases/statement_usecases.dart';
import 'presentation/providers/statement_provider.dart';
import 'data/datasources/registration_remote_datasource.dart';
import 'data/repositories/promotions_repository_impl.dart';
import 'domain/repositories/promotions_repository.dart';
import 'domain/usecases/promotions_usecases.dart';
import 'presentation/providers/promotions_provider.dart';
import 'data/repositories/registration_repository_impl.dart';
import 'domain/repositories/registration_repository.dart';
import 'domain/usecases/registration_usecases.dart';
import 'presentation/providers/registration_provider.dart';
import 'data/datasources/info_remote_datasource.dart';
import 'data/repositories/info_repository_impl.dart';
import 'domain/repositories/info_repository.dart';
import 'domain/usecases/info_usecases.dart';
import 'presentation/providers/info_provider.dart';
import 'data/datasources/checkout_remote_datasource.dart';
import 'data/repositories/checkout_repository_impl.dart';
import 'domain/repositories/checkout_repository.dart';
import 'domain/usecases/checkout_usecases.dart';
import 'presentation/providers/checkout_provider.dart';
import 'data/datasources/favorites_remote_datasource.dart';
import 'data/datasources/purchases_remote_datasource.dart';
import 'data/datasources/quotes_remote_datasource.dart';
import 'data/repositories/addresses_repository_impl.dart';
import 'data/repositories/favorites_repository_impl.dart';
import 'data/repositories/purchases_repository_impl.dart';
import 'data/repositories/quotes_repository_impl.dart';
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
import 'domain/repositories/addresses_repository.dart';
import 'domain/repositories/favorites_repository.dart';
import 'domain/repositories/purchases_repository.dart';
import 'domain/repositories/quotes_repository.dart';
import 'domain/usecases/addresses_usecases.dart';
import 'domain/usecases/favorites_usecases.dart';
import 'domain/usecases/purchases_usecases.dart';
import 'domain/usecases/quotes_usecases.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/cart_repository.dart';
import 'domain/repositories/product_repository.dart';
import 'domain/repositories/store_repository.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/cart_usecases.dart';
import 'domain/usecases/get_banners_usecase.dart';
import 'domain/usecases/get_brands_usecase.dart';
import 'domain/usecases/get_categories_usecase.dart';
import 'domain/usecases/get_company_info_usecase.dart';
import 'domain/usecases/get_product_detail_usecase.dart';
import 'domain/usecases/get_products_usecase.dart';

// Presentation Layer
import 'presentation/providers/addresses_provider.dart';
import 'presentation/providers/favorites_provider.dart';
import 'presentation/providers/purchases_provider.dart';
import 'presentation/providers/quotes_provider.dart';
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

  static final FavoritesRepository _favoritesRepository =
      FavoritesRepositoryImpl(FavoritesRemoteDataSourceImpl(_apiClient));

  static final PurchasesRepository _purchasesRepository =
      PurchasesRepositoryImpl(PurchasesRemoteDataSourceImpl(_apiClient));

  static final AddressesRepository _addressesRepository =
      AddressesRepositoryImpl(AddressesRemoteDataSourceImpl(_apiClient));

  static final QuotesRepository _quotesRepository =
      QuotesRepositoryImpl(QuotesRemoteDataSourceImpl(_apiClient));

  static final CheckoutRepository _checkoutRepository =
      CheckoutRepositoryImpl(CheckoutRemoteDataSourceImpl(_apiClient));

  static final InfoRepository _infoRepository =
      InfoRepositoryImpl(InfoRemoteDataSourceImpl(_apiClient));

  /// El ERP es otro servidor: su cliente HTTP apunta a `ERP_API_URL` y no lleva
  /// el token de la tienda.
  static final ApiClient _erpClient =
      ApiClient(baseUrl: ApiConstants.erpBaseUrl);

  static final StatementRepository _statementRepository =
      StatementRepositoryImpl(StatementRemoteDataSourceImpl(_erpClient));

  static final PromotionsRepository _promotionsRepository =
      PromotionsRepositoryImpl(PromotionsRemoteDataSourceImpl(_apiClient));

  static final RegistrationRepository _registrationRepository =
      RegistrationRepositoryImpl(RegistrationRemoteDataSourceImpl(_apiClient));

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
            changePasswordUseCase: ChangePasswordUseCase(_authRepository),
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
            getBrandsUseCase: GetBrandsUseCase(_productRepository),
          ),
        ),
        authAware<ProductDetailProvider>(
          () => ProductDetailProvider(
            getProductDetailUseCase: GetProductDetailUseCase(_productRepository),
          ),
        ),
        // Mi cuenta: datos del cliente. Al iniciar o cerrar sesión se vacían
        // (o se recargan) para no mostrar lo de otra cuenta.
        authAware<FavoritesProvider>(
          () => FavoritesProvider(
            getFavoritesUseCase: GetFavoritesUseCase(_favoritesRepository),
            addFavoriteUseCase: AddFavoriteUseCase(_favoritesRepository),
            removeFavoriteUseCase: RemoveFavoriteUseCase(_favoritesRepository),
          ),
        ),
        authAware<PurchasesProvider>(
          () => PurchasesProvider(
            getOnlinePurchasesUseCase:
                GetOnlinePurchasesUseCase(_purchasesRepository),
            getStorePurchasesUseCase:
                GetStorePurchasesUseCase(_purchasesRepository),
          ),
        ),
        authAware<AddressesProvider>(
          () => AddressesProvider(
            getAddressesUseCase: GetAddressesUseCase(_addressesRepository),
            saveAddressUseCase: SaveAddressUseCase(_addressesRepository),
            deleteAddressUseCase: DeleteAddressUseCase(_addressesRepository),
            setDefaultAddressUseCase:
                SetDefaultAddressUseCase(_addressesRepository),
            ubigeo: GetUbigeoUseCase(_addressesRepository),
          ),
        ),
        authAware<QuotesProvider>(
          () => QuotesProvider(
            getQuotesUseCase: GetQuotesUseCase(_quotesRepository),
            cancelQuoteUseCase: CancelQuoteUseCase(_quotesRepository),
            convertQuoteUseCase: ConvertQuoteToPurchaseUseCase(_quotesRepository),
          ),
        ),
        ChangeNotifierProvider<RegistrationProvider>(
          create: (_) => RegistrationProvider(
            getDocumentTypesUseCase:
                GetDocumentTypesUseCase(_registrationRepository),
            getCaptchaUseCase: GetCaptchaUseCase(_registrationRepository),
            verifyCaptchaUseCase: VerifyCaptchaUseCase(_registrationRepository),
            registerUseCase: RegisterUseCase(_registrationRepository),
            forgotPasswordUseCase: ForgotPasswordUseCase(_registrationRepository),
          ),
        ),
        authAware<StatementProvider>(
          () => StatementProvider(
            getStatementUseCase: GetStatementUseCase(_statementRepository),
            available: ApiConstants.erpConfigured,
          ),
        ),
        ChangeNotifierProvider<PromotionsProvider>(
          create: (_) => PromotionsProvider(
            getActiveCouponsUseCase: GetActiveCouponsUseCase(_promotionsRepository),
            getOffersUseCase: GetOffersUseCase(_promotionsRepository),
          ),
        ),
        ChangeNotifierProvider<InfoProvider>(
          create: (_) => InfoProvider(
            getAboutUseCase: GetAboutUseCase(_infoRepository),
            getShippingStepsUseCase: GetShippingStepsUseCase(_infoRepository),
            sendContactUseCase: SendContactUseCase(_infoRepository),
            submitClaimUseCase: SubmitClaimUseCase(_infoRepository),
            findClaimUseCase: FindClaimUseCase(_infoRepository),
            getMyClaimsUseCase: GetMyClaimsUseCase(_infoRepository),
          ),
        ),
        // Checkout: se reinicia al abrirlo, no depende de la sesión.
        ChangeNotifierProvider<CheckoutProvider>(
          create: (_) => CheckoutProvider(
            getPaymentTypesUseCase: GetPaymentTypesUseCase(_checkoutRepository),
            extras: GetCheckoutExtrasUseCase(_checkoutRepository),
            validateCouponUseCase: ValidateCouponUseCase(_checkoutRepository),
            verifyStockUseCase: VerifyStockUseCase(_checkoutRepository),
            createQuotesUseCase: CreateQuotesUseCase(_checkoutRepository),
            payOnlineUseCase: PayOnlineUseCase(_checkoutRepository),
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
