import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo de la empresa. Usa el que está configurado en el backend
/// (`logo_url`); si no hay o no carga, el logo de la tienda web, igual que
/// hace la web con `assets/images/logo/logo.svg`.
class BrandLogo extends StatelessWidget {
  static const String fallbackAsset = 'assets/images/logo.svg';

  final String? url;
  final double height;

  const BrandLogo({super.key, this.url, this.height = 34});

  Widget get _fallback => SvgPicture.asset(
        fallbackAsset,
        height: height,
        fit: BoxFit.contain,
        semanticsLabel: 'Logo',
      );

  @override
  Widget build(BuildContext context) {
    final logoUrl = url;
    if (logoUrl == null || logoUrl.isEmpty) return _fallback;

    return Image.network(
      logoUrl,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _fallback,
    );
  }
}
