import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/company_info_entity.dart';
import '../../../domain/entities/info_entity.dart';
import '../../components/components.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/info_provider.dart';
import '../../utils/open_url.dart';

/// "Contáctanos": datos de la empresa y un formulario para escribirles.
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Con sesión, los datos del cliente ya vienen llenos.
    final user = context.read<AuthProvider>().user;
    _name.text = user?.fullName ?? '';
    _email.text = user?.email ?? '';
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final info = context.read<InfoProvider>();

    setState(() => _sending = true);
    final error = await info.sendContact(ContactMessage(
      name: _name.text,
      email: _email.text,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      subject: _subject.text,
      message: _message.text,
    ));
    if (!mounted) return;
    setState(() => _sending = false);

    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    _subject.clear();
    _message.clear();
    AppSnackbar.success(context, 'Mensaje enviado. Te responderemos pronto.');
  }

  static FaIconData _icon(SocialNetwork network) => switch (network) {
        SocialNetwork.facebook => FontAwesomeIcons.facebookF,
        SocialNetwork.instagram => FontAwesomeIcons.instagram,
        SocialNetwork.twitter => FontAwesomeIcons.xTwitter,
        SocialNetwork.youtube => FontAwesomeIcons.youtube,
        SocialNetwork.tiktok => FontAwesomeIcons.tiktok,
        SocialNetwork.whatsapp => FontAwesomeIcons.whatsapp,
      };

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CompanyProvider>().info;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Contáctanos')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.defaultPadding),
        children: [
          if (company != null)
            MenuGroup(children: [
              if (company.address != null)
                MenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Dirección',
                  subtitle: company.address,
                  trailing: const SizedBox.shrink(),
                  onTap: () => openUrl(
                    context,
                    'https://www.google.com/maps/search/'
                    '${Uri.encodeComponent(company.address!)}',
                  ),
                ),
              if (company.email != null)
                MenuItem(
                  icon: Icons.mail_outline,
                  title: 'Correo',
                  subtitle: company.email,
                  trailing: const SizedBox.shrink(),
                  onTap: () => openUrl(context, 'mailto:${company.email}'),
                ),
              if (company.phone != null)
                MenuItem(
                  icon: Icons.phone_outlined,
                  title: 'Teléfono',
                  subtitle: company.phone,
                  trailing: const SizedBox.shrink(),
                  onTap: () => openUrl(context, 'tel:${company.phone}'),
                ),
              if (company.mobile != null)
                MenuItem(
                  icon: Icons.smartphone_outlined,
                  title: 'Celular',
                  subtitle: company.mobile,
                  trailing: const SizedBox.shrink(),
                  onTap: () => openUrl(context, 'tel:${company.mobile}'),
                ),
              if (company.openingHours != null)
                MenuItem(
                  icon: Icons.schedule,
                  title: 'Horario de atención',
                  subtitle: company.openingHours,
                  trailing: const SizedBox.shrink(),
                  onTap: () {},
                ),
            ]),
          if (company != null && company.social.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultPadding,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Text('Síguenos', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 12),
                  for (final entry in company.social.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton.filledTonal(
                        tooltip: entry.key.name,
                        onPressed: () => openUrl(context, entry.value),
                        icon: FaIcon(_icon(entry.key), size: 16),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Escríbenos', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Nombre',
                    controller: _name,
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.required(v, 'tu nombre'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Correo electrónico',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Teléfono (opcional)',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Asunto',
                    controller: _subject,
                    prefixIcon: Icons.title,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.required(v, 'el asunto'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Mensaje',
                    controller: _message,
                    maxLines: 5,
                    validator: (v) {
                      final empty = Validators.required(v, 'tu mensaje');
                      if (empty != null) return empty;
                      return (v ?? '').length > 2000
                          ? 'Máximo 2000 caracteres'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Enviar mensaje',
                    icon: Icons.send_outlined,
                    isLoading: _sending,
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
