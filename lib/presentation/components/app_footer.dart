import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/color_utils.dart';
import '../../domain/entities/company_info_entity.dart';

/// Pie de página de la tienda. Usa el mismo color que el navbar, que define la
/// empresa en el backend (igual que la web).
class AppFooter extends StatelessWidget {
  final CompanyInfoEntity info;
  final Color backgroundColor;

  const AppFooter({
    super.key,
    required this.info,
    required this.backgroundColor,
  });

  static FaIconData _icon(SocialNetwork network) => switch (network) {
        SocialNetwork.facebook => FontAwesomeIcons.facebookF,
        SocialNetwork.instagram => FontAwesomeIcons.instagram,
        SocialNetwork.twitter => FontAwesomeIcons.xTwitter,
        SocialNetwork.youtube => FontAwesomeIcons.youtube,
        SocialNetwork.tiktok => FontAwesomeIcons.tiktok,
        SocialNetwork.whatsapp => FontAwesomeIcons.whatsapp,
      };

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final onBg = ColorUtils.onColor(backgroundColor);
    final textStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: onBg);

    final lines = <String>[
      if (info.email != null) 'Escríbenos a: ${info.email}',
      if (info.phone != null) 'Teléfono: ${info.phone}',
      if (info.mobile != null) 'Celular: ${info.mobile}',
      if (info.address != null) 'Dirección: ${info.address}',
      if (info.openingHours != null) info.openingHours!,
    ];

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.logoUrl != null)
            Image.network(
              info.logoUrl!,
              height: 44,
              errorBuilder: (_, _, _) => Text(info.name, style: textStyle),
            )
          else
            Text(info.name,
                style: textStyle?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: textStyle),
            ),
          if (info.social.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                for (final entry in info.social.entries)
                  InkWell(
                    onTap: () => _open(entry.value),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: onBg.withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: FaIcon(_icon(entry.key), size: 16, color: onBg),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (info.paymentMethods.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Métodos de pago',
                style: textStyle?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in info.paymentMethods)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: method.imageUrl == null
                        ? Text(method.name)
                        : Image.network(
                            method.imageUrl!,
                            height: 28,
                            errorBuilder: (_, _, _) => Text(method.name),
                          ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
