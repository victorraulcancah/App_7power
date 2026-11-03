import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
          // Sin animar el cambio: al abrir, la barra no debe verse pasar por el
          // color por defecto hasta llegar al de la empresa.
          themeAnimationDuration: Duration.zero,
          // La tienda es peruana: calendario y diálogos del sistema en español.
          locale: const Locale('es', 'PE'),
          supportedLocales: const [Locale('es', 'PE'), Locale('es')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // Sin datos de la empresa no se sabe qué color usar: se espera un
          // instante en lugar de pintar el color por defecto y cambiarlo.
          home: company.isLoaded ? const MainShell() : const _Splash(),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}
