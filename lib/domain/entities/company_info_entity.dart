enum SocialNetwork { facebook, instagram, twitter, youtube, tiktok, whatsapp }

class PaymentMethodEntity {
  final int id;
  final String name;
  final String? imageUrl;

  const PaymentMethodEntity({
    required this.id,
    required this.name,
    this.imageUrl,
  });
}

/// Datos públicos de la empresa: identidad visual, contacto y redes.
class CompanyInfoEntity {
  final String name;
  final String? logoUrl;

  /// Color del navbar y del footer, "#RRGGBB". Lo configura la empresa.
  final String? navbarColor;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? address;
  final String? openingHours;
  final String? website;
  final Map<SocialNetwork, String> social;
  final List<PaymentMethodEntity> paymentMethods;

  const CompanyInfoEntity({
    required this.name,
    this.logoUrl,
    this.navbarColor,
    this.email,
    this.phone,
    this.mobile,
    this.address,
    this.openingHours,
    this.website,
    this.social = const {},
    this.paymentMethods = const [],
  });
}
