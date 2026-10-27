import '../../domain/entities/address_entity.dart';

String? _text(dynamic value) {
  final s = value?.toString().trim();
  return (s == null || s.isEmpty || s == 'N/A') ? null : s;
}

class AddressModel extends AddressEntity {
  const AddressModel({
    required super.id,
    required super.recipient,
    required super.fullAddress,
    required super.ubigeoId,
    super.reference,
    super.isDefault,
    super.departmentCode,
    super.provinceCode,
    super.districtCode,
    super.department,
    super.province,
    super.district,
  });

  /// Elemento de `GET /mis-direcciones` (`direcciones[]`).
  factory AddressModel.fromJson(Map<String, dynamic> json) {
    final ubigeo = json['ubigeo'] as Map<String, dynamic>?;

    return AddressModel(
      id: (json['id'] as num).toInt(),
      recipient: json['nombre_destinatario']?.toString() ?? '',
      fullAddress: json['direccion_completa']?.toString() ?? '',
      reference: _text(json['referencia']),
      isDefault: json['predeterminada'] == true || json['predeterminada'] == 1,
      ubigeoId: json['id_ubigeo']?.toString() ?? '',
      departmentCode: _text(ubigeo?['departamento']),
      provinceCode: _text(ubigeo?['provincia']),
      districtCode: _text(ubigeo?['distrito']),
      department: _text(ubigeo?['departamento_nombre']),
      province: _text(ubigeo?['provincia_nombre']),
      district: _text(ubigeo?['distrito_nombre']),
    );
  }
}

/// Elemento de `/departamentos`, `/provincias/{d}` o `/distritos/{d}/{p}`.
/// `id_ubigeo` llega como número; se convierte a texto porque así lo exige el
/// servidor al guardar una dirección.
UbigeoOption ubigeoOptionFromJson(Map<String, dynamic> json) => UbigeoOption(
      code: json['id']?.toString() ?? '',
      name: json['nombre']?.toString() ?? '',
      ubigeoId: json['id_ubigeo']?.toString() ?? '',
    );
