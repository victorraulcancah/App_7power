import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/promotion_entity.dart';

abstract class PromotionsRemoteDataSource {
  Future<List<CouponOffer>> getActiveCoupons();

  Future<OfferBanner> getOffers();

  Future<List<PromoBanner>> getPromoBanners();

  /// Las ventas flash vigentes (sin las que ya terminaron).
  Future<List<FlashSale>> getFlashSales();
}

class PromotionsRemoteDataSourceImpl implements PromotionsRemoteDataSource {
  final ApiClient client;

  PromotionsRemoteDataSourceImpl(this.client);

  /// El backend manda los decimales unas veces como número y otras como texto
  /// ("12.50").
  static double? _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  @override
  Future<List<CouponOffer>> getActiveCoupons() async {
    final response = await client.get(ApiConstants.activeCouponsEndpoint);
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
        .cast<Map<String, dynamic>>()
        .map((c) => CouponOffer(
              id: (c['id'] as num).toInt(),
              code: _text(c['codigo']) ?? '',
              title: _text(c['titulo']) ?? _text(c['codigo']) ?? '',
              description: _text(c['descripcion']),
              isPercentage: c['tipo_descuento'] == 'porcentaje',
              value: _number(c['valor_descuento']) ?? 0,
              minPurchase: _number(c['compra_minima']),
              endsAt: DateTime.tryParse(c['fecha_fin']?.toString() ?? ''),
              firstPurchaseOnly: c['solo_primera_compra'] == true ||
                  c['solo_primera_compra'] == 1,
            ))
        .where((c) => c.code.isNotEmpty)
        .toList();
  }

  @override
  Future<List<PromoBanner>> getPromoBanners() async {
    final response = await client.get(ApiConstants.promoBannersEndpoint);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    // Llega como { status, data: [...] }.
    final list = body is Map ? body['data'] : body;
    return ((list as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((b) => PromoBanner(
              id: (b['id'] as num).toInt(),
              title: _text(b['titulo']) ?? '',
              price: _text(b['precio']),
              buttonText: _text(b['texto_boton']),
              imageUrl: _text(b['imagen_url']),
              linkUrl: _text(b['enlace_url']),
              buttonColor: _text(b['color_boton']),
              nameBadgeColor: _text(b['color_badge_nombre']),
              priceBadgeColor: _text(b['color_badge_precio']),
            ))
        // Sin imagen no hay nada que mostrar.
        .where((b) => b.imageUrl != null)
        .toList();
  }

  @override
  Future<List<FlashSale>> getFlashSales() async {
    final response = await client.get(ApiConstants.flashSalesEndpoint);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final list = body is Map ? body['data'] : body;
    final now = DateTime.now();

    return ((list as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((s) {
          final endsAt = DateTime.tryParse(s['fecha_fin']?.toString() ?? '');
          if (endsAt == null) return null;
          return FlashSale(
            id: (s['id'] as num).toInt(),
            name: _text(s['nombre']) ?? '',
            imageUrl: _text(s['imagen_url']),
            endsAt: endsAt,
            buttonText: _text(s['texto_boton']),
            linkUrl: _text(s['enlace_url']),
            buttonColor: _text(s['color_boton']),
            badgeColor: _text(s['color_badge']),
          );
        })
        .whereType<FlashSale>()
        .where((s) => s.isActive(now))
        .toList();
  }

  @override
  Future<OfferBanner> getOffers() async {
    try {
      final response = await client.get(ApiConstants.activeOffersEndpoint);
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      return OfferBanner(
        imageUrl: _text(body['imagen_url']),
        products: ((body['productos'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((p) {
          final price = _number(p['precio']) ?? 0;
          return OfferProduct(
            id: (p['id'] as num).toInt(),
            name: _text(p['nombre']) ?? '',
            price: price,
            discountPrice: _number(p['precio_con_descuento']) ?? price,
            discountPercent: _number(p['descuento_porcentaje']) ?? 0,
            imageUrl: _text(p['imagen_principal']),
            stock: _number(p['stock'])?.toInt() ?? 0,
            currency: _text(p['moneda']),
            brand: _text(p['marca_nombre']),
          );
        }).toList(),
      );
    } on ServerException catch (e) {
      // Sin banner activo el backend responde 404: es "no hay ofertas".
      if (e.code == '404') return const OfferBanner();
      rethrow;
    }
  }
}
