import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/company_info_entity.dart';
import '../../domain/entities/product_filters.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';
import '../utils/open_url.dart';
import 'account/my_claims_page.dart';
import 'brands_page.dart';
import 'more/about_page.dart';
import 'more/claim_book_page.dart';
import 'more/contact_page.dart';
import 'more/shipping_steps_page.dart';
import 'promotions/coupons_page.dart';
import 'promotions/offers_page.dart';
import 'support/support_page.dart';

/// Pestaña "Más": información de la empresa, atención al cliente y legal.
class MorePage extends StatelessWidget {
  /// Se llama al elegir una marca en "Marcas": abre la tienda con ese filtro.
  final ValueChanged<BrandEntity> onOpenBrand;

  const MorePage({super.key, required this.onOpenBrand});

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
        _BrandCard(info: info),
        MenuGroup(title: 'Compra en 7power', children: [
          MenuItem(
            icon: Icons.local_fire_department_outlined,
            title: 'Ofertas',
            subtitle: 'Productos con descuento',
            onTap: () => _open(context, const OffersPage()),
          ),
          MenuItem(
            icon: Icons.local_offer_outlined,
            title: 'Cupones',
            subtitle: 'Códigos de descuento vigentes',
            onTap: () => _open(context, const CouponsPage()),
          ),
          MenuItem(
            icon: Icons.verified_outlined,
            title: 'Marcas',
            subtitle: 'Explora el catálogo por marca',
            onTap: () => _open(context, BrandsPage(onSelected: onOpenBrand)),
          ),
        ]),
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
            icon: Icons.help_outline_rounded,
            title: 'Ayuda y preguntas frecuentes',
            subtitle: 'Habla con un asesor por WhatsApp',
            onTap: () => _open(context, const SupportPage()),
          ),
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
          // Los reclamos del cliente: solo con sesión iniciada.
          if (context.select<AuthProvider, bool>((a) => a.isAuthenticated))
            MenuItem(
              icon: Icons.menu_book_outlined,
              title: 'Mis reclamos',
              subtitle: 'Los que registraste con tu cuenta',
              onTap: () => _open(context, const MyClaimsPage()),
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
                            : ProductImage(
                                url: m.imageUrl,
                                height: 28,
                                fit: BoxFit.contain,
                                showSpinner: false,
                                fallback: Text(m.name),
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

/// Portada de "Más": fondo oscuro con destellos rojos, el eslogan, el 7 grande y
/// las tres ventajas de la marca. Debajo, la dirección y el correo.
class _BrandCard extends StatelessWidget {
  final CompanyInfoEntity? info;

  const _BrandCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const red = Color(0xFFE02424);

    Widget feature(IconData icon, Color color, String text) => Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget divider() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white24,
    );

    return Container(
      margin: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 14),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              image: const DecorationImage(
                image: AssetImage('assets/images/top_bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Audio automotriz, multimedia, seguridad y energía para tu vehículo.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(width: 56, height: 3, color: red),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Image.asset(
                        'assets/images/seven.png',
                        height: 112,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    feature(Icons.verified_user_outlined, red, 'Calidad\ngarantizada'),
                    divider(),
                    feature(Icons.local_shipping_outlined, Colors.white, 'Envíos a\ntodo el Perú'),
                    divider(),
                    feature(Icons.handshake_outlined, Colors.white, 'Tu mejor aliado\nautomotriz'),
                  ],
                ),
              ],
            ),
          ),
          if (info?.email != null || info?.address != null) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                if (info?.address != null)
                  _Fact(Icons.location_on_outlined, info!.address!, theme.colorScheme.outline),
                if (info?.email != null)
                  _Fact(Icons.mail_outline, info!.email!, theme.colorScheme.outline),
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
