import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/product_filters.dart';
import '../components/components.dart';
import '../providers/company_provider.dart';
import '../providers/products_provider.dart';
import 'account_page.dart';
import 'cart_page.dart';
import 'home_page.dart';
import 'more_page.dart';
import 'products_page.dart';
import 'support/support_page.dart';

/// Estructura principal: barra superior con el logo, contenido por pestañas y
/// navegación inferior (Inicio, Tienda, Cuenta y Más).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static final ValueNotifier<int?> _tabRequest = ValueNotifier<int?>(null);

  /// Pide que la pantalla principal cambie de pestaña (0 inicio, 1 tienda,
  /// 2 cuenta, 3 más); por ejemplo, desde la pantalla de compra realizada.
  static void requestTab(int tab) => _tabRequest.value = tab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _homeTab = 0;
  static const int _shopTab = 1;

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
  void _openSearch(String query) {
    context.read<ProductsProvider>().searchEverywhere(query);
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
    final company = context.watch<CompanyProvider>().info;

    return Scaffold(
      appBar: AppBar(
        // Ayuda por WhatsApp a la mano en todas las pestañas, y el carrito.
        actions: const [SupportAction(), CartButton()],
        // El logo queda centrado; el carrito, a la derecha.
        title: BrandLogo(url: company?.logoUrl, height: 34),
      ),
      body: _TabFade(
        index: _tab,
        child: IndexedStack(
          index: _tab,
          children: [
            HomePage(
              onOpenShop: _openShop,
              onOpenBrand: _openBrand,
              onSearch: _openSearch,
            ),
            const ProductsPage(),
            const AccountPage(),
            MorePage(onOpenBrand: _openBrand),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
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

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

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
        position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}
