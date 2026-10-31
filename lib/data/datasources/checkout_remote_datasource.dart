import 'dart:convert';

import '../../core/constants/api_constants.dart';
import '../../core/errors/exceptions.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/checkout_entity.dart';
import '../models/purchase_model.dart';

abstract class CheckoutRemoteDataSource {
  Future<List<PaymentTypeEntity>> getPaymentTypes();

  Future<bool> isGatewayInTestMode();

  Future<double> getCreditAvailable();

  Future<String?> getHolderPhone();

  Future<double?> getExchangeRate();

  Future<CouponEntity> validateCoupon(String code, double total);

  Future<StockCheck> verifyStock(List<CartItemEntity> items);

  Future<List<CreatedQuote>> createQuotes(QuoteOrder order);

  Future<PaymentResult> pay(PaymentOrder order);
}

class CheckoutRemoteDataSourceImpl implements CheckoutRemoteDataSource {
  final ApiClient client;

  CheckoutRemoteDataSourceImpl(this.client);

  Map<String, dynamic> _map(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

  @override
  Future<List<PaymentTypeEntity>> getPaymentTypes() async {
    final response = await client.get(ApiConstants.paymentTypesEndpoint);
    return (_map(response.bodyBytes)['tipos_pago'] as List)
        .cast<Map<String, dynamic>>()
        .map((t) => PaymentTypeEntity(
              id: (t['id'] as num).toInt(),
              name: t['nombre']?.toString() ?? '',
              code: t['codigo']?.toString() ?? '',
              description: t['descripcion']?.toString(),
            ))
        .toList();
  }

  @override
  Future<bool> isGatewayInTestMode() async {
    final response = await client.get(ApiConstants.gatewayEndpoint);
    return _map(response.bodyBytes)['modo_prueba'] != false;
  }

  @override
  Future<double> getCreditAvailable() async {
    final response = await client.get(ApiConstants.creditEndpoint);
    final body = _map(response.bodyBytes);
    return body['vinculado'] == true
        ? FormatUtils.toDouble(body['credito_disponible'])
        : 0;
  }

  @override
  Future<String?> getHolderPhone() async {
    final response = await client.get(ApiConstants.holderEndpoint);
    final phone = _map(response.bodyBytes)['telefono']?.toString().trim();
    return (phone == null || phone.isEmpty) ? null : phone;
  }

  @override
  Future<double?> getExchangeRate() async {
    final response = await client.get(ApiConstants.exchangeRateEndpoint);
    final body = _map(response.bodyBytes);
    if (body['disponible'] != true) return null;
    return FormatUtils.toDouble(body['valor_final']);
  }

  @override
  Future<CouponEntity> validateCoupon(String code, double total) async {
    final response = await client.post(
      ApiConstants.couponValidateEndpoint,
      body: {'codigo': code, 'total': total},
    );
    final body = _map(response.bodyBytes);

    // Un cupón inválido es una respuesta correcta con `valido: false`.
    if (body['valido'] != true) {
      throw ValidationException(
        body['mensaje']?.toString() ?? 'Cupón no válido',
      );
    }
    final coupon = body['cupon'] as Map<String, dynamic>;
    return CouponEntity(
      code: coupon['codigo']?.toString() ?? code,
      title: coupon['titulo']?.toString(),
      discount: FormatUtils.toDouble(body['descuento']),
      totalWithDiscount: FormatUtils.toDouble(body['total_con_descuento']),
    );
  }

  @override
  Future<StockCheck> verifyStock(List<CartItemEntity> items) async {
    final response = await client.post(
      ApiConstants.verifyStockEndpoint,
      body: {
        'productos': [
          for (final i in items)
            {'producto_id': i.productId, 'cantidad': i.quantity},
        ],
      },
    );
    final body = _map(response.bodyBytes);
    return StockCheck(
      hasStock: body['hay_stock'] == true,
      shortages: ((body['faltantes'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((f) => StockShortage(
                productId: (f['producto_id'] as num).toInt(),
                name: f['nombre']?.toString() ?? '',
                requested: FormatUtils.toDouble(f['solicitado']).toInt(),
                available: FormatUtils.toDouble(f['disponible']).toInt(),
              ))
          .toList(),
    );
  }

  @override
  Future<List<CreatedQuote>> createQuotes(QuoteOrder order) async {
    final d = order.delivery;
    final a = d.address;

    final response = await client.post(
      ApiConstants.createQuoteEndpoint,
      body: {
        'productos': [
          for (final i in order.items)
            {'producto_id': i.productId, 'cantidad': i.quantity},
        ],
        if (order.payments.isNotEmpty)
          'metodo_pago_preferido': order.payments.first.type,
        if (order.payments.isNotEmpty)
          'metodos_pago': [
            for (final p in order.payments)
              {'tipo': p.type, 'moneda': p.currency, 'monto': p.amount},
          ],
        'direccion_envio': a.fullAddress,
        'telefono_contacto': d.phone,
        'observaciones': d.notes,
        'cliente_nombre': d.recipientName,
        'cliente_email': d.email,
        'forma_envio': d.shippingMethod,
        // El costo lo confirma la tienda; la web también manda 0.
        'costo_envio': 0,
        'numero_documento': d.documentNumber,
        'departamento_id': a.departmentCode,
        'provincia_id': _join([a.departmentCode, a.provinceCode]),
        'distrito_id':
            _join([a.departmentCode, a.provinceCode, a.districtCode]),
        'departamento_nombre': a.department,
        'provincia_nombre': a.province,
        'distrito_nombre': a.district,
        'ubicacion_completa': a.location,
        'reemplaza_cotizacion_id': ?order.replacesQuoteId,
      },
    );

    return ((_map(response.bodyBytes)['cotizaciones'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((q) => CreatedQuote(
              code: q['codigo_cotizacion']?.toString() ?? '',
              orderCode: q['pedido_codigo']?.toString(),
              currency: q['moneda']?.toString(),
              total: FormatUtils.toDouble(q['total']),
            ))
        .toList();
  }

  /// Une los códigos de ubicación ("15" + "01" = "1501"); null si falta alguno.
  String? _join(List<String?> parts) =>
      parts.any((p) => p == null) ? null : parts.join();

  @override
  Future<PaymentResult> pay(PaymentOrder order) async {
    final d = order.delivery;
    final a = d.address;

    final response = await client.post(
      ApiConstants.payEndpoint,
      body: {
        'cliente_nombre': d.recipientName,
        'cliente_email': d.email,
        'numero_documento': d.documentNumber,
        'telefono_contacto': d.phone,
        'direccion_envio': a.fullAddress,
        'departamento_nombre': a.department,
        'provincia_nombre': a.province,
        'distrito_nombre': a.district,
        'observaciones': d.notes,
        'moneda': order.currency,
        'cupon_codigo': order.couponCode,
        // De la tarjeta solo viajan estos tres datos.
        'token': order.card.token,
        'tarjeta_marca': order.card.brand,
        'tarjeta_ultimos4': order.card.last4,
      },
    );

    final body = _map(response.bodyBytes);
    final pago = body['pago'] as Map<String, dynamic>?;
    return PaymentResult(
      approved: body['aprobado'] == true,
      message: body['mensaje']?.toString() ?? '',
      purchase: pago == null ? null : PurchaseModel.fromJson(pago),
      cardBrand: pago?['tarjeta_marca']?.toString(),
      cardLast4: pago?['tarjeta_ultimos4']?.toString(),
      reference: pago?['referencia_pasarela']?.toString(),
      simulated: pago?['simulado'] == true,
    );
  }
}
