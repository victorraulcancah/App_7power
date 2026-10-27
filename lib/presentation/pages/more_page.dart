import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/color_utils.dart';
import '../../domain/entities/company_info_entity.dart';
import '../components/components.dart';
import '../providers/company_provider.dart';
import '../utils/open_url.dart';
import 'more/about_page.dart';
import 'more/claim_book_page.dart';
import 'more/contact_page.dart';
import 'more/shipping_steps_page.dart';

/// Pestaña "Más": información de la empresa, atención al cliente y legal.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static FaIconData _icon(SocialNetwork network) => switch (network) {
        SocialNetwork.facebook => FontAwesomeIcons.facebookF,
        SocialNetwork.instagram => FontAwesomeIcons.instagram,
        SocialNetwork.twitter => FontAwesomeIcons.xTwitter,
        SocialNetwork.youtube => FontAwesomeIcons.youtube,
        SocialNetwork.tiktok => FontAwesomeIcons.tiktok,
        SocialNetwork.whatsapp => FontAwesomeIcons.whatsapp,
      };

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CompanyProvider>();
    final info = company.info;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _BrandCard(info: info, color: company.brandColor),
        MenuGroup(title: 'Conoce 7power', children: [
          MenuItem(
            icon: Icons.business_outlined,
            title: 'Sobre nosotros',
            subtitle: 'Quiénes somos, misión y valores',
            onTap: () => _open(context, const AboutPage()),
          ),
          MenuItem(
            icon: Icons.local_shipping_outlined,
            title: 'Cómo funciona el envío',
            subtitle: 'Del pedido a tu puerta',
            onTap: () => _open(context, const ShippingStepsPage()),
          ),
        ]),
        MenuGroup(title: 'Atención al cliente', children: [
          MenuItem(
            icon: Icons.support_agent_outlined,
            title: 'Contáctanos',
            subtitle: 'Escríbenos o llámanos',
            onTap: () => _open(context, const ContactPage()),
          ),
          MenuItem(
            icon: Icons.menu_book_outlined,
            title: 'Libro de reclamaciones',
            subtitle: 'Registra un reclamo o una queja',
            onTap: () => _open(context, const ClaimBookPage()),
          ),
          MenuItem(
            icon: Icons.manage_search_outlined,
            title: 'Consultar un reclamo',
            subtitle: 'Revisa su estado con tu número',
            onTap: () => showClaimLookup(context),
          ),
        ]),
        MenuGroup(title: 'Legal', children: [
          MenuItem(
            icon: Icons.gavel_outlined,
            title: 'Información legal',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openUrl(context, ApiConstants.legalInfoPdf),
          ),
          MenuItem(
            icon: Icons.description_outlined,
            title: 'Términos y condiciones',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openUrl(context, ApiConstants.termsPdf),
          ),
          MenuItem(
            icon: Icons.published_with_changes_outlined,
            title: 'Cambios y devoluciones',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openUrl(context, ApiConstants.returnsPdf),
          ),
          MenuItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openUrl(context, ApiConstants.privacyPdf),
          ),
        ]),
        if (info != null && info.social.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.defaultPadding, 16, AppConstants.defaultPadding, 0,
            ),
            child: Column(
              children: [
                Text('Síguenos', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final entry in info.social.entries)
                      IconButton.filledTonal(
                        tooltip: entry.key.name,
                        onPressed: () => openUrl(context, entry.value),
                        icon: FaIcon(_icon(entry.key), size: 18),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (info != null && info.paymentMethods.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.defaultPadding, 20, AppConstants.defaultPadding, 0,
            ),
            child: Column(
              children: [
                Text('Medios de pago', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in info.paymentMethods)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE6E6E9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: m.imageUrl == null
                            ? Text(m.name)
                            : Image.network(
                                m.imageUrl!,
                                height: 28,
                                errorBuilder: (_, _, _) => Text(m.name),
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Tarjeta de portada con el logo y los datos básicos de la empresa.
class _BrandCard extends StatelessWidget {
  final CompanyInfoEntity? info;
  final Color color;

  const _BrandCard({required this.info, required this.color});

  @override
  Widget build(BuildContext context) {
    final onColor = ColorUtils.onColor(color);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(AppConstants.defaultPadding),
      padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.25),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          BrandLogo(url: info?.logoUrl, height: 48),
          const SizedBox(height: 10),
          Text(
            'Audio automotriz, multimedia, seguridad y energía para tu vehículo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: onColor.withValues(alpha: 0.85)),
          ),
          if (info?.email != null || info?.address != null) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                if (info?.address != null)
                  _Fact(Icons.location_on_outlined, info!.address!, onColor),
                if (info?.email != null)
                  _Fact(Icons.mail_outline, info!.email!, onColor),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Fact(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color.withValues(alpha: 0.85))),
      ],
    );
  }
}
