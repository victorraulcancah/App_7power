import 'package:flutter/material.dart';

/// Una pestaña de [MainNavBar].
class MainNavTab {
  /// El nombre que se ve bajo el ícono.
  final String label;

  /// Lo que dice al mantener pulsado y a los lectores de pantalla.
  final String tooltip;
  final IconData icon;
  final IconData selectedIcon;

  const MainNavTab({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Las pestañas del app, en orden.
const mainNavTabs = [
  MainNavTab(
    label: 'Inicio',
    tooltip: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  MainNavTab(
    label: 'Tienda',
    tooltip: 'Tienda',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
  ),
  MainNavTab(
    label: 'Categorías',
    tooltip: 'Categorías',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category_rounded,
  ),
  MainNavTab(
    label: 'Mi Cuenta',
    tooltip: 'Cuenta',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
  MainNavTab(
    label: 'Más',
    tooltip: 'Más',
    icon: Icons.menu_rounded,
    selectedIcon: Icons.menu_rounded,
  ),
];

/// La barra de abajo de siempre (fondo blanco, los mismos íconos y la pestaña
/// elegida con su óvalo), con el nombre de cada pestaña debajo del ícono.
class MainNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const MainNavBar({super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 68,
      onDestinationSelected: onSelected,
      destinations: [
        for (final tab in mainNavTabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
            tooltip: tab.tooltip,
          ),
      ],
    );
  }
}
