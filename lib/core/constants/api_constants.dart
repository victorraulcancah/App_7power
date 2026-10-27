class ApiConstants {
  /// Dominio raíz del backend (ecommerce-back, Laravel). ÚNICO lugar donde
  /// se define el host. Por defecto apunta a producción; para usar un backend
  /// local se sobreescribe al compilar sin tocar código:
  ///   flutter run --dart-define=API_DOMAIN=http://10.0.2.2:8001
  static const String baseDomain = String.fromEnvironment(
    'API_DOMAIN',
    defaultValue: 'https://api.7power.pe',
  );

  static const String baseUrl = '$baseDomain/api';
  static const String storageUrl = '$baseDomain/storage';

  static const Duration connectionTimeout = Duration(seconds: 30);

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Tienda
  static const String empresaInfoEndpoint = '/empresa-info/publica';
  static const String bannersEndpoint = '/banners/publicos';
  static const String menusEndpoint = '/menus/publicos';

  // Sesión y carrito (requieren token, salvo /login)
  static const String loginEndpoint = '/login';
  static const String logoutEndpoint = '/logout';
  static const String cartEndpoint = '/cart';

  // Mi cuenta (requieren token de cliente)
  static const String profileEndpoint = '/user';
  static const String phoneEndpoint = '/user/telefono';
  static const String favoritesEndpoint = '/favoritos';
  static const String onlinePurchasesEndpoint = '/pago-en-linea';
  static const String storePurchasesEndpoint = '/compras/mis-compras-erp';
  static const String addressesEndpoint = '/mis-direcciones';
  static const String quotesEndpoint = '/cotizaciones/mis-cotizaciones';
  static const String quoteEndpoint = '/cotizaciones';

  // Checkout
  static const String paymentTypesEndpoint = '/tipos-pago/activos';
  static const String gatewayEndpoint = '/pasarela/configuracion';
  static const String creditEndpoint = '/cliente/credito';
  static const String holderEndpoint = '/cliente/titular';
  static const String exchangeRateEndpoint = '/cliente/tipo-cambio';
  static const String couponValidateEndpoint = '/cupones/validar';
  static const String verifyStockEndpoint = '/cotizaciones/verificar-stock';
  static const String createQuoteEndpoint = '/cotizaciones/ecommerce';
  static const String payEndpoint = '/pago-en-linea/pagar';

  // Ubicaciones (públicas)
  static const String departmentsEndpoint = '/departamentos';
  static const String provincesEndpoint = '/provincias';
  static const String districtsEndpoint = '/distritos';

  // Catálogo público
  static const String productosEndpoint = '/productos-publicos';
  static const String productoDetalleEndpoint = '/productos-publicos/{id}';
  static const String categoriasEndpoint = '/categorias/publicas';
  static const String marcasEndpoint = '/marcas/publicas';
}
