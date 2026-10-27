import 'package:flutter/material.dart';

class ColorUtils {
  /// "#9B1C1C" (o sin "#") -> Color. Devuelve null si no es un hex válido.
  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
    if (match == null) return null;
    return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  /// Blanco u negro, el que se lea mejor sobre [background].
  static Color onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : Colors.black;
}
