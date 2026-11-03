import '../../domain/entities/company_info_entity.dart';

/// Respuesta de `GET /empresa-info/publica` (el objeto está dentro de `data`).
class CompanyInfoModel extends CompanyInfoEntity {
  const CompanyInfoModel({
    required super.name,
    super.logoUrl,
    super.navbarColor,
    super.splashColor,
    super.splashText,
    super.email,
    super.phone,
    super.mobile,
    super.address,
    super.openingHours,
    super.website,
    super.social,
    super.paymentMethods,
  });

  /// Mismo formato que la respuesta del backend, para guardarlo en el equipo y
  /// leerlo con [CompanyInfoModel.fromJson] en el próximo arranque.
  Map<String, dynamic> toJson() => {
        'nombre_empresa': name,
        'logo_url': logoUrl,
        'color_navbar': navbarColor,
        'splash_color_fondo': splashColor,
        'splash_texto': splashText,
        'email': email,
        'telefono': phone,
        'celular': mobile,
        'direccion': address,
        'horario_atencion': openingHours,
        'website': website,
        for (final entry in social.entries) entry.key.name: entry.value,
        'metodos_pago': [
          for (final m in paymentMethods)
            {'id': m.id, 'nombre': m.name, 'imagen_url': m.imageUrl},
        ],
      };

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
      splashColor: text('splash_color_fondo'),
      splashText: text('splash_texto'),
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
