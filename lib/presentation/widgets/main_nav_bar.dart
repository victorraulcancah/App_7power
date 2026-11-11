import 'package:flutter/material.dart';

/// Una pestaña de [MainNavBar].
class MainNavTab {
  /// El nombre que se ve bajo el ícono.
  final String label;

  /// Lo que dice al mantener pulsado y a los lectores de pantalla.
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

/// La barra de abajo: una píldora oscura flotante sobre el fondo blanco, con el
/// ícono y el nombre de cada pestaña. La pestaña elegida lleva un cuadro rojo
/// con brillo.
class MainNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const MainNavBar({super.key, required this.selectedIndex, required this.onSelected});

  static const _pill = Color(0xFF0B0B0C);
  static const _pillBorder = Color(0xFF2B2B2E);
  static const _glow = Color(0xFFE02424);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Container(
            height: 72,
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
              width: 62,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4A0A0A), Color(0xFF9B1111)],
                      )
                    : null,
                border: selected
                    ? Border.all(color: MainNavBar._glow, width: 1.4)
                    : null,
                boxShadow: selected
                    ? const [BoxShadow(color: Color(0x66E02424), blurRadius: 14)]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, color: Colors.white, size: 26),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
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
