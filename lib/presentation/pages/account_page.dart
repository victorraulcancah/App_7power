import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/user_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import 'cart_page.dart';
import 'login_page.dart';

/// Pestaña "Cuenta": inicio de sesión o perfil del cliente.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.initial) return const LoadingIndicator();
    if (!auth.isAuthenticated) return const LoginForm();

    return _Profile(user: auth.user!);
  }
}

class _Profile extends StatelessWidget {
  final UserEntity user;

  const _Profile({required this.user});

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed == true) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null ? Text(user.initials) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: theme.textTheme.titleMedium),
                  Text(user.email, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  StatusTag(
                    label: user.emailVerified
                        ? 'Correo verificado'
                        : 'Correo sin verificar',
                    type: user.emailVerified
                        ? StatusTagType.success
                        : StatusTagType.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (user.documentNumber != null)
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(user.documentType ?? 'Documento'),
            subtitle: Text(user.documentNumber!),
          ),
        if (user.phone != null)
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Teléfono'),
            subtitle: Text(user.phone!),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.shopping_cart_outlined),
          title: const Text('Mi carrito'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CartPage())),
        ),
        ListTile(
          leading: Icon(Icons.logout, color: theme.colorScheme.error),
          title: Text('Cerrar sesión',
              style: TextStyle(color: theme.colorScheme.error)),
          onTap: () => _logout(context),
        ),
      ],
    );
  }
}
