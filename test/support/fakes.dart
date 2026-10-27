import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/errors/exceptions.dart';
import 'package:appecommerce/core/errors/failures.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/core/utils/either.dart';
import 'package:appecommerce/data/datasources/auth_local_datasource.dart';
import 'package:appecommerce/data/datasources/auth_remote_datasource.dart';
import 'package:appecommerce/data/datasources/cart_local_datasource.dart';
import 'package:appecommerce/data/datasources/cart_remote_datasource.dart';
import 'package:appecommerce/data/models/cart_item_model.dart';
import 'package:appecommerce/data/models/user_model.dart';
import 'package:appecommerce/data/repositories/auth_repository_impl.dart';
import 'package:appecommerce/data/repositories/cart_repository_impl.dart';
import 'package:appecommerce/domain/entities/banner_entity.dart';
import 'package:appecommerce/domain/entities/category_entity.dart';
import 'package:appecommerce/domain/entities/company_info_entity.dart';
import 'package:appecommerce/domain/entities/product_detail_entity.dart';
import 'package:appecommerce/domain/entities/product_entity.dart';
import 'package:appecommerce/domain/entities/products_page_entity.dart';
import 'package:appecommerce/domain/repositories/product_repository.dart';
import 'package:appecommerce/domain/repositories/store_repository.dart';
import 'package:appecommerce/domain/usecases/auth_usecases.dart';
import 'package:appecommerce/domain/usecases/cart_usecases.dart';
import 'package:appecommerce/domain/usecases/get_banners_usecase.dart';
import 'package:appecommerce/domain/usecases/get_categories_usecase.dart';
import 'package:appecommerce/domain/usecases/get_company_info_usecase.dart';
import 'package:appecommerce/domain/usecases/get_product_detail_usecase.dart';
import 'package:appecommerce/domain/usecases/get_products_usecase.dart';
import 'package:appecommerce/data/datasources/product_remote_datasource.dart';
import 'package:appecommerce/data/models/category_model.dart';
import 'package:appecommerce/data/models/product_detail_model.dart';
import 'package:appecommerce/dependency_injection.dart';
import 'package:appecommerce/main.dart';
import 'package:appecommerce/presentation/providers/auth_provider.dart';
import 'package:appecommerce/presentation/providers/cart_provider.dart';
import 'package:appecommerce/presentation/providers/company_provider.dart';
import 'package:appecommerce/presentation/providers/home_provider.dart';
import 'package:appecommerce/presentation/providers/product_detail_provider.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';

/// Catálogo falso: filtra en memoria como lo haría el backend y devuelve los
/// resultados en páginas de [pageSize].
class FakeProductRepo implements ProductRepository {
  /// Se puede reemplazar en un test para simular que el servidor cambió lo que
  /// devuelve (por ejemplo, los precios tras iniciar sesión).
  List<ProductEntity> products;
  final Failure? failure;
  final int pageSize;
  final List<int> requestedPages = [];

  /// Opciones de moneda por producto para la ficha.
  final Map<int, List<CurrencyOption>> currencyOptions = {};

  FakeProductRepo(this.products, {this.failure, this.pageSize = 20});

  @override
  Future<Either<Failure, ProductsPageEntity>> getProducts({
    int page = 1,
    String? search,
    int? categoryId,
    int? limit,
  }) async {
    requestedPages.add(page);
    if (failure != null) return Either.left(failure!);

    final filtered = products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (search != null &&
          !p.name.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    if (limit != null) {
      final items = filtered.take(limit).toList();
      return Either.right(ProductsPageEntity(
        items: items,
        currentPage: 1,
        lastPage: 1,
        total: items.length,
      ));
    }

    final start = (page - 1) * pageSize;
    final items = filtered.skip(start).take(pageSize).toList();
    return Either.right(ProductsPageEntity(
      items: items,
      currentPage: page,
      lastPage: (filtered.length / pageSize).ceil().clamp(1, 9999),
      total: filtered.length,
    ));
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async =>
      Either.right(const [
        CategoryEntity(id: 1, name: 'DRIVER'),
        CategoryEntity(id: 2, name: 'RCA'),
      ]);

  @override
  Future<Either<Failure, ProductDetailEntity>> getProductDetail(int id) async {
    final product = products.where((p) => p.id == id).firstOrNull;
    if (product == null) {
      return Either.left(const ServerFailure('Producto no encontrado'));
    }
    return Either.right(ProductDetailEntity(
      product: product,
      longDescription: 'Descripción de ${product.name}',
      warranty: '12 meses',
      currencyOptions: currencyOptions[id] ?? const [],
    ));
  }
}

class FakeStoreRepo implements StoreRepository {
  final CompanyInfoEntity? company;

  FakeStoreRepo({this.company});

  @override
  Future<Either<Failure, CompanyInfoEntity>> getCompanyInfo() async =>
      company == null
          ? Either.left(const NetworkFailure('Sin conexión'))
          : Either.right(company!);

  @override
  Future<Either<Failure, List<BannerEntity>>> getBanners() async =>
      Either.right(const [
        BannerEntity(id: 1, imageUrl: 'http://api.test/banner.png'),
      ]);
}

const testCompany = CompanyInfoEntity(
  name: '7power',
  email: 'ventas@7power.pe',
  address: 'CERCADO DE LIMA',
  navbarColor: '#112233',
  website: 'https://7power.pe/',
  social: {SocialNetwork.facebook: 'https://facebook.com/x'},
  paymentMethods: [PaymentMethodEntity(id: 1, name: 'Plin')],
);

const testUser = UserModel(
  id: 7,
  fullName: 'Ana Pérez',
  email: 'ana@correo.com',
  documentNumber: '12345678',
  documentType: 'DNI',
);

ProductEntity product(
  int id,
  String name, {
  int categoryId = 1,
  double price = 10,
  int stock = 5,
  String currency = 's',
  bool priceVisible = true,
}) =>
    ProductEntity(
      id: id,
      name: name,
      categoryId: categoryId,
      price: price,
      currency: currency,
      stock: stock,
      priceVisible: priceVisible,
    );

/// Origen de datos de productos para el refresco del carrito de invitado:
/// devuelve la ficha que se le haya cargado en [details]; si no hay, falla.
class FakeProductRemote implements ProductRemoteDataSource {
  final Map<int, ProductDetailModel> details = {};

  @override
  Future<ProductDetailModel> getProductDetail(int id) async {
    final detail = details[id];
    if (detail == null) throw const ServerException('Producto no encontrado');
    return detail;
  }

  @override
  Future<ProductsPageEntity> getProducts({
    required int page,
    String? search,
    int? categoryId,
    int? limit,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<CategoryModel>> getCategories() => throw UnimplementedError();
}

/// Resultado de login configurable.
class FakeAuthRemote implements AuthRemoteDataSource {
  String userType = 'cliente';
  final List<String> loggedOutTokens = [];

  @override
  Future<LoginResult> login(String email, String password) async {
    if (password != 'secreto') {
      throw const AuthException('Las credenciales proporcionadas son incorrectas.');
    }
    return LoginResult(
      userType: userType,
      token: 'token-$userType',
      client: userType == 'cliente' ? testUser : null,
    );
  }

  @override
  Future<void> logout(String token) async => loggedOutTokens.add(token);

  /// Celular que el servidor "guardó" con `updatePhone`.
  String? savedPhone;

  /// Lo que devuelve `GET /user`.
  UserModel profile = testUser;

  @override
  Future<UserModel> getProfile() async => profile;

  @override
  Future<void> updatePhone(String phone) async {
    if (!phone.startsWith('9')) {
      throw const ServerException('Celular no válido', '422');
    }
    savedPhone = phone;
  }
}

class FakeAuthLocal implements AuthLocalDataSource {
  StoredSession? session;

  @override
  Future<void> saveSession(String token, UserModel user) async =>
      session = StoredSession(token, user);

  @override
  Future<StoredSession?> readSession() async => session;

  @override
  Future<void> clearSession() async => session = null;
}

class FakeCartLocal implements CartLocalDataSource {
  List<CartItemModel> items = [];

  @override
  Future<List<CartItemModel>> read() async => List.of(items);

  @override
  Future<void> write(List<CartItemModel> value) async => items = List.of(value);

  @override
  Future<void> clear() async => items = [];
}

/// "Servidor" de carrito en memoria. Con [stockLimit] imita el 409 del backend.
class FakeCartRemote implements CartRemoteDataSource {
  List<CartItemModel> items = [];
  int stockLimit = 99;
  int syncCalls = 0;

  @override
  Future<List<CartItemModel>> getCart() async => List.of(items);

  @override
  Future<void> add(int productId, int quantity) async {
    final index = items.indexWhere((i) => i.productId == productId);
    final total = (index >= 0 ? items[index].quantity : 0) + quantity;
    if (total > stockLimit) {
      throw const ServerException('Stock insuficiente.', '409');
    }
    final base = index >= 0
        ? items[index]
        : CartItemModel(
            productId: productId,
            name: 'Producto $productId',
            price: 10,
            quantity: 0,
            stock: stockLimit,
          );
    final updated = CartItemModel.fromEntity(base.copyWith(quantity: total));
    index >= 0 ? items[index] = updated : items.add(updated);
  }

  @override
  Future<void> updateQuantity(int productId, int quantity) async {
    final index = items.indexWhere((i) => i.productId == productId);
    items[index] = CartItemModel.fromEntity(
      items[index].copyWith(quantity: quantity),
    );
  }

  @override
  Future<void> remove(int productId) async =>
      items.removeWhere((i) => i.productId == productId);

  @override
  Future<void> clear() async => items = [];

  @override
  Future<List<CartItemModel>> sync(List<CartItemModel> value) async {
    syncCalls++;
    for (final item in value) {
      await add(item.productId, item.quantity);
    }
    return List.of(items);
  }
}

/// Todo lo que necesita la app, con dobles en lugar de red y almacenamiento.
class TestEnv {
  final FakeProductRepo products;
  final FakeStoreRepo store;
  final FakeAuthRemote authRemote = FakeAuthRemote();
  final FakeAuthLocal authLocal = FakeAuthLocal();
  final FakeCartLocal cartLocal = FakeCartLocal();
  final FakeCartRemote cartRemote = FakeCartRemote();
  final FakeProductRemote productRemote = FakeProductRemote();
  final ApiClient apiClient = ApiClient(isConnected: () async => true);

  late final AuthRepositoryImpl authRepo = AuthRepositoryImpl(
    remote: authRemote,
    local: authLocal,
    apiClient: apiClient,
  );

  late final CartRepositoryImpl cartRepo = CartRepositoryImpl(
    remote: cartRemote,
    local: cartLocal,
    isLoggedIn: () => apiClient.authToken != null,
    products: productRemote,
  );

  TestEnv({
    List<ProductEntity> catalog = const [],
    Failure? catalogFailure,
    int pageSize = 20,
    CompanyInfoEntity? company = testCompany,
  })  : products = FakeProductRepo(catalog,
            failure: catalogFailure, pageSize: pageSize),
        store = FakeStoreRepo(company: company);

  Widget app() => MyApp(providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            loginUseCase: LoginUseCase(authRepo),
            logoutUseCase: LogoutUseCase(authRepo),
            restoreSessionUseCase: RestoreSessionUseCase(authRepo),
            refreshProfileUseCase: RefreshProfileUseCase(authRepo),
            updatePhoneUseCase: UpdatePhoneUseCase(authRepo),
            repository: authRepo,
          )..restore(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) => CartProvider(
            getCartUseCase: GetCartUseCase(cartRepo),
            addToCartUseCase: AddToCartUseCase(cartRepo),
            updateQuantityUseCase: UpdateCartQuantityUseCase(cartRepo),
            removeFromCartUseCase: RemoveFromCartUseCase(cartRepo),
            clearCartUseCase: ClearCartUseCase(cartRepo),
            syncGuestCartUseCase: SyncGuestCartUseCase(cartRepo),
          ),
          update: (_, auth, cart) => cart!
            ..onAuthChanged(
              known: auth.status != AuthStatus.initial,
              authenticated: auth.isAuthenticated,
            ),
        ),
        ChangeNotifierProvider<CompanyProvider>(
          create: (_) => CompanyProvider(
            getCompanyInfoUseCase: GetCompanyInfoUseCase(store),
          )..load(),
        ),
        DependencyInjection.authAware<HomeProvider>(
          () => HomeProvider(
            getBannersUseCase: GetBannersUseCase(store),
            getProductsUseCase: GetProductsUseCase(products),
          ),
        ),
        DependencyInjection.authAware<ProductsProvider>(
          () => ProductsProvider(
            getProductsUseCase: GetProductsUseCase(products),
            getCategoriesUseCase: GetCategoriesUseCase(products),
          ),
        ),
        DependencyInjection.authAware<ProductDetailProvider>(
          () => ProductDetailProvider(
            getProductDetailUseCase: GetProductDetailUseCase(products),
          ),
        ),
      ]);
}
