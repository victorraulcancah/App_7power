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

  // Registro y recuperación de contraseña (públicos)
  static const String registerEndpoint = '/register';
  static const String documentTypesEndpoint = '/document-types';
  static const String captchaChallengeEndpoint = '/captcha/desafio';
  static const String captchaVerifyEndpoint = '/captcha/verificar';
  static const String forgotPasswordEndpoint = '/forgot-password';

  /// API del ERP (7Power), donde está el estado de cuenta del cliente. No es la
  /// de la tienda. Por defecto es la de producción; para otro ERP (por ejemplo
  /// el local) se cambia al compilar, y si queda vacía el app no ofrece
  /// "Estado de cuenta":
  ///   flutter run --dart-define=ERP_API_URL=http://10.0.2.2/api
  static const String erpBaseUrl = String.fromEnvironment(
    'ERP_API_URL',
    defaultValue: 'https://novi-k.com/7power/public/api',
  );
  static bool get erpConfigured => erpBaseUrl.isNotEmpty;
  static const String statementEndpoint = '/ecommerce/estado-de-cuenta';

  // Promociones (públicas)
  static const String activeCouponsEndpoint = '/cupones/activos';
  static const String activeOffersEndpoint = '/banners-ofertas/activo';

  // Información de la empresa (públicos)
  static const String aboutEndpoint = '/sobre-nosotros/publico';
  static const String shippingStepsEndpoint = '/pasos-envio';
  static const String contactEndpoint = '/contacto';
  static const String claimCreateEndpoint = '/reclamos/crear';
  static const String claimLookupEndpoint = '/reclamos/buscar';

  /// Los reclamos del cliente con sesión (requiere token).
  static const String myClaimsEndpoint = '/reclamos/mis-reclamos';

  /// Sitio web de la tienda: de ahí salen los PDF legales y las páginas de
  /// registro y recuperación de contraseña.
  static const String webDomain = String.fromEnvironment(
    'WEB_DOMAIN',
    defaultValue: 'https://7power.pe',
  );
  static const String legalInfoPdf = '$webDomain/assets/legal/informacion-legal.pdf';
  static const String termsPdf =
      '$webDomain/assets/legal/terminos-y-condiciones-de-compra.pdf';
  static const String returnsPdf =
      '$webDomain/assets/legal/terminos-y-condiciones-de-compra.pdf#page=3';
  static const String privacyPdf = '$webDomain/assets/legal/'
      'politica-de-privacidad-y-proteccion-de-datos-personales.pdf';

  // Mi cuenta (requieren token de cliente)
  static const String profileEndpoint = '/user';
  static const String phoneEndpoint = '/user/telefono';
  static const String changePasswordEndpoint = '/user/change-password';
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
  static const String marcasEndpoint = '/marcas/publicas';}
