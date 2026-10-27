import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:appecommerce/core/errors/failures.dart';
import 'package:appecommerce/core/utils/color_utils.dart';
import 'package:appecommerce/core/utils/either.dart';
import 'package:appecommerce/data/models/banner_model.dart';
import 'package:appecommerce/data/models/category_model.dart';
import 'package:appecommerce/data/models/company_info_model.dart';
import 'package:appecommerce/data/models/product_model.dart';
import 'package:appecommerce/domain/entities/banner_entity.dart';
import 'package:appecommerce/domain/entities/category_entity.dart';
import 'package:appecommerce/domain/entities/company_info_entity.dart';
import 'package:appecommerce/domain/entities/product_entity.dart';
import 'package:appecommerce/domain/entities/products_page_entity.dart';
import 'package:appecommerce/domain/repositories/product_repository.dart';
import 'package:appecommerce/domain/repositories/store_repository.dart';
import 'package:appecommerce/domain/usecases/get_banners_usecase.dart';
import 'package:appecommerce/domain/usecases/get_categories_usecase.dart';
import 'package:appecommerce/domain/usecases/get_company_info_usecase.dart';
import 'package:appecommerce/domain/usecases/get_products_usecase.dart';
import 'package:appecommerce/main.dart';
import 'package:appecommerce/presentation/providers/company_provider.dart';
import 'package:appecommerce/presentation/providers/home_provider.dart';
import 'package:appecommerce/presentation/providers/products_provider.dart';

/// Repositorio falso: filtra en memoria como lo haría el backend y devuelve
/// los resultados en páginas de [pageSize].
class _FakeRepo implements ProductRepository {
  final List<ProductEntity> products;
  final Failure? failure;
  final int pageSize;
  final List<int> requestedPages = [];

  _FakeRepo(this.products, {this.failure, this.pageSize = 20});

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
}

class _FakeStore implements StoreRepository {
  final CompanyInfoEntity? company;

  _FakeStore({this.company});

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

const _empresa = CompanyInfoEntity(
  name: '7power',
  email: 'ventas@7power.pe',
  address: 'CERCADO DE LIMA',
  navbarColor: '#112233',
  social: {SocialNetwork.facebook: 'https://facebook.com/x'},
  paymentMethods: [PaymentMethodEntity(id: 1, name: 'Plin')],
);

Widget _app(_FakeRepo repo, {_FakeStore? store}) {
  final storeRepo = store ?? _FakeStore(company: _empresa);
  return MyApp(providers: [
    ChangeNotifierProvider<CompanyProvider>(
      create: (_) => CompanyProvider(
        getCompanyInfoUseCase: GetCompanyInfoUseCase(storeRepo),
      )..load(),
    ),
    ChangeNotifierProvider<HomeProvider>(
      create: (_) => HomeProvider(
        getBannersUseCase: GetBannersUseCase(storeRepo),
        getProductsUseCase: GetProductsUseCase(repo),
      ),
    ),
    ChangeNotifierProvider<ProductsProvider>(
      create: (_) => ProductsProvider(
        getProductsUseCase: GetProductsUseCase(repo),
        getCategoriesUseCase: GetCategoriesUseCase(repo),
      ),
    ),
  ]);
}

ProductEntity _p(int id, String name,
        {int categoryId = 1, double price = 10, int stock = 5}) =>
    ProductEntity(
      id: id,
      name: name,
      categoryId: categoryId,
      price: price,
      currency: 's',
      stock: stock,
    );

/// Pasa a la pestaña "Tienda".
Future<void> _goToShop(WidgetTester tester) async {
  await tester.tap(find.text('Tienda'));
  await tester.pumpAndSettle();
}

void main() {
  test('ProductModel interpreta la respuesta de /productos-publicos', () {
    final p = ProductModel.fromJson({
      'id': 635,
      'nombre': "1.5'' DRIVER 2VC",
      'precio': 45.5,
      'moneda': 'd',
      'stock': 92,
      'imagen_principal': 'http://api.test/storage/productos/a.jpg',
      'categoria': 'DRIVER',
      'categoria_id': 46,
      'marca': '7POWER',
      'codigo_producto': 'DRV2',
    });

    expect(p.price, 45.5);
    expect(p.hasPrice, isTrue);
    expect(p.currency, 'd');
    expect(p.stock, 92);
    expect(p.categoryId, 46);
    expect(p.imageUrl, startsWith('http'));
  });

  test('ProductModel tolera precio null y descarta imagen relativa', () {
    final p = ProductModel.fromJson({
      'id': 1,
      'nombre': 'X',
      'precio': null,
      'stock': 0,
      'imagen_principal': '/placeholder-product.jpg',
    });

    expect(p.price, 0);
    expect(p.hasPrice, isFalse);
    expect(p.imageUrl, isNull);
    expect(p.isAvailable, isFalse);
  });

  test('CategoryModel interpreta /categorias/publicas', () {
    final c = CategoryModel.fromJson({
      'id': 38,
      'nombre': 'ACCESORIOS',
      'imagen_url': 'http://api.test/storage/categorias/a.jpg',
      'productos_count': 39,
    });

    expect(c.name, 'ACCESORIOS');
    expect(c.productsCount, 39);
  });

  test('CompanyInfoModel lee color, contacto, redes y métodos de pago', () {
    final c = CompanyInfoModel.fromJson({
      'nombre_empresa': '7power',
      'telefono': null,
      'celular': '  ',
      'email': 'ventas@7power.pe',
      'direccion': 'CERCADO DE LIMA',
      'facebook': 'https://www.facebook.com/SEVENPOWER',
      'instagram': 'https://www.instagram.com/7power_oficial/',
      'twitter': null,
      'logo_url': 'https://api.7power.pe/storage/empresa/logos/a.png',
      'color_navbar': '#000000',
      'metodos_pago': [
        {'id': 1, 'nombre': 'Plin', 'imagen_url': 'https://x/plin.png'},
      ],
    });

    expect(c.name, '7power');
    expect(c.navbarColor, '#000000');
    expect(c.phone, isNull);
    expect(c.mobile, isNull);
    expect(c.social.keys,
        [SocialNetwork.facebook, SocialNetwork.instagram]);
    expect(c.paymentMethods.single.name, 'Plin');
  });

  test('BannerModel interpreta /banners/publicos', () {
    final b = BannerModel.fromJson({
      'id': 9,
      'titulo': 'Oferta',
      'enlace_url': '/shop',
      'imagen_url': 'https://api.7power.pe/storage/banners/a.png',
    });

    expect(b.linkUrl, '/shop');
    expect(b.subtitle, isNull);
  });

  test('ColorUtils convierte hex y elige el color de texto legible', () {
    expect(ColorUtils.parseHex('#9B1C1C'), const Color(0xFF9B1C1C));
    expect(ColorUtils.parseHex('9b1c1c'), const Color(0xFF9B1C1C));
    expect(ColorUtils.parseHex('rojo'), isNull);
    expect(ColorUtils.parseHex(null), isNull);
    expect(ColorUtils.onColor(Colors.black), Colors.white);
    expect(ColorUtils.onColor(Colors.white), Colors.black);
  });

  testWidgets('El navbar toma el color que define el backend', (tester) async {
    await tester.pumpWidget(_app(_FakeRepo([_p(1, 'Driver')])));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final material = Theme.of(tester.element(find.byType(AppBar)));
    expect(material.appBarTheme.backgroundColor, const Color(0xFF112233));
    expect(appBar.title, isNotNull);
  });

  testWidgets('Sin datos de empresa usa el color por defecto', (tester) async {
    await tester.pumpWidget(
      _app(_FakeRepo([_p(1, 'Driver')]), store: _FakeStore()),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(AppBar)));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF9B1C1C));
  });

  testWidgets('La portada muestra categorías y productos, sin footer',
      (tester) async {
    await tester.pumpWidget(_app(_FakeRepo([_p(1, 'Driver 400W')])));
    await tester.pumpAndSettle();

    expect(find.text('Categorías'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'DRIVER'), findsOneWidget);

    // La portada es una lista: lo que queda fuera de pantalla no se construye
    // hasta hacer scroll.
    await tester.scrollUntilVisible(
      find.text('Driver 400W'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Driver 400W'), findsOneWidget);

    // El contacto y los métodos de pago ya no se muestran en la portada.
    expect(find.text('Escríbenos a: ventas@7power.pe'), findsNothing);
    expect(find.text('Métodos de pago'), findsNothing);
  });

  testWidgets('El logo de la empresa sigue en el navbar', (tester) async {
    final empresaConLogo = CompanyInfoEntity(
      name: _empresa.name,
      logoUrl: 'http://api.test/logo.png',
      navbarColor: _empresa.navbarColor,
    );
    await tester.pumpWidget(_app(
      _FakeRepo([_p(1, 'Driver 400W')]),
      store: _FakeStore(company: empresaConLogo),
    ));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('Tocar una categoría de la portada abre la tienda filtrada',
      (tester) async {
    final repo = _FakeRepo([
      _p(1, 'Driver 400W'),
      _p(2, 'Cable RCA', categoryId: 2),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'RCA'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'RCA'), findsOneWidget);
    expect(find.text('Cable RCA'), findsWidgets);
    expect(find.text('Driver 400W'), findsNothing);
  });

  testWidgets('Tienda lista productos, marca agotados y sin precio',
      (tester) async {
    final repo = _FakeRepo([
      _p(1, 'Driver 400W', price: 120),
      _p(2, 'Cable RCA', categoryId: 2, price: 0),
      _p(3, 'Parlante', stock: 0),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await _goToShop(tester);

    expect(find.text('Driver 400W'), findsWidgets);
    expect(find.text('Cable RCA'), findsWidgets);
    expect(find.text('Parlante'), findsWidgets);
    expect(find.text('Agotado'), findsWidgets);
    expect(find.text('Consultar precio'), findsWidgets);
    expect(find.text('S/ 120.00'), findsWidgets);
  });

  testWidgets('Buscar y elegir categoría consultan al servidor',
      (tester) async {
    final repo = _FakeRepo([
      _p(1, 'Driver 400W'),
      _p(2, 'Cable RCA', categoryId: 2),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await _goToShop(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'RCA'));
    await tester.pumpAndSettle();
    expect(
      context(tester).read<ProductsProvider>().products.map((p) => p.name),
      ['Cable RCA'],
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'driver');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      context(tester).read<ProductsProvider>().products.map((p) => p.name),
      ['Driver 400W'],
    );
  });

  testWidgets('Al llegar al final carga la siguiente página', (tester) async {
    final repo = _FakeRepo(
      [for (var i = 1; i <= 6; i++) _p(i, 'Producto $i')],
      pageSize: 2,
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(repo.requestedPages, contains(1));

    final provider = context(tester).read<ProductsProvider>();
    expect(provider.hasMore, isTrue);

    await provider.loadMore();
    await tester.pumpAndSettle();

    expect(repo.requestedPages, contains(2));
    expect(provider.products.length, 4);
  });

  testWidgets('La tienda muestra el error y permite reintentar',
      (tester) async {
    final repo =
        _FakeRepo(const [], failure: const NetworkFailure('Sin conexión'));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await _goToShop(tester);

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

BuildContext context(WidgetTester tester) =>
    tester.element(find.byType(NavigationBar));
