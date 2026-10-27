import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'dependency_injection.dart';
import 'presentation/pages/products_page.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(providers: DependencyInjection.providers));
}

class MyApp extends StatelessWidget {
  /// Providers globales. Se reciben por parámetro para poder sustituirlos
  /// por dobles de prueba en los tests.
  final List<ChangeNotifierProvider> providers;

  const MyApp({super.key, required this.providers});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        home: const ProductsPage(),
      ),
    );
  }
}
