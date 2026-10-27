import 'package:flutter/material.dart';
import '../core/utils/color_utils.dart';

class AppTheme {
  /// Color de marca por defecto. Se usa hasta que llega el de la empresa
  /// (`color_navbar` en /empresa-info/publica) o si el backend no lo define.
  static const Color primary = Color(0xFF9B1C1C);
  static const Color secondary = Color(0xFF000000);
  static const Color bg = Colors.white;

  /// Fondo de las pantallas con tarjetas (gris muy claro, para que se noten).
  static const Color canvas = Color(0xFFF6F6F7);

  /// Tema de la tienda. [brand] es el color del navbar/footer que configura la
  /// empresa en el backend; también es el color primario de la app.
  ///
  /// Los grises (superficies, bordes, indicador de la barra inferior) salen de
  /// una paleta neutra: si salieran del color de marca, un navbar negro daría
  /// tonos rosados raros en toda la app.
  static ThemeData build([Color? brand]) {
    final seed = brand ?? primary;
    final onSeed = ColorUtils.onColor(seed);

    final neutral = ColorScheme.fromSeed(
      seedColor: const Color(0xFF707070),
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    );
    final scheme = neutral.copyWith(
      primary: seed,
      onPrimary: onSeed,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
      secondaryContainer: seed.withValues(alpha: 0.10),
      onSecondaryContainer: seed,
    );

    final radius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: onSeed,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: onSeed,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black,
        height: 66,
        indicatorColor: seed.withValues(alpha: 0.12),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? seed
                  : const Color(0xFF8A8A8F),
              size: 24,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? seed
                  : const Color(0xFF8A8A8F),
            )),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: Color(0xFFE6E6E9)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE9E9EC),
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF4A4A4F),
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xFFDCDCE0)),
        selectedColor: seed.withValues(alpha: 0.12),
        checkmarkColor: seed,
        labelStyle: const TextStyle(fontSize: 13),
        backgroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: seed.withValues(alpha: 0.5)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: onSeed,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static final ThemeData lightTheme = build();
}
