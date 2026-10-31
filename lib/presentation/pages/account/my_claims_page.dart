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
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  itemCount: info.claims.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    claim.number,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                StatusTag(
                  label: claimStatusLabel(claim.status),
                  type: claimStatusTagType(claim.status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (type.isNotEmpty) type,
                if (claim.createdAt != null) FormatUtils.date(claim.createdAt!),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            if (claim.productName != null) ...[
              const SizedBox(height: 8),
              Text(
                claim.productName!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            if (claim.detail != null) ...[
              const SizedBox(height: 4),
              Text(
                claim.detail!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (!answered && claim.deadline != null) ...[
              const SizedBox(height: 8),
              Text(
                'Respuesta hasta el ${FormatUtils.date(claim.deadline!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (answered) ...[
              const Divider(height: 24),
              Text('Respuesta de la empresa', style: theme.textTheme.titleSmall),
              if (claim.responseDate != null)
                Text(
                  FormatUtils.date(claim.responseDate!),
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 4),
              Text(claim.response!),
            ],
          ],
        ),
      ),
    );
  }
}
