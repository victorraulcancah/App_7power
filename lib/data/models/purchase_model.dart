import '../../core/utils/format_utils.dart';
import '../../domain/entities/purchase_entity.dart';

String? _text(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

class PurchaseModel extends PurchaseEntity {
  const PurchaseModel({
    required super.code,
    required super.stage,
    required super.total,
    super.date,
    super.currency,
    super.subtotal,
    super.igv,
    super.discount,
    super.shipping,
    super.couponCode,
    super.invoiceNumber,
    super.invoiceSentAt,
    super.shippingMethod,
    super.customerEmail,
    super.deliveryAddress,
    super.items,
  });

  /// Elemento de `GET /pago-en-linea` (`pagos[]`).
  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final address = [
      _text(json['direccion_envio']),
      _text(json['distrito_nombre']),
      _text(json['provincia_nombre']),
      _text(json['departamento_nombre']),
    ].whereType<String>().join(', ');

    return PurchaseModel(
      code: json['codigo']?.toString() ?? '',
      stage: PurchaseStage.fromApi(json['estado_proceso']?.toString()),
      date: DateTime.tryParse(json['fecha']?.toString() ?? ''),
      currency: json['moneda']?.toString(),
      subtotal: FormatUtils.toDouble(json['subtotal']),
      igv: FormatUtils.toDouble(json['igv']),
      discount: FormatUtils.toDouble(json['descuento']),
      shipping: FormatUtils.toDouble(json['costo_envio']),
      total: FormatUtils.toDouble(json['total']),
      couponCode: _text(json['cupon_codigo']),
      invoiceNumber: _text(json['comprobante_erp']),
      invoiceSentAt: DateTime.tryParse(
        json['comprobante_enviado_at']?.toString() ?? '',
      ),
      shippingMethod: _text(json['forma_envio']),
      customerEmail: _text(json['cliente_email']),
      deliveryAddress: address.isEmpty ? null : address,
      items: ((json['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((i) => PurchaseItemEntity(
                productId: (i['producto_id'] as num?)?.toInt() ?? 0,
                code: _text(i['codigo_producto']),
                name: i['nombre']?.toString() ?? '',
                quantity: FormatUtils.toDouble(i['cantidad']).toInt(),
                unitPrice: FormatUtils.toDouble(i['precio_unitario']),
                subtotal: FormatUtils.toDouble(i['subtotal']),
                imageUrl: _text(i['imagen_url']),
              ))
          .toList(),
    );
  }
}

/// Respuesta de `GET /compras/mis-compras-erp`.
class StorePurchasesModel extends StorePurchasesResult {
  const StorePurchasesModel({required super.linked, required super.sales});

  factory StorePurchasesModel.fromJson(Map<String, dynamic> json) =>
      StorePurchasesModel(
        linked: json['vinculado'] == true,
        sales: ((json['compras'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map((c) => StoreSaleEntity(
                  id: (c['id'] as num).toInt(),
                  document: c['documento']?.toString() ?? '',
                  date: _text(c['fecha']),
                  currency: c['moneda']?.toString(),
                  total: FormatUtils.toDouble(c['total']),
                  cancelled: c['anulada'] == true,
                  notes: _text(c['observaciones']),
                  items: ((c['productos'] as List?) ?? const [])
                      .cast<Map<String, dynamic>>()
                      .map((p) => StoreSaleItemEntity(
                            code: _text(p['codigo']),
                            name: p['nombre']?.toString() ?? '',
                            quantity: FormatUtils.toDouble(p['cantidad']),
                            price: FormatUtils.toDouble(p['precio']),
                            subtotal: FormatUtils.toDouble(p['subtotal']),
                          ))
                      .toList(),
                ))
            .toList(),
      );
}
