import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../components/components.dart';
import '../../providers/info_provider.dart';
import '../../providers/load_status.dart';

/// "Sobre nosotros": quiénes son, misión, visión y valores.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

/// Ícono de cada sección según su título (Misión, Visión, Valores...).
IconData _iconFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('misi')) return Icons.flag_outlined;
  if (t.contains('visi')) return Icons.visibility_outlined;
  if (t.contains('valor')) return Icons.favorite_border;
  return Icons.star_border;
}

/// Imagen a todo el ancho y completa: el alto sale de su proporción, así no se
/// recorta (con alto fijo se cortaba, o no llenaba la tarjeta).
class _Picture extends StatelessWidget {
  final String url;
  final bool rounded;

  const _Picture({required this.url, this.rounded = false});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // Alto mínimo mientras carga, para que la pantalla no salte.
      constraints: const BoxConstraints(minHeight: 160),
      child: ProductImage(
        url: url,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        borderRadius: rounded
            ? BorderRadius.circular(AppConstants.defaultBorderRadius)
            : null,
      ),
    );
  }
}

class _AboutPageState extends State<AboutPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InfoProvider>().loadAbout();
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = context.watch<InfoProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sobre nosotros')),
      body: switch (info.aboutStatus) {
        LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
        LoadStatus.error => ErrorState(
            message: info.aboutError,
            onRetry: info.loadAbout,
          ),
        LoadStatus.loaded => ListView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            children: [
              if (info.about!.imageUrl != null)
                _Picture(url: info.about!.imageUrl!, rounded: true),
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 8),
                child: Text(
                  'Quiénes somos',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (info.about!.description != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    info.about!.description!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                      fontSize: 15,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              for (final value in info.about!.values)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (value.imageUrl != null) _Picture(url: value.imageUrl!),
                      Padding(
                        padding: const EdgeInsets.all(AppConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.10),
                                  foregroundColor: theme.colorScheme.primary,
                                  child: Icon(_iconFor(value.title), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    value.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              value.description,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      },
    );
  }
}
