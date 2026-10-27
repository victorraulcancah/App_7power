import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'dependency_injection.dart';
import 'presentation/pages/home_page.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      home: const HomePage(),
    );

    // MultiProvider no admite una lista vacía; mientras no haya features
    // registradas en DependencyInjection se devuelve la app directamente.
    final providers = DependencyInjection.providers;
    if (providers.isEmpty) return app;
    return MultiProvider(providers: providers, child: app);
  }
}
