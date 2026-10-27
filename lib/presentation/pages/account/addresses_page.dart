import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/address_entity.dart';
import '../../components/components.dart';
import '../../providers/addresses_provider.dart';
import '../../providers/load_status.dart';
import 'address_form_page.dart';

/// "Direcciones": las de entrega del cliente.
class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressesProvider>().load();
    });
  }

  Future<void> _delete(AddressEntity address) async {
    final addresses = context.read<AddressesProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar dirección'),
        content: Text('¿Eliminar "${address.fullAddress}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await addresses.delete(address.id);
    if (!mounted) return;
    if (error != null) AppSnackbar.error(context, error);
  }

  Future<void> _setDefault(AddressEntity address) async {
    final error =
        await context.read<AddressesProvider>().setDefault(address.id);
    if (!mounted) return;
    if (error != null) AppSnackbar.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final addresses = context.watch<AddressesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Direcciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddressFormPage.open(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nueva dirección'),
      ),
      body: switch (addresses.status) {
        LoadStatus.initial || LoadStatus.loading => const LoadingIndicator(),
        LoadStatus.error => ErrorState(
            message: addresses.errorMessage,
            onRetry: addresses.load,
          ),
        LoadStatus.loaded => addresses.items.isEmpty
            ? const EmptyState(
                icon: Icons.location_off_outlined,
                title: 'Aún no tienes direcciones',
                message: 'Agrega una para recibir tus pedidos.',
              )
            : RefreshIndicator(
                onRefresh: addresses.load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.defaultPadding,
                    AppConstants.defaultPadding,
                    AppConstants.defaultPadding,
                    96,
                  ),
                  itemCount: addresses.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = addresses.items[i];
                    return _AddressCard(
                      address: a,
                      onEdit: () => AddressFormPage.open(context, address: a),
                      onDelete: () => _delete(a),
                      onSetDefault: () => _setDefault(a),
                    );
                  },
                ),
              ),
      },
    );
  }
}

class _AddressCard extends StatelessWidget {
  final AddressEntity address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(address.recipient,
                      style: theme.textTheme.titleSmall),
                ),
                if (address.isDefault)
                  const StatusTag(
                    label: 'Predeterminada',
                    type: StatusTagType.success,
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            Text(address.fullAddress),
            if (address.location.isNotEmpty)
              Text(address.location,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            if (address.reference != null)
              Text('Indicaciones: ${address.reference}',
                  style: theme.textTheme.bodySmall),
            if (!address.isDefault)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onSetDefault,
                  child: const Text('Establecer predeterminada'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
