import '../../domain/entities/info_entity.dart';

String? _text(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

class AboutModel extends AboutEntity {
  const AboutModel({
    required super.name,
    super.description,
    super.imageUrl,
    super.values,
  });

  /// `data` de `GET /sobre-nosotros/publico`.
  factory AboutModel.fromJson(Map<String, dynamic> json) {
    // Solo los valores activos, en su orden.
    final rawValues = ((json['valores'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where((v) => v['activo'] != false)
        .toList()
      ..sort((a, b) =>
          ((a['orden'] as num?) ?? 0).compareTo((b['orden'] as num?) ?? 0));

    return AboutModel(
      name: _text(json['nombre_empresa']) ?? '',
      // El texto llega con saltos de línea de Windows (\r\n).
      description: _text(json['descripcion'])?.replaceAll('\r\n', '\n'),
      imageUrl: _text(json['imagen_descripcion_url']),
      values: [
        for (final v in rawValues)
          AboutValueEntity(
            title: _text(v['titulo']) ?? '',
            description: (_text(v['descripcion']) ?? '').replaceAll('\r\n', '\n'),
            imageUrl: _text(v['imagen_url']),
          ),
      ],
    );
  }
}

/// Paso de `GET /pasos-envio` (`data[]`).
ShippingStepEntity shippingStepFromJson(Map<String, dynamic> json) =>
    ShippingStepEntity(
      order: (json['orden'] as num?)?.toInt() ?? 0,
      title: _text(json['titulo']) ?? '',
      description: _text(json['descripcion']),
      imageUrl: _text(json['imagen']),
    );

/// `reclamo` de `POST /reclamos/crear`.
ClaimReceipt claimReceiptFromJson(Map<String, dynamic> json) => ClaimReceipt(
      number: json['numero_reclamo']?.toString() ?? '',
      deadline: DateTime.tryParse(json['fecha_limite_respuesta']?.toString() ?? ''),
    );

/// `reclamo` de `GET /reclamos/buscar/{numero}`.
ClaimStatus claimStatusFromJson(Map<String, dynamic> json) => ClaimStatus(
      number: json['numero_reclamo']?.toString() ?? '',
      status: _text(json['estado']) ?? 'pendiente',
      requestType: _text(json['tipo_solicitud']),
      deadline: DateTime.tryParse(json['fecha_limite_respuesta']?.toString() ?? ''),
      response: _text(json['respuesta_proveedor']),
      responseDate: DateTime.tryParse(json['fecha_respuesta']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
