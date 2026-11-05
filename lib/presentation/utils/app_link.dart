import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../pages/product_detail_page.dart';
import '../pages/promotions/coupons_page.dart';
import '../pages/promotions/offers_page.dart';
import 'open_url.dart';

/// A dónde apunta un enlace que viene del backend (los botones de banners y
/// ventas flash se configuran con direcciones de la web).
enum AppLinkKind { product, shop, offers, coupons, external }

class AppLinkTarget {
  final AppLinkKind kind;

  /// El producto, cuando [kind] es [AppLinkKind.product].
  final int? productId;

  /// La dirección completa a abrir fuera del app, cuando [kind] es external.
  final String? url;

  const AppLinkTarget(this.kind, {this.productId, this.url});
}

class AppLink {
  static const _ownHosts = {'7power.pe', 'www.7power.pe'};

  /// Interpreta [url]: las páginas de la tienda se abren dentro del app y el
  /// resto en el navegador. Acepta direcciones completas de la propia web
  /// (`https://7power.pe/product-details/667`) y rutas sueltas (`/shop`).
  static AppLinkTarget parse(String? url) {
    final raw = url?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (raw.isEmpty || uri == null) return const AppLinkTarget(AppLinkKind.shop);

    final isAbsolute = uri.hasScheme;
    if (isAbsolute && !_ownHosts.contains(uri.host.toLowerCase())) {
      return AppLinkTarget(AppLinkKind.external, url: raw);
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return const AppLinkTarget(AppLinkKind.shop);

    switch (segments.first) {
      case 'product-details' || 'product':
        final id = segments.length > 1 ? int.tryParse(segments[1]) : null;
        if (id != null) {
          return AppLinkTarget(AppLinkKind.product, productId: id);
        }
      case 'shop':
        return const AppLinkTarget(AppLinkKind.shop);
      case 'ofertas':
        return const AppLinkTarget(AppLinkKind.offers);
      case 'cupones':
        return const AppLinkTarget(AppLinkKind.coupons);
      case 'my-account' when segments.length > 1 && segments[1] == 'cupones':
        return const AppLinkTarget(AppLinkKind.coupons);
    }

    // Cualquier otra página de la web se abre en el navegador.
    final full = isAbsolute ? raw : '${ApiConstants.webDomain}/${segments.join('/')}';
    return AppLinkTarget(AppLinkKind.external, url: full);
  }

  /// Abre [url] donde corresponda. [onOpenShop] cambia a la pestaña Tienda.
  static Future<void> open(
    BuildContext context,
    String? url, {
    required VoidCallback onOpenShop,
  }) async {
    final target = parse(url);
    final navigator = Navigator.of(context);

    switch (target.kind) {
      case AppLinkKind.product:
        await navigator.push(MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: target.productId!),
        ));
      case AppLinkKind.shop:
        onOpenShop();
      case AppLinkKind.offers:
        await navigator.push(MaterialPageRoute(builder: (_) => const OffersPage()));
      case AppLinkKind.coupons:
        await navigator.push(MaterialPageRoute(builder: (_) => const CouponsPage()));
      case AppLinkKind.external:
        await openUrl(context, target.url!);
    }
  }
}
