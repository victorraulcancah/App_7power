import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/components.dart';
import '../providers/company_provider.dart';
import '../providers/products_provider.dart';
import 'account_page.dart';
import 'cart_page.dart';
import 'home_page.dart';
import 'more_page.dart';
import 'products_page.dart';

/// Estructura principal: barra superior con el logo, contenido por pestañas y
/// navegación inferior (Inicio, Tienda, Cuenta y Más).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _homeTab = 0;
  static const int _shopTab = 1;

  int _tab = _homeTab;

  void _openShop({int? categoryId}) {
    context.read<ProductsProvider>().selectCategory(categoryId);
    setState(() => _tab = _shopTab);
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CompanyProvider>().info;

    return Scaffold(
      appBar: AppBar(
        actions: const [CartButton()],
        // El logo queda centrado; el carrito, a la derecha.
        title: BrandLogo(url: company?.logoUrl, height: 34),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          HomePage(onOpenShop: _openShop),
          const ProductsPage(),
          const AccountPage(),
          const MorePage(),
        ],
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
