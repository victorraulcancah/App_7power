import '../../core/utils/format_utils.dart';
import '../../domain/entities/quote_entity.dart';

String? _text(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

class QuoteModel extends QuoteEntity {
  const QuoteModel({
    required super.id,
    required super.code,
    required super.status,
    required super.total,
    super.date,
    super.expiresAt,
    super.currency,
    super.subtotal,
    super.igv,
    super.shipping,
    super.editable,
    super.expired,
    super.canConvert,
    super.shippingMethod,
    super.deliveryAddress,
    super.phone,
    super.notes,
    super.payments,
    super.items,
  });

  /// Elemento de `GET /cotizaciones/mis-cotizaciones` (`cotizaciones[]`).
  factory QuoteModel.fromJson(Map<String, dynamic> json) {
    final orderState = json['estado_pedido'] as Map<String, dynamic>?;
    final quoteState = json['estado_actual'] as Map<String, dynamic>?;

    // Lo que ve el cliente es el estado del pedido; si no hay, el de la
    // cotización, y por defecto "En espera" (igual que la web).
    final status = _text(orderState?['nombre_estado']) ??
        _text(quoteState?['nombre']) ??
        'En espera';

    final address = [
      _text(json['direccion_envio']),
      _text(json['ubicacion_completa']),
    ].whereType<String>().join(' - ');

    return QuoteModel(
      id: (json['id'] as num).toInt(),
      code: json['codigo_cotizacion']?.toString() ?? '',
      status: status,
      date: DateTime.tryParse(json['fecha_cotizacion']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['fecha_vencimiento']?.toString() ?? ''),
      currency: json['moneda']?.toString(),
      subtotal: FormatUtils.toDouble(json['subtotal']),
      igv: FormatUtils.toDouble(json['igv']),
      shipping: FormatUtils.toDouble(json['costo_envio']),
      total: FormatUtils.toDouble(json['total']),
      editable: json['editable'] == true,
      expired: json['esta_vencida'] == true,
      canConvert: json['puede_convertir_compra'] == true,
      shippingMethod: _text(json['forma_envio']),
      deliveryAddress: address.isEmpty ? null : address,
      phone: _text(json['telefono_contacto']),
      notes: _text(json['observaciones']),
      payments: ((json['metodos_pago'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((p) => QuotePaymentEntity(
                type: p['tipo']?.toString() ?? '',
                currency: p['moneda']?.toString(),
                amount: FormatUtils.toDouble(p['monto']),
              ))
          .toList(),
      items: ((json['productos'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((p) => QuoteItemEntity(
                productId: (p['producto_id'] as num?)?.toInt() ?? 0,
                name: p['nombre']?.toString() ?? '',
                imageUrl: _text(p['imagen']),
                quantity: FormatUtils.toDouble(p['cantidad']).toInt(),
                unitPrice: FormatUtils.toDouble(p['precio_unitario']),
                subtotal: FormatUtils.toDouble(p['subtotal']),
              ))
          .toList(),
    );
  }
}
