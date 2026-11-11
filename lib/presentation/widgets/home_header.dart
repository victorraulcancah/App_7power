import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/components.dart';
import '../pages/account/favorites_page.dart';
import '../pages/login_page.dart';
import '../pages/search_page.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

/// Buscador de la barra superior del inicio. Es un campo que, al tocarlo, abre
/// el buscador a pantalla completa (con selector de categoría y sugerencias,
/// como el de la web). Es bajo porque comparte la barra con los atajos a
/// favoritos y carrito.
class HomeSearchField extends StatelessWidget {
  /// Abre la tienda con los resultados de lo que se buscó.
  final void Function(String query, int? categoryId) onSearch;

  const HomeSearchField({super.key, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return SearchBox(
      flat: true,
      child: TextField(
        key: const Key('home-search'),
        // No se escribe aquí: al tocarlo se abre el buscador.
        readOnly: true,
        showCursor: false,
        onTap: () => SearchPage.open(context, onSubmit: onSearch),
        style: const TextStyle(fontSize: 14),
        decoration: SearchBox.decoration(
          context,
          hint: 'Buscar productos, marcas o códigos',
          compact: true,
        ),
      ),
    );
  }
}

/// Atajo a la lista de favoritos para la barra superior. Sin sesión pide
/// iniciarla.
class FavoritesShortcut extends StatelessWidget {
  const FavoritesShortcut({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select<FavoritesProvider, int>((f) => f.items.length);

    return IconButton(
      tooltip: 'Favoritos',
      // Más chico y sin el relleno de siempre: así el buscador tiene más ancho.
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
      onPressed: () {
        if (!context.read<AuthProvider>().isAuthenticated) {
          AppSnackbar.info(context, 'Inicia sesión para ver tus favoritos.');
          LoginPage.open(context);
          return;
        }
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
      },
      // Toma el color de la barra (claro sobre el fondo negro).
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: const Color(0xFFFFC107),
        textColor: Colors.black,
        label: Text('$count'),
        child: const Icon(Icons.favorite_border, size: 22),
      ),
    );
  }
}
