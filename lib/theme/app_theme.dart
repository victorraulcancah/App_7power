import 'package:flutter/material.dart';
import '../core/utils/color_utils.dart';

class AppTheme {
  /// Rojo de la marca: es el color de la app (botones, íconos, selección,
  /// precios). El color que la empresa configura en el backend (`color_navbar`,
  /// hoy negro) es solo de la barra superior y del footer; si no lo define, esas
  /// también usan este rojo.
  static const Color primary = Color(0xFF9B1C1C);

  /// Tonalidades del rojo: más oscuro para degradados y fondos suaves para
  /// botones secundarios, íconos y fichas.
  static const Color primaryDark = Color(0xFF6B1111);
  static const Color primaryLight = Color(0xFFD13A3A);
  static const Color primarySoft = Color(0xFFFBE4E4);

  /// Degradado de la marca para cabeceras y tarjetas destacadas.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
    stops: [0, 0.55, 1],
  );
  static const Color secondary = Color(0xFF000000);
  static const Color bg = Colors.white;

  /// Fondo de las pantallas con tarjetas (gris muy claro, para que se noten).
  static const Color canvas = Color(0xFFF6F6F7);

  /// Tema de la tienda. [navbar] es el color de la barra superior y del footer
  /// que configura la empresa en el backend; el resto de la app usa el rojo de
  /// la marca en distintas tonalidades.
  ///
  /// Los grises (superficies, bordes, indicador de la barra inferior) salen de
  /// una paleta neutra: así un navbar negro no tiñe el resto de la app.
  static ThemeData build([Color? navbar]) {
    const seed = primary;
    final onSeed = ColorUtils.onColor(seed);
    final bar = navbar ?? primary;
    final onBar = ColorUtils.onColor(bar);

    final neutral = ColorScheme.fromSeed(
      seedColor: const Color(0xFF707070),
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    );
    final scheme = neutral.copyWith(
      primary: seed,
      onPrimary: onSeed,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
      primaryContainer: primarySoft,
      onPrimaryContainer: primaryDark,
      secondaryContainer: seed.withValues(alpha: 0.10),
      onSecondaryContainer: seed,
    );

    final radius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      // Barra superior: el color de la empresa (negro hoy).
      appBarTheme: AppBarTheme(
        backgroundColor: bar,
        foregroundColor: onBar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: onBar,
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
      // Pestañas y filtros: la elegida va rellena con el color de la marca; las
      // demás, blancas con borde. El color del texto se fija a mano: sin él
      // salía blanco sobre blanco.
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xFFDCDCE0)),
        backgroundColor: Colors.white,
        selectedColor: seed,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF26262B),
        ),
        // ChoiceChip usa este estilo cuando está elegida.
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onSeed,
        ),
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
