import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants/app_constants.dart';

/// Una fila horizontal de tarjetas que avanza sola y sin fin (como un cartel en
/// movimiento). Se detiene al tocarla o arrastrarla y sigue unos segundos
/// después de soltarla. Con pocos elementos, que caben en pantalla, no se mueve.
class AutoScrollRow extends StatefulWidget {
  /// Las pruebas lo apagan (`test/flutter_test_config.dart`): una animación sin
  /// fin impide que `pumpAndSettle` termine.
  static bool autoScroll = true;

  /// Cuánto se espera, tras soltarla, para seguir avanzando.
  static const Duration resumeAfter = Duration(seconds: 3);

  /// Separación entre tarjetas.
  static const double gap = 12;

  final int itemCount;

  /// Construye la tarjeta [index] (0 hasta [itemCount] - 1). [looped] es true en
  /// las repeticiones del carril sin fin: ahí no deben ir claves únicas.
  final Widget Function(BuildContext context, int index, bool looped) itemBuilder;
  final double height;

  /// Velocidad del avance, en píxeles por segundo.
  final double speed;

  /// Desde cuántos elementos se mueve; con menos caben todos en pantalla.
  final int minToScroll;

  const AutoScrollRow({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.speed = 26,
    this.minToScroll = 5,
  });

  @override
  State<AutoScrollRow> createState() => _AutoScrollRowState();
}

class _AutoScrollRowState extends State<AutoScrollRow>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  bool _touching = false;
  Timer? _resume;

  /// Falso para quien pidió menos movimiento en el sistema.
  bool _allowed = true;

  bool get _moves => widget.itemCount >= widget.minToScroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _allowed = !MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(AutoScrollRow old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  void _syncTicker() {
    final shouldRun = AutoScrollRow.autoScroll && _allowed && _moves;
    if (shouldRun && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final seconds = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (_touching || _resume != null || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.offset + widget.speed * seconds);
  }

  void _onPointerDown() {
    _touching = true;
    _resume?.cancel();
    _resume = null;
  }

  void _onPointerUp() {
    _touching = false;
    _resume?.cancel();
    _resume = Timer(AutoScrollRow.resumeAfter, () => _resume = null);
  }

  @override
  void dispose() {
    _resume?.cancel();
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.itemCount;
    final loops = _moves;

    return SizedBox(
      height: widget.height,
      child: Listener(
        onPointerDown: (_) => _onPointerDown(),
        onPointerUp: (_) => _onPointerUp(),
        onPointerCancel: (_) => _onPointerUp(),
        child: ListView.builder(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
            vertical: 8,
          ),
          // Con muchos elementos la fila no termina: al llegar al último vuelve
          // a empezar.
          itemCount: loops ? null : count,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(right: AutoScrollRow.gap),
            child: widget.itemBuilder(context, i % count, i >= count),
          ),
        ),
      ),
    );
  }
}
