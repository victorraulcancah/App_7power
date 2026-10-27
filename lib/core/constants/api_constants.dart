class ApiConstants {
  /// Dominio raíz del backend (Laravel). ÚNICO lugar donde se define el host.
  /// Se puede sobreescribir al compilar sin tocar código:
  ///   flutter run --dart-define=API_DOMAIN=http://10.0.2.2:8000
  static const String baseDomain = String.fromEnvironment(
    'API_DOMAIN',
    defaultValue: 'http://api.7power-ecommerce.test',
  );

  /// El backend identifica a la empresa (tienda) por el header `Origin`
  /// (columna `carpeta` de la tabla companies), igual que lo hace la web.
  /// Una app móvil no lo envía sola, por eso se manda en cada request.
  static const String tenantOrigin = String.fromEnvironment(
    'TENANT_ORIGIN',
    defaultValue: 'http://7power-ecommerce.test',
  );

  static const String baseUrl = '$baseDomain/api';
  static const String storageUrl = '$baseDomain/storage';

  static const Duration connectionTimeout = Duration(seconds: 30);

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Origin': tenantOrigin,
  };

  // Endpoints públicos del ecommerce
  static const String productosEndpoint = '/productos/list';
  static const String productoImagenEndpoint = '/productos/img-public';
  static const String productosPreciosEndpoint = '/productos/product-list-price';
  static const String listasPreciosEndpoint = '/lista-de-precios/list-public';
  static const String estadoCuentaEndpoint = '/ecommerce/estado-de-cuenta';
  static const String validarCodigoClienteEndpoint =
      '/ecommerce/clientes/validar-codigo';
  static const String creditoClienteEndpoint = '/ecommerce/clientes/credito';
  static const String buscarClienteEndpoint = '/ecommerce/clientes/buscar';

  // Autenticación
  static const String loginEndpoint = '/login';
  static const String logoutEndpoint = '/logout';
  static const String recuperarPasswordEndpoint = '/recuperar-password';
}
