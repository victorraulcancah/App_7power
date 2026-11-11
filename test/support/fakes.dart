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
import 'package:appecommerce/domain/usecases/get_cached_home_usecases.dart';
import 'package:appecommerce/domain/usecases/get_categories_usecase.dart';
import 'package:appecommerce/domain/usecases/get_company_info_usecase.dart';
import 'package:appecommerce/domain/usecases/get_product_detail_usecase.dart';
import 'package:appecommerce/domain/usecases/get_products_usecase.dart';
import 'package:appecommerce/core/utils/format_utils.dart';
import 'package:appecommerce/domain/entities/product_filters.dart';
import 'package:appecommerce/domain/usecases/get_brands_usecase.dart';
import 'package:appecommerce/data/datasources/info_remote_datasource.dart';
import 'package:appecommerce/data/models/info_model.dart';
import 'package:appecommerce/data/repositories/info_repository_impl.dart';
import 'package:appecommerce/domain/entities/info_entity.dart';
import 'package:appecommerce/domain/usecases/info_usecases.dart';
import 'package:appecommerce/presentation/providers/info_provider.dart';
import 'package:appecommerce/domain/entities/cart_item_entity.dart';
import 'package:appecommerce/data/datasources/checkout_remote_datasource.dart';
import 'package:appecommerce/data/repositories/checkout_repository_impl.dart';
import 'package:appecommerce/domain/entities/checkout_entity.dart';
import 'package:appecommerce/domain/usecases/checkout_usecases.dart';
import 'package:appecommerce/presentation/providers/checkout_provider.dart';
import 'package:appecommerce/data/datasources/addresses_remote_datasource.dart';
import 'package:appecommerce/data/datasources/favorites_remote_datasource.dart';
import 'package:appecommerce/data/datasources/product_remote_datasource.dart';
import 'package:appecommerce/data/datasources/purchases_remote_datasource.dart';
import 'package:appecommerce/data/datasources/quotes_remote_datasource.dart';
import 'package:appecommerce/data/models/address_model.dart';
import 'package:appecommerce/data/models/product_model.dart';
import 'package:appecommerce/data/models/purchase_model.dart';
import 'package:appecommerce/data/models/quote_model.dart';
import 'package:appecommerce/data/repositories/addresses_repository_impl.dart';
import 'package:appecommerce/data/repositories/favorites_repository_impl.dart';
import 'package:appecommerce/data/repositories/purchases_repository_impl.dart';
import 'package:appecommerce/data/repositories/quotes_repository_impl.dart';
import 'package:appecommerce/domain/entities/address_entity.dart';
import 'package:appecommerce/domain/usecases/addresses_usecases.dart';
import 'package:appecommerce/domain/usecases/favorites_usecases.dart';
import 'package:appecommerce/domain/usecases/purchases_usecases.dart';
import 'package:appecommerce/domain/usecases/quotes_usecases.dart';
import 'package:appecommerce/presentation/providers/addresses_provider.dart';
import 'package:appecommerce/presentation/providers/favorites_provider.dart';
import 'package:appecommerce/presentation/providers/purchases_provider.dart';
import 'package:appecommerce/presentation/providers/quotes_provider.dart';
import 'package:appecommerce/data/models/category_model.dart';
import 'package:appecommerce/data/datasources/statement_remote_datasource.dart';
import 'package:appecommerce/data/repositories/statement_repository_impl.dart';
import 'package:appecommerce/domain/entities/statement_entity.dart';
import 'package:appecommerce/domain/usecases/statement_usecases.dart';
import 'package:appecommerce/presentation/providers/statement_provider.dart';
import 'package:appecommerce/data/datasources/promotions_remote_datasource.dart';
import 'package:appecommerce/data/repositories/promotions_repository_impl.dart';
import 'package:appecommerce/domain/entities/promotion_entity.dart';
import 'package:appecommerce/domain/usecases/promotions_usecases.dart';
import 'package:appecommerce/presentation/providers/promotions_provider.dart';
import 'package:appecommerce/data/datasources/registration_remote_datasource.dart';
import 'package:appecommerce/data/repositories/registration_repository_impl.dart';
import 'package:appecommerce/domain/entities/register_entity.dart';
import 'package:appecommerce/domain/usecases/registration_usecases.dart';
import 'package:appecommerce/presentation/providers/registration_provider.dart';
import 'package:appecommerce/data/models/product_detail_model.dart';
import 'package:appecommerce/dependency_injection.dart';
import 'package:appecommerce/main.dart';
import 'package:appecommerce/core/push/push_messaging.dart';
import 'package:appecommerce/data/datasources/push_remote_datasource.dart';
import 'package:appecommerce/presentation/providers/app_lock_provider.dart';
import 'package:appecommerce/presentation/providers/push_provider.dart';
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

  /// Marcas del filtro. Se relacionan con los productos por el nombre.
  List<BrandEntity> brands = const [];

  /// Si es true la respuesta trae los topes del deslizador de precio (un
  /// cliente con lista de precios); si no, vienen null como con un invitado.
  bool priceBounds = false;

  /// Lo último que se pidió, para revisar lo que mandó la app.
  ProductFilters lastFilters = ProductFilters.none;
  final List<ProductFilters> filtersHistory = [];
  int? lastCategoryId;

  FakeProductRepo(this.products, {this.failure, this.pageSize = 20});

  @override
  Future<Either<Failure, ProductsPageEntity>> getProducts({
    int page = 1,
    String? search,
    int? categoryId,
    int? limit,
    ProductFilters filters = ProductFilters.none,
  }) async {
    requestedPages.add(page);
    lastFilters = filters;
    lastCategoryId = categoryId;
    filtersHistory.add(filters);
    if (failure != null) return Either.left(failure!);

    final brandNames = {
      for (final b in brands)
        if (filters.brandIds.contains(b.id)) b.name,
    };

    // Los topes se calculan antes de aplicar el rango de precio elegido.
    final beforePrice = products.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (search != null &&
          !p.name.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      if (brandNames.isNotEmpty && !brandNames.contains(p.brand)) return false;
      return true;
    }).toList();

    final filtered = beforePrice.where((p) {
      if (filters.minPrice != null && p.price < filters.minPrice!) return false;
      if (filters.maxPrice != null && p.price > filters.maxPrice!) return false;
      return true;
    }).toList();

    switch (filters.sort) {
      case ProductSort.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
      case ProductSort.stockDesc:
        filtered.sort((a, b) => b.stock.compareTo(a.stock));
      case ProductSort.relevance:
        break;
    }

    final prices = [
      for (final p in beforePrice)
        if (p.price > 0) p.price,
    ]..sort();
    final double? priceMin = priceBounds && prices.isNotEmpty ? prices.first : null;
    final double? priceMax = priceBounds && prices.isNotEmpty ? prices.last : null;

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
      priceMin: priceMin,
      priceMax: priceMax,
    ));
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async =>
      Either.right(const [
        CategoryEntity(id: 1, name: 'DRIVER'),
        CategoryEntity(id: 2, name: 'RCA'),
      ]);

  @override
  Future<Either<Failure, List<BrandEntity>>> getBrands({int? categoryId}) async {
    brandRequests.add(categoryId);
    if (categoryId != null && brandsFailure != null) {
      return Either.left(brandsFailure!);
    }
    // Con categoría, las que tienen productos en ella (por defecto, todas).
    if (categoryId != null && brandsByCategory.containsKey(categoryId)) {
      return Either.right(brandsByCategory[categoryId]!);
    }
    return Either.right(brands);
  }

  /// Marcas con productos en cada categoría (para `getBrands(categoryId:)`).
  final Map<int, List<BrandEntity>> brandsByCategory = {};

  /// Las categorías por las que se pidieron marcas (null = la lista completa).
  final List<int?> brandRequests = [];

  /// Si se indica, pedir las marcas de una categoría falla.
  Failure? brandsFailure;

  /// Lo que "tiene guardado el equipo" al arrancar (null = nada guardado).
  List<CategoryEntity>? cachedCategories;
  List<BrandEntity>? cachedBrands;
  ProductsPageEntity? cachedHome;

  @override
  Future<List<CategoryEntity>?> getCachedCategories() async => cachedCategories;

  @override
  Future<List<BrandEntity>?> getCachedBrands() async => cachedBrands;

  @override
  Future<ProductsPageEntity?> getCachedHomeProducts({required int limit}) async =>
      cachedHome;

  @override
  Future<Either<Failure, ProductDetailEntity>> getProductDetail(int id) async {
    final product = products.where((p) => p.id == id).firstOrNull;
    if (product == null) {
      return Either.left(const ServerFailure('Producto no encontrado'));
    }
    return Either.right(ProductDetailEntity(
      product: product,
      images: galleries[id] ?? const [],
      manualUrl: manualUrls[id],
      longDescription: 'Descripción de ${product.name}',
      warranty: '12 meses',
      currencyOptions: currencyOptions[id] ?? const [],
      related: relatedProducts[id] ?? const [],
    ));
  }

  /// Productos relacionados que devuelve el servidor para cada producto.
  final Map<int, List<ProductEntity>> relatedProducts = {};

  /// Fotos de la galería y manual en PDF por producto, para la ficha.
  final Map<int, List<String>> galleries = {};
  final Map<int, String> manualUrls = {};
}

class FakeStoreRepo implements StoreRepository {
  final CompanyInfoEntity? company;

  /// Lo que "tiene guardado el equipo" al arrancar.
  final CompanyInfoEntity? cached;

  /// Si se indica, la respuesta del backend no llega hasta que se complete.
  final Future<void>? delay;

  /// Banners que "tiene guardados el equipo" al arrancar.
  final List<BannerEntity>? cachedBanners;

  FakeStoreRepo({this.company, this.cached, this.delay, this.cachedBanners});

  @override
  Future<CompanyInfoEntity?> getCachedCompanyInfo() async => cached;

  @override
  Future<List<BannerEntity>?> getCachedBanners() async => cachedBanners;

  @override
  Future<Either<Failure, CompanyInfoEntity>> getCompanyInfo() async {
    await delay;
    return company == null
        ? Either.left(const NetworkFailure('Sin conexión'))
        : Either.right(company!);
  }

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
  String? brand,
}) =>
    ProductEntity(
      id: id,
      name: name,
      brand: brand,
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
    ProductFilters filters = ProductFilters.none,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<CategoryModel>> getCategories() => throw UnimplementedError();

  @override
  Future<List<BrandEntity>> getBrands({int? categoryId}) =>
      throw UnimplementedError();

  @override
  Future<List<CategoryModel>?> getCachedCategories() async => null;

  @override
  Future<List<BrandEntity>?> getCachedBrands() async => null;

  @override
  Future<ProductsPageEntity?> getCachedHomeProducts({required int limit}) async =>
      null;
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
      client: userType == 'cliente' ? loginUser : null,
    );
  }

  /// El cliente que devuelve el login.
  UserModel loginUser = testUser;

  /// Los `id_token` de Google recibidos; solo vale el que empieza con "valido".
  final List<String> googleTokens = [];

  @override
  Future<LoginResult> loginWithGoogle(String idToken) async {
    googleTokens.add(idToken);
    if (!idToken.startsWith('valido')) {
      throw const AuthException('No pudimos validar tu cuenta de Google. Intenta de nuevo.');
    }
    return LoginResult(
      userType: userType,
      token: 'token-google',
      client: userType == 'cliente' ? loginUser : null,
    );
  }

  @override
  Future<void> logout(String token) async => loggedOutTokens.add(token);

  /// Celular que el servidor "guardó" con `updatePhone`.
  String? savedPhone;

  /// Lo que devuelve `GET /user`.
  UserModel profile = testUser;

  /// Lo que devuelve `GET /cliente/titular` (por defecto, sin vincular).
  HolderModel holder = const HolderModel(linked: false);
  int holderCalls = 0;

  /// Si se indica, consultar al titular falla (sin red, por ejemplo).
  Exception? holderFailure;

  @override
  Future<HolderModel> getHolder() async {
    holderCalls++;
    if (holderFailure != null) throw holderFailure!;
    return holder;
  }

  @override
  Future<UserModel> getProfile() async => profile;

  @override
  Future<void> updatePhone(String phone) async {
    if (!phone.startsWith('9')) {
      throw const ServerException('Celular no válido', '422');
    }
    savedPhone = phone;
  }

  /// Fotos subidas (rutas locales) y, si se indica, el motivo por el que falla.
  final List<String> uploadedPhotos = [];
  int deletedPhotos = 0;
  Exception? photoFailure;

  @override
  Future<String?> uploadPhoto(String filePath) async {
    if (photoFailure != null) throw photoFailure!;
    uploadedPhotos.add(filePath);
    return '/storage/clientes/${uploadedPhotos.length}_7.jpg';
  }

  @override
  Future<void> deletePhoto() async {
    if (photoFailure != null) throw photoFailure!;
    deletedPhotos++;
  }

  /// Contraseña vigente del cliente en el "servidor" y los cambios recibidos.
  String currentPassword = 'secreto';
  final List<Map<String, String>> passwordChanges = [];

  @override
  Future<void> changePassword({
    required String current,
    required String next,
    required String confirmation,
  }) async {
    if (current != currentPassword) {
      throw const ValidationException('La contraseña actual es incorrecta');
    }
    passwordChanges.add({'current': current, 'next': next, 'confirmation': confirmation});
    currentPassword = next;
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
    // Agregar algo que estaba guardado para después lo devuelve al carrito.
    final updated = CartItemModel.fromEntity(
      base.copyWith(quantity: total, savedForLater: false),
    );
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

  /// Como el servidor: vaciar solo quita lo activo, lo guardado se queda.
  @override
  Future<void> clear() async =>
      items = items.where((i) => i.savedForLater).toList();

  @override
  Future<void> saveForLater(int productId) async => _flag(productId, true);

  @override
  Future<void> moveToCart(int productId) async {
    final index = items.indexWhere((i) => i.productId == productId);
    if (index >= 0 && items[index].quantity > stockLimit) {
      throw const ServerException(
        'Stock insuficiente para mover este producto al carrito.',
        '409',
      );
    }
    _flag(productId, false);
  }

  void _flag(int productId, bool saved) {
    final index = items.indexWhere((i) => i.productId == productId);
    if (index < 0) return;
    items[index] = CartItemModel.fromEntity(
      items[index].copyWith(savedForLater: saved),
    );
  }

  @override
  Future<List<CartItemModel>> sync(List<CartItemModel> value) async {
    syncCalls++;
    for (final item in value) {
      await add(item.productId, item.quantity);
    }
    return List.of(items);
  }
}

/// "Servidor" de favoritos en memoria. Con [failure] todas las llamadas fallan.
class FakeFavoritesRemote implements FavoritesRemoteDataSource {
  List<ProductModel> items = [];
  Exception? failure;
  final List<int> added = [];
  final List<int> removed = [];

  @override
  Future<List<ProductModel>> getFavorites() async {
    if (failure != null) throw failure!;
    return List.of(items);
  }

  @override
  Future<void> add(int productId) async {
    if (failure != null) throw failure!;
    added.add(productId);
  }

  @override
  Future<void> remove(int productId) async {
    if (failure != null) throw failure!;
    removed.add(productId);
  }
}

class FakePurchasesRemote implements PurchasesRemoteDataSource {
  List<PurchaseModel> online = [];
  StorePurchasesModel store =
      const StorePurchasesModel(linked: false, sales: []);

  @override
  Future<List<PurchaseModel>> getOnlinePurchases() async => List.of(online);

  @override
  Future<StorePurchasesModel> getStorePurchases() async => store;
}

class FakeAddressesRemote implements AddressesRemoteDataSource {
  List<AddressModel> items = [];
  final List<AddressDraft> saved = [];
  final List<int?> savedIds = [];
  final List<int> deleted = [];
  final List<int> madeDefault = [];

  final departments = const [
    UbigeoOption(code: '15', name: 'LIMA', ubigeoId: '150000'),
    UbigeoOption(code: '04', name: 'AREQUIPA', ubigeoId: '40000'),
  ];
  final provinces = const {
    '15': [UbigeoOption(code: '01', name: 'LIMA', ubigeoId: '150100')],
    '04': [UbigeoOption(code: '01', name: 'AREQUIPA', ubigeoId: '40100')],
  };
  final districts = const {
    '15/01': [
      UbigeoOption(code: '22', name: 'MIRAFLORES', ubigeoId: '150122'),
      UbigeoOption(code: '01', name: 'LIMA CERCADO', ubigeoId: '150101'),
    ],
  };

  @override
  Future<List<AddressModel>> getAddresses() async => List.of(items);

  @override
  Future<void> save(AddressDraft draft, {int? id}) async {
    saved.add(draft);
    savedIds.add(id);
  }

  @override
  Future<void> delete(int id) async => deleted.add(id);

  @override
  Future<void> setDefault(int id) async => madeDefault.add(id);

  @override
  Future<List<UbigeoOption>> getDepartments() async => departments;

  @override
  Future<List<UbigeoOption>> getProvinces(String department) async =>
      provinces[department] ?? const [];

  @override
  Future<List<UbigeoOption>> getDistricts(
    String department,
    String province,
  ) async =>
      districts['$department/$province'] ?? const [];
}

class FakeQuotesRemote implements QuotesRemoteDataSource {
  List<QuoteModel> items = [];
  final List<int> cancelled = [];
  Exception? cancelFailure;

  final List<int> converted = [];
  Exception? convertFailure;

  @override
  Future<String> convertToPurchase(int id) async {
    if (convertFailure != null) throw convertFailure!;
    converted.add(id);
    return 'Cotización enviada para aprobación de compra (COMP-1)';
  }

  @override
  Future<List<QuoteModel>> getQuotes() async => List.of(items);

  @override
  Future<void> cancel(int id, {String? reason}) async {
    if (cancelFailure != null) throw cancelFailure!;
    cancelled.add(id);
  }
}

/// Información de la empresa en memoria.
class FakeInfoRemote implements InfoRemoteDataSource {
  AboutModel about = const AboutModel(
    name: '7power',
    description: 'Somos una empresa peruana de audio automotriz.',
    values: [
      AboutValueEntity(title: 'Misión', description: 'Desarrollar soluciones.'),
      AboutValueEntity(title: 'Visión', description: 'Ser referentes.'),
    ],
  );
  List<ShippingStepEntity> steps = const [
    ShippingStepEntity(order: 1, title: 'Realiza el pedido', description: 'Por la web'),
    ShippingStepEntity(order: 2, title: 'Espera su transporte'),
  ];

  Exception? failure;
  final List<ContactMessage> contacts = [];
  final List<ClaimDraft> claims = [];
  ClaimStatus? claimToFind;

  /// Lo que devuelve `GET /reclamos/mis-reclamos`.
  List<ClaimStatus> myClaims = const [];

  @override
  Future<List<ClaimStatus>> getMyClaims() async {
    if (failure != null) throw failure!;
    return myClaims;
  }

  @override
  Future<AboutModel> getAbout() async {
    if (failure != null) throw failure!;
    return about;
  }

  @override
  Future<List<ShippingStepEntity>> getShippingSteps() async => steps;

  @override
  Future<void> sendContact(ContactMessage message) async {
    if (failure != null) throw failure!;
    contacts.add(message);
  }

  @override
  Future<ClaimReceipt> submitClaim(ClaimDraft claim) async {
    if (failure != null) throw failure!;
    claims.add(claim);
    return ClaimReceipt(
      number: 'REC-2026-00001',
      deadline: DateTime(2026, 11, 20),
    );
  }

  @override
  Future<ClaimStatus> findClaim(String number) async {
    final found = claimToFind;
    if (found == null || found.number != number) {
      throw const ServerException(
        'Reclamo no encontrado con el número proporcionado',
        '404',
      );
    }
    return found;
  }
}

/// Checkout en memoria: guarda lo último que se le envió para poder revisarlo.
class FakeCheckoutRemote implements CheckoutRemoteDataSource {
  List<PaymentTypeEntity> paymentTypes = const [
    PaymentTypeEntity(id: 1, name: 'Transferencia', code: 'transferencia'),
    PaymentTypeEntity(id: 2, name: 'Yape', code: 'yape'),
    PaymentTypeEntity(id: 3, name: 'Crédito', code: 'credito_autorizado'),
  ];
  bool testMode = true;
  double credit = 0;
  String? holderPhone;
  double? exchangeRate;

  /// Respuesta de `verificar-stock`.
  StockCheck stock = const StockCheck(hasStock: true);

  /// Resultado del pago: null = aprobado, o el mensaje de rechazo.
  String? declineMessage;
  Exception? payFailure;
  Exception? quoteFailure;

  QuoteOrder? lastQuote;
  PaymentOrder? lastPayment;
  final List<String> couponsAsked = [];

  @override
  Future<List<PaymentTypeEntity>> getPaymentTypes() async => paymentTypes;

  @override
  Future<bool> isGatewayInTestMode() async => testMode;

  @override
  Future<double> getCreditAvailable() async => credit;

  @override
  Future<String?> getHolderPhone() async => holderPhone;

  @override
  Future<double?> getExchangeRate() async => exchangeRate;

  @override
  Future<CouponEntity> validateCoupon(String code, double total) async {
    couponsAsked.add(code);
    if (code != 'PROMO10') throw const ValidationException('Cupón no válido o expirado');
    return CouponEntity(
      code: code,
      discount: total * 0.1,
      totalWithDiscount: total * 0.9,
    );
  }

  @override
  Future<StockCheck> verifyStock(List<CartItemEntity> items) async => stock;

  @override
  Future<List<CreatedQuote>> createQuotes(QuoteOrder order) async {
    if (quoteFailure != null) throw quoteFailure!;
    lastQuote = order;
    final currencies = {for (final i in order.items) FormatUtils.normalizeCurrency(i.currency)};
    return [
      for (final c in ['s', 'd'].where(currencies.contains))
        CreatedQuote(
          code: '2026-00001${c == 'd' ? '-D' : ''}',
          orderCode: 'PED-1',
          currency: c,
          total: order.items
              .where((i) => FormatUtils.normalizeCurrency(i.currency) == c)
              .fold(0.0, (s, i) => s + i.subtotal),
        ),
    ];
  }

  @override
  Future<PaymentResult> pay(PaymentOrder order) async {
    if (payFailure != null) throw payFailure!;
    lastPayment = order;
    if (declineMessage != null) {
      return PaymentResult(approved: false, message: declineMessage!);
    }
    return PaymentResult(
      approved: true,
      message: 'Pago aprobado (pasarela de prueba, sin cobro real).',
      simulated: true,
      reference: 'SIM-ABC123',
      cardBrand: order.card.brand,
      cardLast4: order.card.last4,
      purchase: PurchaseModel.fromJson({
        'codigo': 'PAGO-2026-00001',
        'estado_proceso': 'pendiente_facturar',
        'moneda': order.currency ?? 's',
        'subtotal': 100,
        'total': 100,
        'direccion_envio': order.delivery.address.fullAddress,
        'items': [
          {'producto_id': 1, 'nombre': 'Driver', 'cantidad': 1, 'precio_unitario': 100, 'subtotal': 100},
        ],
      }),
    );
  }
}

/// Estado de cuenta en memoria: reparte [movements] en páginas de [pageSize].
class FakeStatementRemote implements StatementRemoteDataSource {
  AccountSummary summary = const AccountSummary(
    creditLimit: 15000,
    creditUsed: 7450,
    creditAvailable: 7550,
    debtSoles: 7450,
  );
  List<AccountMovement> movements = const [];
  int pageSize = 2;
  Exception? failure;

  /// Lo último que se pidió.
  String? lastCode;
  DateTime? lastFrom;
  DateTime? lastTo;
  final List<int> pagesAsked = [];

  @override
  Future<AccountStatementPage> getStatement({
    required String erpCode,
    required DateTime from,
    required DateTime to,
    int page = 1,
  }) async {
    if (failure != null) throw failure!;
    lastCode = erpCode;
    lastFrom = from;
    lastTo = to;
    pagesAsked.add(page);
    final start = (page - 1) * pageSize;
    return AccountStatementPage(
      summary: summary,
      movements: movements.skip(start).take(pageSize).toList(),
      total: movements.length,
    );
  }
}

/// Notificaciones push en memoria. Cada test decide si "hay Firebase" y mete los
/// avisos que quiere que lleguen.
class FakePushMessaging implements PushMessaging {
  /// Si es false, `init()` dice que no se pueden usar (sin Firebase o sin permiso).
  bool configured = false;
  String? currentToken = 'tok-telefono-1';
  PushMessage? initial;
  int initCalls = 0;
  int deletedTokens = 0;

  final foregroundController = StreamController<PushMessage>.broadcast();
  final openedController = StreamController<PushMessage>.broadcast();
  final refreshController = StreamController<String>.broadcast();

  @override
  Future<bool> init() async {
    initCalls++;
    return configured;
  }

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get onTokenRefresh => refreshController.stream;

  @override
  Stream<PushMessage> get onForeground => foregroundController.stream;

  @override
  Stream<PushMessage> get onOpened => openedController.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;

  @override
  Future<void> deleteToken() async => deletedTokens++;
}

/// El registro de teléfonos en el "servidor".
class FakePushRemote implements PushRemoteDataSource {
  final List<String> registered = [];
  final List<String> unregistered = [];
  Exception? failure;

  @override
  Future<void> register(String token) async {
    if (failure != null) throw failure!;
    registered.add(token);
  }

  @override
  Future<void> unregister(String token) async {
    if (failure != null) throw failure!;
    unregistered.add(token);
  }
}

/// Cupones y ofertas en memoria.
class FakePromotionsRemote implements PromotionsRemoteDataSource {
  List<CouponOffer> coupons = const [];
  OfferBanner offers = const OfferBanner();
  List<PromoBanner> promoBanners = const [];
  List<FlashSale> flashSales = const [];
  Exception? failure;

  @override
  Future<List<PromoBanner>> getPromoBanners() async {
    if (failure != null) throw failure!;
    return promoBanners;
  }

  @override
  Future<List<FlashSale>> getFlashSales() async {
    if (failure != null) throw failure!;
    return flashSales;
  }

  @override
  Future<List<CouponOffer>> getActiveCoupons() async {
    if (failure != null) throw failure!;
    return coupons;
  }

  @override
  Future<OfferBanner> getOffers() async {
    if (failure != null) throw failure!;
    return offers;
  }
}

/// Registro y recuperación de contraseña en memoria. El rompecabezas se
/// resuelve cuando todas las piezas quedan en su hueco (orden 0, 1, 2…).
class FakeRegistrationRemote implements RegistrationRemoteDataSource {
  List<DocumentTypeEntity> types = const [
    DocumentTypeEntity(id: 1, name: 'DNI'),
    DocumentTypeEntity(id: 6, name: 'RUC'),
  ];
  CaptchaChallenge challenge = const CaptchaChallenge(
    token: 'tok-1',
    imagePath: 'storage/captcha/a.png',
    order: [1, 0],
    columns: 2,
    rows: 1,
  );

  Exception? registerFailure;
  Exception? forgotFailure;
  int captchasAsked = 0;
  final List<List<int>> verified = [];
  final List<RegisterDraft> registered = [];
  final List<String> registeredTokens = [];
  final List<String> forgotten = [];

  @override
  Future<List<DocumentTypeEntity>> getDocumentTypes() async => types;

  @override
  Future<CaptchaChallenge> getCaptcha() async {
    captchasAsked++;
    return challenge;
  }

  @override
  Future<void> verifyCaptcha(String token, List<int> order) async {
    verified.add(order);
    final solved = [for (var i = 0; i < order.length; i++) i];
    if (order.toString() != solved.toString()) {
      throw const ValidationException('Las piezas no están en el orden correcto.');
    }
  }

  @override
  Future<String> register(RegisterDraft draft, String captchaToken) async {
    if (registerFailure != null) throw registerFailure!;
    registered.add(draft);
    registeredTokens.add(captchaToken);
    return 'Usuario registrado exitosamente.';
  }

  @override
  Future<String> forgotPassword(String email) async {
    if (forgotFailure != null) throw forgotFailure!;
    forgotten.add(email);
    return 'Te enviamos un correo para cambiar tu contraseña.';
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
  final FakeFavoritesRemote favoritesRemote = FakeFavoritesRemote();
  final FakePurchasesRemote purchasesRemote = FakePurchasesRemote();
  final FakeAddressesRemote addressesRemote = FakeAddressesRemote();
  final FakeQuotesRemote quotesRemote = FakeQuotesRemote();
  final FakeCheckoutRemote checkoutRemote = FakeCheckoutRemote();
  final FakeInfoRemote infoRemote = FakeInfoRemote();
  final FakeRegistrationRemote registrationRemote = FakeRegistrationRemote();
  final FakePromotionsRemote promotionsRemote = FakePromotionsRemote();
  final FakeStatementRemote statementRemote = FakeStatementRemote();
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
    CompanyInfoEntity? cachedCompany,
    Future<void>? companyDelay,
    List<BannerEntity>? cachedBanners,
  })  : products = FakeProductRepo(catalog,
            failure: catalogFailure, pageSize: pageSize),
        store = FakeStoreRepo(
            company: company,
            cached: cachedCompany,
            delay: companyDelay,
            cachedBanners: cachedBanners);

  /// El bloqueo con huella; los tests lo leen para ver su estado.
  final AppLockProvider lock = AppLockProvider();

  /// Notificaciones push en memoria: por defecto "sin Firebase" (no hace nada).
  final FakePushMessaging pushMessaging = FakePushMessaging();
  final FakePushRemote pushRemote = FakePushRemote();

  Widget app() => MyApp(providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            loginUseCase: LoginUseCase(authRepo),
            logoutUseCase: LogoutUseCase(authRepo),
            restoreSessionUseCase: RestoreSessionUseCase(authRepo),
            refreshProfileUseCase: RefreshProfileUseCase(authRepo),
            updatePhoneUseCase: UpdatePhoneUseCase(authRepo),
            changePasswordUseCase: ChangePasswordUseCase(authRepo),
            repository: authRepo,
          )..restore(),
        ),
        ChangeNotifierProvider<AppLockProvider>(
          create: (_) => lock..load(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PushProvider>(
          create: (_) => PushProvider(messaging: pushMessaging, remote: pushRemote),
          update: (_, auth, push) => push!..attach(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) => CartProvider(
            getCartUseCase: GetCartUseCase(cartRepo),
            addToCartUseCase: AddToCartUseCase(cartRepo),
            updateQuantityUseCase: UpdateCartQuantityUseCase(cartRepo),
            removeFromCartUseCase: RemoveFromCartUseCase(cartRepo),
            clearCartUseCase: ClearCartUseCase(cartRepo),
            syncGuestCartUseCase: SyncGuestCartUseCase(cartRepo),
            saveForLaterUseCase: SaveForLaterUseCase(cartRepo),
            moveToCartUseCase: MoveToCartUseCase(cartRepo),
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
            getCachedCompanyInfoUseCase: GetCachedCompanyInfoUseCase(store),
          )..load(),
        ),
        DependencyInjection.authAware<HomeProvider>(
          () => HomeProvider(
            getBannersUseCase: GetBannersUseCase(store),
            getProductsUseCase: GetProductsUseCase(products),
            getCachedBannersUseCase: GetCachedBannersUseCase(store),
            getCachedHomeProductsUseCase: GetCachedHomeProductsUseCase(products),
          ),
        ),
        DependencyInjection.authAware<ProductsProvider>(
          () => ProductsProvider(
            getProductsUseCase: GetProductsUseCase(products),
            getCategoriesUseCase: GetCategoriesUseCase(products),
            getBrandsUseCase: GetBrandsUseCase(products),
            getCachedCategoriesUseCase: GetCachedCategoriesUseCase(products),
            getCachedBrandsUseCase: GetCachedBrandsUseCase(products),
          ),
        ),
        DependencyInjection.authAware<ProductDetailProvider>(
          () => ProductDetailProvider(
            getProductDetailUseCase: GetProductDetailUseCase(products),
          ),
        ),
        DependencyInjection.authAware<FavoritesProvider>(() {
          final repo = FavoritesRepositoryImpl(favoritesRemote);
          return FavoritesProvider(
            getFavoritesUseCase: GetFavoritesUseCase(repo),
            addFavoriteUseCase: AddFavoriteUseCase(repo),
            removeFavoriteUseCase: RemoveFavoriteUseCase(repo),
          );
        }),
        DependencyInjection.authAware<PurchasesProvider>(() {
          final repo = PurchasesRepositoryImpl(purchasesRemote);
          return PurchasesProvider(
            getOnlinePurchasesUseCase: GetOnlinePurchasesUseCase(repo),
            getStorePurchasesUseCase: GetStorePurchasesUseCase(repo),
          );
        }),
        DependencyInjection.authAware<AddressesProvider>(() {
          final repo = AddressesRepositoryImpl(addressesRemote);
          return AddressesProvider(
            getAddressesUseCase: GetAddressesUseCase(repo),
            saveAddressUseCase: SaveAddressUseCase(repo),
            deleteAddressUseCase: DeleteAddressUseCase(repo),
            setDefaultAddressUseCase: SetDefaultAddressUseCase(repo),
            ubigeo: GetUbigeoUseCase(repo),
          );
        }),
        DependencyInjection.authAware<QuotesProvider>(() {
          final repo = QuotesRepositoryImpl(quotesRemote);
          return QuotesProvider(
            getQuotesUseCase: GetQuotesUseCase(repo),
            cancelQuoteUseCase: CancelQuoteUseCase(repo),
            convertQuoteUseCase: ConvertQuoteToPurchaseUseCase(repo),
          );
        }),
        DependencyInjection.authAware<StatementProvider>(
          () => StatementProvider(
            getStatementUseCase:
                GetStatementUseCase(StatementRepositoryImpl(statementRemote)),
            available: true,
          ),
        ),
        ChangeNotifierProvider<PromotionsProvider>(create: (_) {
          final repo = PromotionsRepositoryImpl(promotionsRemote);
          return PromotionsProvider(
            getActiveCouponsUseCase: GetActiveCouponsUseCase(repo),
            getOffersUseCase: GetOffersUseCase(repo),
            getPromoBannersUseCase: GetPromoBannersUseCase(repo),
            getFlashSalesUseCase: GetFlashSalesUseCase(repo),
          );
        }),
        ChangeNotifierProvider<RegistrationProvider>(create: (_) {
          final repo = RegistrationRepositoryImpl(registrationRemote);
          return RegistrationProvider(
            getDocumentTypesUseCase: GetDocumentTypesUseCase(repo),
            getCaptchaUseCase: GetCaptchaUseCase(repo),
            verifyCaptchaUseCase: VerifyCaptchaUseCase(repo),
            registerUseCase: RegisterUseCase(repo),
            forgotPasswordUseCase: ForgotPasswordUseCase(repo),
          );
        }),
        ChangeNotifierProvider<InfoProvider>(create: (_) {
          final repo = InfoRepositoryImpl(infoRemote);
          return InfoProvider(
            getAboutUseCase: GetAboutUseCase(repo),
            getShippingStepsUseCase: GetShippingStepsUseCase(repo),
            sendContactUseCase: SendContactUseCase(repo),
            submitClaimUseCase: SubmitClaimUseCase(repo),
            findClaimUseCase: FindClaimUseCase(repo),
            getMyClaimsUseCase: GetMyClaimsUseCase(repo),
          );
        }),
        ChangeNotifierProvider<CheckoutProvider>(create: (_) {
          final repo = CheckoutRepositoryImpl(checkoutRemote);
          return CheckoutProvider(
            getPaymentTypesUseCase: GetPaymentTypesUseCase(repo),
            extras: GetCheckoutExtrasUseCase(repo),
            validateCouponUseCase: ValidateCouponUseCase(repo),
            verifyStockUseCase: VerifyStockUseCase(repo),
            createQuotesUseCase: CreateQuotesUseCase(repo),
            payOnlineUseCase: PayOnlineUseCase(repo),
          );
        }),
      ]);
}
