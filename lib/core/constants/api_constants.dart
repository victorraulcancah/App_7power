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

  // Catálogo público
  static const String productosEndpoint = '/productos-publicos';
  static const String productoDetalleEndpoint = '/productos-publicos/{id}';
  static const String categoriasEndpoint = '/categorias/publicas';
  static const String marcasEndpoint = '/marcas/publicas';
}
