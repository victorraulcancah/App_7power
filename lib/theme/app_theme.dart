import 'package:flutter/material.dart';
import '../core/utils/color_utils.dart';

class AppTheme {
  /// Color de marca por defecto. Se usa hasta que llega el de la empresa
  /// (`color_navbar` en /empresa-info/publica) o si el backend no lo define.
  static const Color primary = Color(0xFF9B1C1C);
  static const Color secondary = Color(0xFF000000);
  static const Color bg = Colors.white;

  /// Tema de la tienda. [brand] es el color del navbar/footer que configura la
  /// empresa en el backend; también se usa como color primario de la app.
  static ThemeData build([Color? brand]) {
    final seed = brand ?? primary;
    final scheme = ColorScheme.fromSeed(seedColor: seed).copyWith(
      primary: seed,
      onPrimary: ColorUtils.onColor(seed),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static final ThemeData lightTheme = build();
}
