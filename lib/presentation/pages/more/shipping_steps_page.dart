import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../components/components.dart';
import '../../providers/info_provider.dart';
import '../../providers/load_status.dart';

/// "¿Cómo funciona el envío?": los pasos desde el pedido hasta la entrega.
class ShippingStepsPage extends StatefulWidget {
  const ShippingStepsPage({super.key});

  @override
  State<ShippingStepsPage> createState() => _ShippingStepsPageState();
}

class _ShippingStepsPageState extends State<ShippingStepsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InfoProvider>().loadSteps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = context.watch<InfoProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cómo funciona el envío')),
      body: switch (info.stepsStatus) {
        LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
        LoadStatus.error => ErrorState(
            message: info.stepsError,
            onRetry: info.loadSteps,
          ),
        LoadStatus.loaded => info.steps.isEmpty
            ? const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'Sin información por ahora',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                itemCount: info.steps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final step = info.steps[i];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        if (step.imageUrl != null)
                          ProductImage(url: step.imageUrl, width: 96, height: 96),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Paso ${i + 1}',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    )),
                                Text(step.title,
                                    style: theme.textTheme.titleSmall),
                                if (step.description != null)
                                  Text(step.description!,
                                      style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      },
    );
  }
}
