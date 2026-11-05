import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../domain/entities/company_info_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/company_provider.dart';
import 'open_url.dart';
import 'product_share.dart';

/// Atención al cliente por WhatsApp: abre un chat con el mensaje ya escrito.
class WhatsAppSupport {
  static const String greeting = 'Hola, necesito ayuda con mi compra en 7Power.';

  /// El número que se usa: el de WhatsApp que la empresa configuró en el panel y,
  /// si no hay, el de la tienda web ([ApiConstants.supportWhatsapp]).
  static String number(CompanyInfoEntity? company) =>
      parseNumber(company?.social[SocialNetwork.whatsapp]) ??
      ApiConstants.supportWhatsapp;

  /// Saca el número de lo que haya escrito la empresa: puede ser un enlace
  /// (`https://wa.me/51951127833`, `...send?phone=51951127833`) o el número tal
  /// cual (`+51 951 127 833`, `951127833`). Devuelve solo dígitos con código de
  /// país, o null si no hay un número válido.
  static String? parseNumber(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;

    final fromLink = RegExp(r'(?:wa\.me/|phone=)\+?(\d+)').firstMatch(text);
    final digits = (fromLink?.group(1) ?? text.replaceAll(RegExp(r'\D'), ''));

    // Un celular peruano de 9 dígitos va con el código de país.
    if (digits.length == 9) return '51$digits';
    if (digits.length >= 10 && digits.length <= 15) return digits;
    return null;
  }

  /// La dirección que abre el chat con [message] escrito.
  static String url(String number, String message) =>
      'https://api.whatsapp.com/send?phone=$number&text=${Uri.encodeComponent(message)}';

  /// La consulta sobre un producto: su nombre, código y enlace a la web.
  static String productMessage(ProductEntity product) {
    final code = product.code != null ? ' (Código: ${product.code})' : '';
    return 'Hola, quiero consultar por este producto: ${product.name}$code\n'
        '${ProductShare.url(product.id)}';
  }

  /// Quien abre la dirección. Las pruebas lo sustituyen: abrir WhatsApp es cosa
  /// del sistema.
  static Future<void> Function(BuildContext context, String url) opener = openUrl;

  /// Abre el chat. Si el teléfono no puede, avisa (ver [openUrl]).
  static Future<void> open(
    BuildContext context, {
    String message = greeting,
  }) {
    final company = context.read<CompanyProvider>().info;
    return opener(context, url(number(company), message));
  }
}
