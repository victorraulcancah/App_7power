// Genera los PNG del ícono y del splash a partir del "7" vectorial de la marca
// (assets/icon/seven.svg, tomado de la web).
//
//   flutter test tool/generate_icons.dart
//
// No es un test de verdad: se ejecuta con `flutter test` porque ahí está el
// motor gráfico de Flutter para rasterizar el SVG. Después hay que correr
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const int _size = 1024;

/// Fondo negro del navbar de 7power.
const ui.Color _black = ui.Color(0xFF000000);

Future<void> _save(String path, ui.Image image) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Dibuja el "7" centrado, ocupando [fraction] del lado del lienzo.
Future<ui.Image> _render(
  PictureInfo info, {
  required double fraction,
  ui.Color? background,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (background != null) {
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 1024, 1024),
      ui.Paint()..color = background,
    );
  }
  final target = _size * fraction;
  final scale = target / info.size.width;
  canvas
    ..translate((_size - target) / 2, (_size - info.size.height * scale) / 2)
    ..scale(scale)
    ..drawPicture(info.picture);
  return recorder.endRecording().toImage(_size, _size);
}

void main() {
  testWidgets('genera los íconos', (tester) async {
    await tester.runAsync(() async {
      final svg = File('assets/icon/seven.svg').readAsStringSync();
      final info = await vg.loadPicture(SvgStringLoader(svg), null);

      // Ícono completo (iOS y Android antiguo): "7" sobre negro.
      await _save('assets/icon/icon.png',
          await _render(info, fraction: 0.62, background: _black));

      // Primer plano del ícono adaptativo de Android: solo el "7", dentro de
      // la zona segura (el sistema recorta el borde con distintas máscaras).
      await _save('assets/icon/icon_foreground.png',
          await _render(info, fraction: 0.46));

      // Imagen del splash: el "7" sin fondo.
      await _save('assets/icon/splash_logo.png',
          await _render(info, fraction: 0.62));
    });
  });
}
