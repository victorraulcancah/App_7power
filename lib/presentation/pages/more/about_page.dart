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
                ProductImage(
                  url: info.about!.imageUrl,
                  fit: BoxFit.cover,
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
              if (info.about!.description != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(info.about!.description!,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                ),
              for (final value in info.about!.values)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (value.imageUrl != null)
                        ProductImage(url: value.imageUrl, height: 150),
                      Padding(
                        padding: const EdgeInsets.all(AppConstants.defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(value.title,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(value.description,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(height: 1.45)),
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
