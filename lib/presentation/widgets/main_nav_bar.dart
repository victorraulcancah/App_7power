import 'package:flutter/material.dart';

/// Una pestaña de [MainNavBar].
class MainNavTab {
  /// El nombre que se ve bajo el ícono.
  final String label;

  /// Lo que dice a los lectores de pantalla (y a las pruebas).
  final String tooltip;
  final IconData icon;

  const MainNavTab({
    required this.label,
    required this.tooltip,
    required this.icon,
  });
}

/// Las pestañas del app, en orden.
const mainNavTabs = [
  MainNavTab(label: 'Inicio', tooltip: 'Inicio', icon: Icons.home_outlined),
  MainNavTab(label: 'Tienda', tooltip: 'Tienda', icon: Icons.storefront_outlined),
  MainNavTab(label: 'Categorías', tooltip: 'Categorías', icon: Icons.grid_view_outlined),
  MainNavTab(label: 'Mi Cuenta', tooltip: 'Cuenta', icon: Icons.person_outline_rounded),
  MainNavTab(label: 'Más', tooltip: 'Más', icon: Icons.more_horiz_rounded),
];

/// La barra de abajo: fondo blanco, íconos y nombres en gris. La pestaña elegida
/// lleva un cuadro rosado suave, con su ícono y su nombre en rojo.
class MainNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const MainNavBar({super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE6E6EA))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < mainNavTabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      tab: mainNavTabs[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El gris de las pestañas que no están elegidas.
const _gray = Color(0xFF6B6B73);

class _NavItem extends StatelessWidget {
  final MainNavTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final primary = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: tab.tooltip,
      // Sin globo de texto al tocar o mantener pulsado: el nombre ya se ve.
      triggerMode: TooltipTriggerMode.manual,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: still ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 70,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // Rosado suave, como los cuadros de los íconos de los menús.
                color: selected ? primary.withValues(alpha: 0.12) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, color: selected ? primary : _gray, size: 26),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected ? primary : _gray,
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
