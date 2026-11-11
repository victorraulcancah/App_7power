import 'package:flutter/material.dart';

/// Una pestaña de [MainNavBar].
class MainNavTab {
  /// El nombre de la pestaña (no se dibuja: es para quien usa lector de pantalla).
  final String label;
  final String tooltip;
  final IconData icon;

  const MainNavTab({required this.label, required this.tooltip, required this.icon});
}

/// Las pestañas del app, en orden.
const mainNavTabs = [
  MainNavTab(label: 'Inicio', tooltip: 'Inicio', icon: Icons.home_outlined),
  MainNavTab(label: 'Tienda', tooltip: 'Tienda', icon: Icons.storefront_outlined),
  MainNavTab(label: 'Categorías', tooltip: 'Categorías', icon: Icons.grid_view_outlined),
  MainNavTab(label: 'Mi Cuenta', tooltip: 'Cuenta', icon: Icons.person_outline_rounded),
  MainNavTab(label: 'Más', tooltip: 'Más', icon: Icons.more_horiz_rounded),
];

/// La barra de abajo: una píldora oscura flotante sobre el fondo blanco, solo
/// con los íconos. La pestaña elegida lleva un cuadro con degradado de rojo a
/// negro y borde brillante.
class MainNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const MainNavBar({super.key, required this.selectedIndex, required this.onSelected});

  static const _pill = Color(0xFF0B0B0C);
  static const _pillBorder = Color(0xFF2B2B2E);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: _pill,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _pillBorder),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4)),
              ],
            ),
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

class _NavItem extends StatelessWidget {
  final MainNavTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Tooltip(
      message: tab.tooltip,
      // Sin globo de texto al tocar o mantener pulsado.
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
              width: 68,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                // De rojo vivo en la esquina a casi negro al otro lado.
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFC81E1E), Color(0xFF560A0A), Color(0xFF100505)],
                        stops: [0.0, 0.55, 1.0],
                      )
                    : null,
                border: selected
                    ? Border.all(color: const Color(0xFFFF3B30), width: 1.2)
                    : null,
                boxShadow: selected
                    ? const [
                        BoxShadow(color: Color(0x66E02424), blurRadius: 16),
                        BoxShadow(color: Color(0x33FF3B30), blurRadius: 6),
                      ]
                    : null,
              ),
              // Solo el ícono: el nombre queda como descripción para los lectores
              // de pantalla.
              child: Icon(tab.icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
