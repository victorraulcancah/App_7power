import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/constants/app_constants.dart';
import 'dependency_injection.dart';
import 'presentation/pages/main_shell.dart';
import 'presentation/providers/company_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp(providers: DependencyInjection.providers));
}

class MyApp extends StatelessWidget {
  /// Providers globales. Se reciben por parámetro para poder sustituirlos
  /// por dobles de prueba en los tests.
  final List<SingleChildWidget> providers;

  const MyApp({super.key, required this.providers});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers,
      // El tema depende de la empresa (color del navbar/footer): se reconstruye
      // cuando llegan sus datos desde el backend.
      child: Consumer<CompanyProvider>(
        builder: (context, company, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConstants.appName,
          theme: company.theme,
          home: const MainShell(),
        ),
      ),
    );
  }
}
