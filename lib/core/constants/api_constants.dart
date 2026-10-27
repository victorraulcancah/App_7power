class ApiConstants {
  /// Dominio raíz del backend. ÚNICO lugar donde se define el host.
  /// Se puede sobreescribir al compilar sin tocar código:
  ///   flutter run --dart-define=API_DOMAIN=https://otro-dominio.pe
  static const String baseDomain = String.fromEnvironment(
    'API_DOMAIN',
    defaultValue: 'https://example.com',
  );

  static const String baseUrl = '$baseDomain/api';
  static const String storageUrl = '$baseDomain/storage';

  static const Duration connectionTimeout = Duration(seconds: 30);

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Endpoints
}
