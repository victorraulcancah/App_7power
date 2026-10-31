import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/product_entity.dart';
import '../components/components.dart';
import '../pages/login_page.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

/// Corazón para guardar un producto en "Favoritos". Sin sesión pide iniciarla.
///
/// Con [compact] es un círculo blanco chico, para ir sobre la imagen de una
/// tarjeta de producto.
class FavoriteButton extends StatelessWidget {
  final ProductEntity product;
  final bool compact;

  const FavoriteButton({super.key, required this.product, this.compact = false});

  Future<void> _toggle(BuildContext context) async {
    final loggedIn = context.read<AuthProvider>().isAuthenticated;
    if (!loggedIn) {
      AppSnackbar.info(context, 'Inicia sesión para guardar tus favoritos.');
      await LoginPage.open(context);
      return;
    }

    final favorites = context.read<FavoritesProvider>();
    final adding = !favorites.isFavorite(product.id);
    final error = await favorites.toggle(product);

    if (!context.mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      AppSnackbar.success(
        context,
        adding ? 'Guardado en favoritos' : 'Quitado de favoritos',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = context
        .select<FavoritesProvider, bool>((f) => f.isFavorite(product.id));
    final theme = Theme.of(context);
    final tooltip = isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos';
    final icon = Icon(isFavorite ? Icons.favorite : Icons.favorite_border);

    if (!compact) {
      return IconButton(
        tooltip: tooltip,
        icon: icon,
        onPressed: () => _toggle(context),
      );
    }

    return IconButton.filled(
      tooltip: tooltip,
      icon: icon,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        foregroundColor:
            isFavorite ? theme.colorScheme.error : const Color(0xFF26262B),
      ),
      onPressed: () => _toggle(context),
    );
  }
}
