import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/product_entity.dart';
import '../components/app_snackbar.dart';

/// Compartir un producto por WhatsApp, correo o lo que el cliente elija: se
/// manda su nombre, el precio (si se puede ver) y el enlace a la web.
class ProductShare {
  /// Quien envía el texto. Las pruebas lo sustituyen: la hoja de compartir es
  /// del sistema y no existe ahí.
  static Future<void> Function(String text, String subject) sender =
      (text, subject) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  };

  /// La página del producto en la web.
  static String url(int productId) =>
      '${ApiConstants.webDomain}/product-details/$productId';

  /// El texto que se comparte. El precio solo va si el cliente puede verlo: a un
  /// invitado sin lista de precios no se le muestra.
  static String message(ProductEntity product) {
    final price = product.priceVisible && product.price > 0
        ? ' - ${FormatUtils.money(product.price, currency: product.currency)}'
        : '';
    return 'Mira este producto: ${product.name}$price\n${url(product.id)}';
  }

  static Future<void> share(BuildContext context, ProductEntity product) async {
    try {
      await sender(message(product), product.name);
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, 'No se pudo compartir el producto.');
      }
    }
  }
}
