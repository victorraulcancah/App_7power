import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:appecommerce/core/errors/failures.dart';
import 'package:appecommerce/core/network/api_client.dart';
import 'package:appecommerce/core/storage/response_cache.dart';
import 'package:appecommerce/core/utils/either.dart';
import 'package:appecommerce/data/datasources/product_remote_datasource.dart';
import 'package:appecommerce/data/datasources/store_remote_datasource.dart';
import 'package:appecommerce/domain/entities/banner_entity.dart';
import 'package:appecommerce/domain/entities/product_filters.dart';
import 'package:appecommerce/domain/entities/products_page_entity.dart';
import 'package:appecommerce/domain/usecases/get_banners_usecase.dart';
import 'package:appecommerce/domain/usecases/get_cached_home_usecases.dart';
import 'package:appecommerce/domain/usecases/get_products_usecase.dart';
import 'package:appecommerce/presentation/providers/home_provider.dart';

import 'support/fakes.dart';

/// Un servidor de pruebas que cuenta los pedidos y responde lo que se le diga.
http.Client _server(
  Map<String, Object> routes, {
  void Function(http.Request)? onRequest,
}) =>
    MockClient((r) async {
      onRequest?.call(r);
      final body = routes[r.url.path.split('/api').last];
      if (body == null) return http.Response('no existe', 404);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });

Map<String, Object> _productsBody(String name) => {
      'productos': [
        {
          'id': 1,
          'nombre': name,
          'precio': 10.5,
          'moneda': 's',
          'stock': 5,
          'categoria': 'DRIVER',
          'categoria_id': 46,
          'marca': '7POWER',
          'codigo_producto': 'D1',
        },
      ],
      'pagination': {'current_page': 1, 'last_page': 1, 'total': 1},
    };

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ResponseCache', () {
    test('guarda y devuelve lo mismo', () async {
      final cache = ResponseCache();
      await cache.write('banners', '{"data":[]}');

      expect(await cache.read('banners'), '{"data":[]}');
      expect(await cache.read('otra'), isNull);
    });

    test('lo vencido no se usa', () async {
      var now = DateTime(2026, 11, 1);
      final cache = ResponseCache(now: () => now);
      await cache.write('banners', 'x');

      now = now.add(ResponseCache.maxAge - const Duration(hours: 1));
      expect(await cache.read('banners'), 'x');

      now = now.add(const Duration(hours: 2));
      expect(await cache.read('banners'), isNull);
    });

    test('el contenido puede traer el separador sin romperse', () async {
      final cache = ResponseCache();
      await cache.write('k', 'a|b|c');

      expect(await cache.read('k'), 'a|b|c');
    });

    test('un valor dañado se ignora', () async {
      SharedPreferences.setMockInitialValues({'response_cache_v1_k': 'sin separador'});

      expect(await ResponseCache().read('k'), isNull);
    });

    test('prune borra los de otros dueños y deja los indicados', () async {
      final cache = ResponseCache();
      await cache.write('home_products_8_guest', 'g');
      await cache.write('home_products_8_u1', 'viejo');
      await cache.write('home_products_8_u2', 'actual');
      await cache.write('banners', 'b');

      await cache.prune('home_products_',
          keep: {'home_products_8_guest', 'home_products_8_u2'});

      expect(await cache.read('home_products_8_guest'), 'g');
      expect(await cache.read('home_products_8_u2'), 'actual');
      expect(await cache.read('home_products_8_u1'), isNull);
      // Lo que no empieza con el prefijo no se toca.
      expect(await cache.read('banners'), 'b');
    });

    test('ownerFor distingue al invitado y a cada sesión, sin guardar el token',
        () {
      expect(ResponseCache.ownerFor(null), 'guest');
      expect(ResponseCache.ownerFor(''), 'guest');
      final a = ResponseCache.ownerFor('1|token-a');
      expect(a, startsWith('u'));
      expect(a, isNot(contains('token')));
      expect(a, isNot(ResponseCache.ownerFor('2|token-b')));
      expect(a, ResponseCache.ownerFor('1|token-a'));
    });
  });

  group('Datos guardados de la portada', () {
    ProductRemoteDataSourceImpl products(
      http.Client client, {
      String? token,
    }) =>
        ProductRemoteDataSourceImpl(
          ApiClient(client: client)..authToken = token,
          cache: ResponseCache(),
        );

    test('los productos de la portada se guardan y se leen para el mismo cliente',
        () async {
      final remote = products(_server({'/productos-publicos': _productsBody('Driver')}));

      expect(await remote.getCachedHomeProducts(limit: 8), isNull);
      await remote.getProducts(page: 1, limit: 8);

      final cached = await remote.getCachedHomeProducts(limit: 8);
      expect(cached?.items.single.name, 'Driver');
    });

    test('lo guardado por un invitado no se le muestra a un cliente con sesión',
        () async {
      final routes = {'/productos-publicos': _productsBody('Precio de invitado')};
      await products(_server(routes)).getProducts(page: 1, limit: 8);

      final conSesion = products(_server(routes), token: '5|secreto');

      expect(await conSesion.getCachedHomeProducts(limit: 8), isNull);

      // Y al revés: al pedir con sesión se guarda aparte.
      await conSesion.getProducts(page: 1, limit: 8);
      expect(await conSesion.getCachedHomeProducts(limit: 8), isNotNull);
      expect(await products(_server(routes)).getCachedHomeProducts(limit: 8),
          isNotNull, reason: 'el del invitado se conserva');
    });

    test('al iniciar otra sesión se borra lo de la sesión anterior', () async {
      final routes = {'/productos-publicos': _productsBody('X')};
      await products(_server(routes), token: '1|vieja').getProducts(page: 1, limit: 8);
      await products(_server(routes), token: '2|nueva').getProducts(page: 1, limit: 8);

      expect(
        await products(_server(routes), token: '1|vieja').getCachedHomeProducts(limit: 8),
        isNull,
      );
      expect(
        await products(_server(routes), token: '2|nueva').getCachedHomeProducts(limit: 8),
        isNotNull,
      );
    });

    test('un invitado que pide no borra lo de la sesión', () async {
      final routes = {'/productos-publicos': _productsBody('X')};
      await products(_server(routes), token: '9|sesion').getProducts(page: 1, limit: 8);

      // Al abrir el app se pide como invitado antes de restaurar la sesión.
      await products(_server(routes)).getProducts(page: 1, limit: 8);

      expect(
        await products(_server(routes), token: '9|sesion').getCachedHomeProducts(limit: 8),
        isNotNull,
      );
    });

    test('una búsqueda, una categoría o la tienda paginada no se guardan',
        () async {
      final remote = products(_server({'/productos-publicos': _productsBody('X')}));

      await remote.getProducts(page: 1, limit: 8, categoryId: 46);
      await remote.getProducts(page: 1, limit: 8, search: 'rca');
      await remote.getProducts(page: 1);

      expect(await remote.getCachedHomeProducts(limit: 8), isNull);
    });

    test('categorías y marcas se guardan; lo ilegible se ignora', () async {
      final remote = products(_server({
        '/categorias/publicas': [
          {'id': 38, 'nombre': 'ACCESORIOS', 'productos_count': 39},
        ],
        '/marcas/publicas': [
          {'id': 25, 'nombre': '7POWER', 'productos_count': 404},
          {'id': 99, 'nombre': 'VACIA', 'productos_count': 0},
        ],
      }));

      expect(await remote.getCachedCategories(), isNull);
      expect(await remote.getCachedBrands(), isNull);

      await remote.getCategories();
      await remote.getBrands();

      expect((await remote.getCachedCategories())?.single.name, 'ACCESORIOS');
      // Las marcas sin productos tampoco se ofrecen desde lo guardado.
      expect((await remote.getCachedBrands())?.map((b) => b.name), ['7POWER']);

      SharedPreferences.setMockInitialValues({
        'response_cache_v1_categories': '${DateTime.now().millisecondsSinceEpoch}|{roto',
      });
      expect(await remote.getCachedCategories(), isNull);
    });

    test('los banners se guardan', () async {
      final remote = StoreRemoteDataSourceImpl(
        ApiClient(
          client: _server({
            '/banners/publicos': {
              'data': [
                {'id': 9, 'imagen_url': 'https://api.test/storage/banners/a.png'},
              ],
            },
          }),
        ),
        cache: ResponseCache(),
      );

      expect(await remote.getCachedBanners(), isNull);
      await remote.getBanners();

      expect((await remote.getCachedBanners())?.single.id, 9);
    });

    test('si el servidor falla, no se pisa lo guardado', () async {
      final ok = products(_server({'/productos-publicos': _productsBody('Bueno')}));
      await ok.getProducts(page: 1, limit: 8);

      final caido = products(MockClient((_) async => http.Response('boom', 500)));
      await expectLater(caido.getProducts(page: 1, limit: 8), throwsA(anything));

      expect((await caido.getCachedHomeProducts(limit: 8))?.items.single.name, 'Bueno');
    });
  });

  group('HomeProvider con lo guardado', () {
    ProductsPageEntity page(String name) => ProductsPageEntity(
          items: [product(1, name)],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

    test('muestra lo guardado enseguida y lo reemplaza cuando llega lo nuevo',
        () async {
      final network = Completer<void>();
      final repo = _SlowProductRepo([product(1, 'Nuevo')], network.future)
        ..cachedHome = page('Guardado');
      final store = FakeStoreRepo(
        cachedBanners: const [BannerEntity(id: 1, imageUrl: 'http://api.test/b.png')],
      );
      final home = HomeProvider(
        getBannersUseCase: GetBannersUseCase(store),
        getProductsUseCase: GetProductsUseCase(repo),
        getCachedBannersUseCase: GetCachedBannersUseCase(store),
        getCachedHomeProductsUseCase: GetCachedHomeProductsUseCase(repo),
      );

      final loading = home.load();
      await Future<void>.delayed(Duration.zero);

      // La red sigue pendiente, pero la portada ya está.
      expect(home.status, HomeStatus.loaded);
      expect(home.recommended.single.name, 'Guardado');
      expect(home.banners, isNotEmpty);

      network.complete();
      await loading;
      expect(home.recommended.single.name, 'Nuevo');
    });

    test('sin nada guardado espera a la red como antes', () async {
      final network = Completer<void>();
      final repo = _SlowProductRepo([product(1, 'Nuevo')], network.future);
      final store = FakeStoreRepo();
      final home = HomeProvider(
        getBannersUseCase: GetBannersUseCase(store),
        getProductsUseCase: GetProductsUseCase(repo),
        getCachedBannersUseCase: GetCachedBannersUseCase(store),
        getCachedHomeProductsUseCase: GetCachedHomeProductsUseCase(repo),
      );

      final loading = home.load();
      await Future<void>.delayed(Duration.zero);
      expect(home.status, HomeStatus.loading);

      network.complete();
      await loading;
      expect(home.status, HomeStatus.loaded);
      expect(home.recommended.single.name, 'Nuevo');
    });

    test('si la red falla se queda con lo guardado', () async {
      final repo = FakeProductRepo([], failure: const NetworkFailure('sin red'))
        ..cachedHome = page('Guardado');
      final store = FakeStoreRepo();
      final home = HomeProvider(
        getBannersUseCase: GetBannersUseCase(store),
        getProductsUseCase: GetProductsUseCase(repo),
        getCachedBannersUseCase: GetCachedBannersUseCase(store),
        getCachedHomeProductsUseCase: GetCachedHomeProductsUseCase(repo),
      );

      await home.load();

      expect(home.recommended.single.name, 'Guardado');
      expect(home.status, HomeStatus.loaded);
    });

    test('al cambiar de sesión no se muestran los productos del cliente anterior',
        () async {
      final network = Completer<void>();
      final repo = _SlowProductRepo([product(1, 'De Ana')], Future.value());
      final store = FakeStoreRepo();
      final home = HomeProvider(
        getBannersUseCase: GetBannersUseCase(store),
        getProductsUseCase: GetProductsUseCase(repo),
        getCachedBannersUseCase: GetCachedBannersUseCase(store),
        getCachedHomeProductsUseCase: GetCachedHomeProductsUseCase(repo),
      );
      await home.load();
      expect(home.recommended.single.name, 'De Ana');

      // Entra otro cliente: la red tarda y no hay nada guardado para él.
      repo.networkDelay = network.future;
      final reloading = home.reloadForAuthChange();
      await Future<void>.delayed(Duration.zero);

      expect(home.recommended, isEmpty);
      expect(home.status, HomeStatus.loading);

      network.complete();
      await reloading;
    });
  });
}

/// Un listado de productos cuya respuesta de red tarda lo que el test decida.
class _SlowProductRepo extends FakeProductRepo {
  Future<void> networkDelay;

  _SlowProductRepo(super.products, this.networkDelay);

  @override
  Future<Either<Failure, ProductsPageEntity>> getProducts({
    int page = 1,
    String? search,
    int? categoryId,
    int? limit,
    ProductFilters filters = ProductFilters.none,
  }) async {
    await networkDelay;
    return super.getProducts(
      page: page,
      search: search,
      categoryId: categoryId,
      limit: limit,
      filters: filters,
    );
  }
}
