import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/user_entity.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/statement_provider.dart';
import 'account/addresses_page.dart';
import 'account/favorites_page.dart';
import 'account/my_claims_page.dart';
import 'account/personal_data_page.dart';
import 'account/statement_page.dart';
import 'account/purchases_page.dart';
import 'account/quotes_page.dart';
import 'cart_page.dart';
import 'login_page.dart';
import 'more/about_page.dart';
import 'more/claim_book_page.dart';
import 'more/contact_page.dart';

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

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Header(user: user),
        // Accesos rápidos: lo que más se consulta.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.defaultPadding, 16, AppConstants.defaultPadding, 8,
          ),
          child: Row(
            children: [
              _Quick(
                icon: Icons.receipt_long_outlined,
                label: 'Compras',
                onTap: () => _open(context, const PurchasesPage()),
              ),
              const SizedBox(width: 12),
              _Quick(
                icon: Icons.description_outlined,
                label: 'Cotizaciones',
                onTap: () => _open(context, const QuotesPage()),
              ),
              const SizedBox(width: 12),
              _Quick(
                icon: Icons.favorite_border,
                label: 'Mis listas',
                onTap: () => _open(context, const FavoritesPage()),
              ),
            ],
          ),
        ),
        MenuGroup(title: 'Mi cuenta', children: [
          MenuItem(
            icon: Icons.person_outline,
            title: 'Datos personales',
            onTap: () => _open(context, const PersonalDataPage()),
          ),
          MenuItem(
            icon: Icons.location_on_outlined,
            title: 'Direcciones',
            onTap: () => _open(context, const AddressesPage()),
          ),
          if (context.select<StatementProvider, bool>((s) => s.available))
            MenuItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Estado de cuenta',
              onTap: () => _open(context, const StatementPage()),
            ),
          MenuItem(
            icon: Icons.menu_book_outlined,
            title: 'Mis reclamos',
            onTap: () => _open(context, const MyClaimsPage()),
          ),
          MenuItem(
            icon: Icons.shopping_cart_outlined,
            title: 'Mi carrito',
            onTap: () => _open(context, const CartPage()),
          ),
        ]),
        MenuGroup(title: 'Ayuda', children: [
          MenuItem(
            icon: Icons.menu_book_outlined,
            title: 'Libro de reclamaciones',
            onTap: () => _open(context, const ClaimBookPage()),
          ),
          MenuItem(
            icon: Icons.support_agent_outlined,
            title: 'Contáctanos',
            onTap: () => _open(context, const ContactPage()),
          ),
          MenuItem(
            icon: Icons.business_outlined,
            title: 'Sobre nosotros',
            onTap: () => _open(context, const AboutPage()),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.defaultPadding, 16, AppConstants.defaultPadding, 0,
          ),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
            ),
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ),
      ],
    );
  }
}

/// Cabecera con el color de la marca, esquinas inferiores redondeadas y los
/// datos del cliente.
class _Header extends StatelessWidget {
  final UserEntity user;

  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppConstants.defaultPadding * 1.25, 8,
        AppConstants.defaultPadding * 1.25, 24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: onPrimary,
            foregroundColor: theme.colorScheme.primary,
            foregroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            // Si la foto no carga se ven las iniciales.
            onForegroundImageError: user.photoUrl != null ? (_, _) {} : null,
            child: Text(user.initials,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: onPrimary.withValues(alpha: 0.85)),
                ),
                if (user.erpCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Cuenta vinculada · ${user.erpCode}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: onPrimary),
                      ),
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

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Quick({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(height: 6),
                Text(label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
