import 'package:provider/provider.dart';

class DependencyInjection {
  /// Providers globales de la app. Cada feature nueva registra aquí su
  /// provider con sus casos de uso (datasource -> repository -> usecase).
  static List<ChangeNotifierProvider> get providers => [];
}
