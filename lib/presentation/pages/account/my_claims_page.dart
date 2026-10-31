import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/entities/info_entity.dart';
import '../../components/components.dart';
import '../../providers/info_provider.dart';
import '../../providers/load_status.dart';
import '../more/claim_book_page.dart';

/// "Mis reclamos": los reclamos y quejas que el cliente registró en el libro de
/// reclamaciones, con su estado y la respuesta de la empresa.
class MyClaimsPage extends StatefulWidget {
  const MyClaimsPage({super.key});

  @override
  State<MyClaimsPage> createState() => _MyClaimsPageState();
}

class _MyClaimsPageState extends State<MyClaimsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InfoProvider>().loadClaims();
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = context.watch<InfoProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reclamos')),
      body: switch (info.claimsStatus) {
        LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
        LoadStatus.error => ErrorState(
            message: info.claimsError,
            onRetry: info.loadClaims,
          ),
        LoadStatus.loaded => info.claims.isEmpty
            ? EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Aún no tienes reclamos',
                message: 'Los que registres en el libro de reclamaciones '
                    'aparecerán aquí.',
                actionLabel: 'Ir al libro de reclamaciones',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClaimBookPage()),
                ),
              )
            : RefreshIndicator(
                onRefresh: info.loadClaims,
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: info.claims.length,
                  itemBuilder: (context, i) => _ClaimCard(claim: info.claims[i]),
                ),
              ),
      },
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final ClaimStatus claim;

  const _ClaimCard({required this.claim});

  static String _typeLabel(String? type) => switch (type) {
        'reclamo' => 'Reclamo',
        'queja' => 'Queja',
        final other => other ?? '',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = claim.response != null;
    final type = _typeLabel(claim.requestType);

    return DataCard(
      icon: Icons.menu_book_outlined,
      badge: claim.number,
      trailing: StatusTag(
        label: claimStatusLabel(claim.status),
        type: claimStatusTagType(claim.status),
      ),
      fields: [
        if (type.isNotEmpty) DataField('Tipo', type),
        if (claim.createdAt != null)
          DataField('Fecha', FormatUtils.date(claim.createdAt!)),
        if (claim.productName != null)
          DataField('Producto', claim.productName!, maxLines: 2, bold: true),
        if (claim.detail != null)
          DataField('Detalle', claim.detail!, maxLines: 3),
      ],
      children: [
        if (!answered && claim.deadline != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Respuesta hasta el ${FormatUtils.date(claim.deadline!)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        if (answered)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Respuesta de la empresa', style: theme.textTheme.titleSmall),
                if (claim.responseDate != null)
                  Text(
                    FormatUtils.date(claim.responseDate!),
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 4),
                Text(claim.response!),
              ],
            ),
          ),
      ],
    );
  }
}
