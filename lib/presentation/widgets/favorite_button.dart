import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/product_entity.dart';
import '../components/components.dart';
import '../pages/login_page.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

/// Corazón para guardar un producto en "Mis listas". Sin sesión pide iniciarla.
class FavoriteButton extends StatelessWidget {
  final ProductEntity product;

  const FavoriteButton({super.key, required this.product});

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
        adding ? 'Guardado en mis listas' : 'Quitado de mis listas',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = context
        .select<FavoritesProvider, bool>((f) => f.isFavorite(product.id));

    return IconButton(
      tooltip: isFavorite ? 'Quitar de mis listas' : 'Guardar en mis listas',
      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
      onPressed: () => _toggle(context),
    );
  }
}
