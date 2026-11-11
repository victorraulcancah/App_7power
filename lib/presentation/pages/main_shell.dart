import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/product_filters.dart';
import '../components/components.dart';
import '../providers/products_provider.dart';
import '../widgets/home_header.dart';
import 'account_page.dart';
import 'cart_page.dart';
import 'categories_page.dart';
import 'home_page.dart';
import 'more_page.dart';
import 'products_page.dart';
import 'search_page.dart';

/// Estructura principal: barra superior con el logo, contenido por pestañas y
/// navegación inferior (Inicio, Tienda, Categorías, Cuenta y Más).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final ValueNotifier<int?> _tabRequest = ValueNotifier<int?>(null);

  /// Pide que la pantalla principal cambie de pestaña (0 inicio, 1 tienda,
  /// 2 categorías, 3 cuenta, 4 más); por ejemplo, desde la pantalla de compra
  /// realizada.
  static void requestTab(int tab) => _tabRequest.value = tab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _homeTab = 0;
  static const int _shopTab = 1;
  static const int _categoriesTab = 2;
  static const int _accountTab = 3;

  int _tab = _homeTab;

  @override
  void initState() {
    super.initState();
    MainShell._tabRequest.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    MainShell._tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final tab = MainShell._tabRequest.value;
    if (tab == null) return;
    MainShell._tabRequest.value = null;
    setState(() => _tab = tab);
  }

  void _openShop({int? categoryId}) {
    context.read<ProductsProvider>().selectCategory(categoryId);
    setState(() => _tab = _shopTab);
  }

  /// La tienda con los resultados de lo buscado en el inicio.
  void _openSearch(String query, int? categoryId) {
    context
        .read<ProductsProvider>()
        .searchEverywhere(query, categoryId: categoryId);
    setState(() => _tab = _shopTab);
  }

  /// La tienda con solo esa marca (sin categoría ni otros filtros de antes).
  void _openBrand(BrandEntity brand) {
    final products = context.read<ProductsProvider>();
    products.selectCategory(null);
    products.applyFilters(ProductFilters(brandIds: {brand.id}));
    setState(() => _tab = _shopTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La tienda no lleva barra: su buscador, el filtro y el carrito van en la
      // primera fila de la pantalla (ver `ProductsPage`).
      appBar: _tab == _shopTab
          ? null
          : _tab == _categoriesTab
          // Categorías: barra clara con el título, la búsqueda y el carrito.
          ? AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF26262B),
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE6E6EA))),
              title: const Text('Categorías'),
              actions: [
                IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      SearchPage.open(context, onSubmit: _openSearch),
                ),
                const CartButton(plain: true),
                const SizedBox(width: 4),
              ],
            )
          : _tab == 0
          // El inicio no lleva logo: el buscador ocupa la barra, con la lista
          // de favoritos, el carrito y la ayuda a su lado.
          ? AppBar(
              // Barra clara, como el ejemplo: buscador de borde gris e íconos
              // oscuros sobre blanco, con una línea fina debajo.
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF26262B),
              surfaceTintColor: Colors.transparent,
              // La hora y la batería del teléfono, en oscuro sobre el blanco.
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE6E6EA))),
              centerTitle: false,
              titleSpacing: 10,
              title: SizedBox(
                width: double.infinity,
                child: HomeSearchField(onSearch: _openSearch),
              ),
              // Íconos sueltos y angostos: así al buscador le queda el ancho.
              actions: const [
                FavoritesShortcut(),
                CartButton(plain: true),
                SizedBox(width: 4),
              ],
            )
          // Cuenta y Más: barra clara con el título y el carrito pequeño, sin
          // logo ni WhatsApp.
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF26262B),
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              shape: const Border(bottom: BorderSide(color: Color(0xFFE6E6EA))),
              title: Text(_tab == _accountTab ? 'Cuenta' : 'Más'),
              actions: const [CartButton(plain: true), SizedBox(width: 4)],
            ),
      // Sin barra en la tienda, la hora y la batería del teléfono van en oscuro
      // sobre el blanco.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: _TabFade(
          index: _tab,
          child: IndexedStack(
            index: _tab,
            children: [
              HomePage(onOpenShop: _openShop, onOpenBrand: _openBrand),
              const ProductsPage(),
              CategoriesPage(onOpenShop: _openShop),
              const AccountPage(),
              MorePage(onOpenBrand: _openBrand),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        // Solo íconos: el nombre queda como descripción (mantener pulsado) y
        // para los lectores de pantalla.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        height: 60,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Tienda',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category_rounded),
            label: 'Categorías',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cuenta',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            selectedIcon: Icon(Icons.menu_rounded),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}

/// Al cambiar de pestaña el contenido nuevo aparece con un desvanecido y un leve
/// deslizamiento, en lugar de cambiar de golpe. Las pestañas siguen vivas (no
/// se reconstruyen): solo se anima su aparición.
class _TabFade extends StatefulWidget {
  final int index;
  final Widget child;

  const _TabFade({required this.index, required this.child});

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index &&
        FadeSlideIn.enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_curve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
