import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/user_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import 'account/addresses_page.dart';
import 'account/favorites_page.dart';
import 'account/personal_data_page.dart';
import 'account/purchases_page.dart';
import 'account/quotes_page.dart';
import 'cart_page.dart';
import 'login_page.dart';

/// Pestaña "Cuenta": inicio de sesión, o el menú de la cuenta del cliente.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.initial) return const LoadingIndicator();
    if (!auth.isAuthenticated) return const LoginForm();

    return _AccountMenu(user: auth.user!);
  }
}

class _AccountMenu extends StatelessWidget {
  final UserEntity user;

  const _AccountMenu({required this.user});

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

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget tile(IconData icon, String title, Widget page, {String? subtitle}) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, page),
        );

    return ListView(
      children: [
        _Header(user: user),
        const SizedBox(height: 8),
        tile(Icons.person_outline, 'Datos personales', const PersonalDataPage()),
        tile(Icons.location_on_outlined, 'Direcciones', const AddressesPage()),
        tile(Icons.description_outlined, 'Mis cotizaciones', const QuotesPage()),
        tile(Icons.receipt_long_outlined, 'Mis compras', const PurchasesPage()),
        tile(Icons.favorite_border, 'Mis listas', const FavoritesPage()),
        tile(Icons.shopping_cart_outlined, 'Mi carrito', const CartPage()),
        const Divider(height: 32),
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

class _Header extends StatelessWidget {
  final UserEntity user;

  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.primary,
      padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: theme.colorScheme.onPrimary,
            foregroundColor: theme.colorScheme.primary,
            foregroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            // Si la foto no carga se ven las iniciales.
            onForegroundImageError: user.photoUrl != null ? (_, _) {} : null,
            child: Text(user.initials,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${user.firstNames ?? user.fullName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.onPrimary),
                ),
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
                if (user.erpCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Cuenta vinculada · ${user.erpCode}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
