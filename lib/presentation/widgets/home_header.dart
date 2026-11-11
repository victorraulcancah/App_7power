import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/components.dart';
import '../pages/account/favorites_page.dart';
import '../pages/login_page.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

/// Buscador de la barra superior del inicio, como el de la web: al enviar el
/// texto se abre la tienda con los resultados (no busca mientras se escribe).
/// Es más bajo que el de la tienda porque comparte la barra con los atajos a
/// favoritos y carrito.
class HomeSearchField extends StatefulWidget {
  /// Abre la tienda con los resultados de lo que se buscó.
  final ValueChanged<String> onSearch;

  const HomeSearchField({super.key, required this.onSearch});

  @override
  State<HomeSearchField> createState() => _HomeSearchFieldState();
}

class _HomeSearchFieldState extends State<HomeSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    // Queda vacío para la próxima vez que se vuelva al inicio.
    _controller.clear();
    widget.onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    return SearchBox(
      flat: true,
      child: TextField(
        key: const Key('home-search'),
        controller: _controller,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        onSubmitted: (_) => _submit(),
        decoration: SearchBox.decoration(
          context,
          hint: 'Buscar productos',
          compact: true,
          suffix: SearchSubmitButton(onPressed: _submit, compact: true),
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
