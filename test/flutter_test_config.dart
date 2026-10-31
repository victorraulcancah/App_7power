import 'dart:async';

import 'package:appecommerce/presentation/components/product_image.dart';

/// Se ejecuta antes de cada archivo de pruebas.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // La caché de imágenes en disco usa plugins (almacenamiento y SQLite) que
  // no existen en las pruebas: ahí se usa la carga de red normal.
  ProductImage.diskCache = false;
  await testMain();
}
