import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/color_utils.dart';
import '../../domain/entities/promotion_entity.dart';
import 'product_image.dart';
import 'section_header.dart';

/// Un color "#RRGGBB" de la empresa, o [fallback] si no lo definió o no es válido.
Color _color(String? hex, Color fallback) => ColorUtils.parseHex(hex) ?? fallback;

// ---------------------------------------------------------------------------
// Ventas flash
// ---------------------------------------------------------------------------

/// "Ventas Flash": ofertas por tiempo limitado, cada una con su cuenta
/// regresiva. Las que ya terminaron no se muestran.
class FlashSalesSection extends StatelessWidget {
  final List<FlashSale> sales;
  final ValueChanged<FlashSale> onOpen;

  /// El reloj, para poder probarlo.
  final DateTime Function() now;

  const FlashSalesSection({
    super.key,
    required this.sales,
    required this.onOpen,
    this.now = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final active = sales.where((s) => s.isActive(now())).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Ventas Flash'),
        SizedBox(
          height: FlashSaleCard.height + 12,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.defaultPadding,
              vertical: 6,
            ),
            itemCount: active.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => FlashSaleCard(
              sale: active[i],
              now: now,
              onTap: () => onOpen(active[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de una venta flash: su imagen, el nombre, el tiempo que queda y el
/// botón.
class FlashSaleCard extends StatelessWidget {
  static const double height = 176;
  static const double width = 310;

  final FlashSale sale;
  final VoidCallback onTap;
  final DateTime Function() now;

  const FlashSaleCard({
    super.key,
    required this.sale,
    required this.onTap,
    this.now = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final radius = BorderRadius.circular(20);
    final buttonColor = _color(sale.buttonColor, primary);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: const Color(0xFF1B1B1F),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (sale.imageUrl != null) ProductImage(url: sale.imageUrl),
                // Oscurece de izquierda a derecha para que se lea el texto.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xE6000000), Color(0x66000000)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Badge(
                        icon: Icons.bolt_rounded,
                        label: sale.name,
                        color: _color(sale.badgeColor, primary),
                      ),
                      const Spacer(),
                      FlashCountdown(endsAt: sale.endsAt, now: now),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: ColorUtils.onColor(buttonColor),
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: Text(sale.buttonText ?? 'Ver oferta'),
                      ),
                    ],
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

/// Cuenta regresiva en cuatro cajas (días, horas, minutos y segundos) que se
/// actualiza cada segundo.
class FlashCountdown extends StatefulWidget {
  /// Las pruebas lo apagan (`test/flutter_test_config.dart`): un temporizador
  /// que se repite impide que terminen.
  static bool ticking = true;

  final DateTime endsAt;
  final DateTime Function() now;

  const FlashCountdown({super.key, required this.endsAt, this.now = DateTime.now});

  @override
  State<FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<FlashCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (FlashCountdown.ticking) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(widget.now());
    final remaining = left.isNegative ? Duration.zero : left;

    String two(int n) => n.toString().padLeft(2, '0');

    return Row(
      children: [
        _Unit(value: two(remaining.inDays), label: 'Días'),
        _Unit(value: two(remaining.inHours % 24), label: 'Hrs'),
        _Unit(value: two(remaining.inMinutes % 60), label: 'Min'),
        _Unit(value: two(remaining.inSeconds % 60), label: 'Seg'),
      ],
    );
  }
}

class _Unit extends StatelessWidget {
  final String value;
  final String label;

  const _Unit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banners promocionales
// ---------------------------------------------------------------------------

/// "Promociones": banners grandes con el nombre y el precio de cada una, que se
/// deslizan de lado.
class PromoBannersSection extends StatefulWidget {
  final List<PromoBanner> banners;
  final ValueChanged<PromoBanner> onOpen;

  const PromoBannersSection({super.key, required this.banners, required this.onOpen});

  @override
  State<PromoBannersSection> createState() => _PromoBannersSectionState();
}

class _PromoBannersSectionState extends State<PromoBannersSection> {
  final _controller = PageController(viewportFraction: 0.9);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Promociones'),
        SizedBox(
          height: PromoBannerCard.height + 12,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: PromoBannerCard(
                banner: banners[i],
                onTap: () => widget.onOpen(banners[i]),
              ),
            ),
          ),
        ),
        if (banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < banners.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Un banner promocional: la imagen con el nombre y el precio en insignias de
/// colores y el botón, todos con los colores que define la empresa.
class PromoBannerCard extends StatelessWidget {
  static const double height = 190;

  final PromoBanner banner;
  final VoidCallback onTap;

  const PromoBannerCard({super.key, required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(20);
    final buttonColor = _color(banner.buttonColor, primary);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProductImage(url: banner.imageUrl),
                // Oscurece la parte de abajo, donde va el texto.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (banner.title.isNotEmpty)
                              _Badge(
                                label: banner.title,
                                color: _color(banner.nameBadgeColor, primary),
                              ),
                            if (banner.price != null)
                              _Badge(
                                label: banner.price!,
                                color: _color(
                                  banner.priceBadgeColor,
                                  const Color(0xFF28A745),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: ColorUtils.onColor(buttonColor),
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: Text(banner.buttonText ?? 'Ver más'),
                      ),
                    ],
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

/// Insignia de color con texto (y un ícono opcional).
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final onColor = ColorUtils.onColor(color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: onColor),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
