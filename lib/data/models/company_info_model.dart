import '../../domain/entities/company_info_entity.dart';

/// Respuesta de `GET /empresa-info/publica` (el objeto está dentro de `data`).
class CompanyInfoModel extends CompanyInfoEntity {
  const CompanyInfoModel({
    required super.name,
    super.logoUrl,
    super.navbarColor,
    super.email,
    super.phone,
    super.mobile,
    super.address,
    super.openingHours,
    super.website,
    super.social,
    super.paymentMethods,
  });

  factory CompanyInfoModel.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    // Solo las redes que la empresa tiene configuradas.
    final social = <SocialNetwork, String>{
      for (final network in SocialNetwork.values)
        if (text(network.name) != null) network: text(network.name)!,
    };

    return CompanyInfoModel(
      name: text('nombre_empresa') ?? '',
      logoUrl: text('logo_url'),
      navbarColor: text('color_navbar'),
      email: text('email'),
      phone: text('telefono'),
      mobile: text('celular'),
      address: text('direccion'),
      openingHours: text('horario_atencion'),
      website: text('website'),
      social: social,
      paymentMethods: ((json['metodos_pago'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((m) => PaymentMethodEntity(
                id: (m['id'] as num).toInt(),
                name: m['nombre']?.toString() ?? '',
                imageUrl: m['imagen_url']?.toString(),
              ))
          .toList(),
    );
  }
}
