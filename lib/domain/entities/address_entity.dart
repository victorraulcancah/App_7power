/// Departamento, provincia o distrito para los selectores de ubicación.
class UbigeoOption {
  /// Código dentro de su nivel ("15", "01", "22"): sirve para pedir el nivel
  /// siguiente.
  final String code;
  final String name;

  /// Id completo de la ubicación. Solo el de un distrito se envía al guardar
  /// una dirección.
  final String ubigeoId;

  const UbigeoOption({
    required this.code,
    required this.name,
    required this.ubigeoId,
  });
}

class AddressEntity {
  final int id;
  final String recipient;
  final String fullAddress;
  final String? reference;
  final bool isDefault;

  /// Id de ubicación del distrito.
  final String ubigeoId;

  /// Códigos por nivel, para precargar los selectores al editar.
  final String? departmentCode;
  final String? provinceCode;
  final String? districtCode;
  final String? department;
  final String? province;
  final String? district;

  const AddressEntity({
    required this.id,
    required this.recipient,
    required this.fullAddress,
    required this.ubigeoId,
    this.reference,
    this.isDefault = false,
    this.departmentCode,
    this.provinceCode,
    this.districtCode,
    this.department,
    this.province,
    this.district,
  });

  /// "Distrito, Provincia, Departamento".
  String get location =>
      [district, province, department].whereType<String>().join(', ');
}

/// Datos que el cliente llena para crear o editar una dirección.
class AddressDraft {
  final String fullAddress;
  final String ubigeoId;
  final String? reference;
  final bool isDefault;

  const AddressDraft({
    required this.fullAddress,
    required this.ubigeoId,
    this.reference,
    this.isDefault = false,
  });
}
