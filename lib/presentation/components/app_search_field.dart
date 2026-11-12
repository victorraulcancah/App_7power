import 'dart:async';
import 'package:flutter/material.dart';

/// Buscador que espera [debounce] tras la última tecla antes de notificar,
/// para no disparar una petición por cada letra.
class AppSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onSearch;
  final Duration debounce;
  final String? initialValue;

  /// Bajo y de borde gris, sin la sombra roja: el de las barras claras (como el
  /// del inicio).
  final bool compact;

  const AppSearchField({
    super.key,
    required this.onSearch,
    this.hint = 'Buscar productos',
    this.debounce = const Duration(milliseconds: 400),
    this.initialValue,
    this.compact = false,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _timer;

  /// Si el texto cambia desde fuera (una búsqueda hecha en el inicio), el
  /// campo lo muestra. Lo que el usuario escribe aquí no se pisa: coincide con
  /// lo que ya se notificó.
  @override
  void didUpdateWidget(AppSearchField old) {
    super.didUpdateWidget(old);
    final value = widget.initialValue ?? '';
    if (widget.initialValue != old.initialValue &&
        value != _controller.text.trim()) {
      _controller.text = value;
    }
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onSearch(value.trim()));
    setState(() {});
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onSearch('');
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchBox(
      flat: widget.compact,
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: widget.compact ? const TextStyle(fontSize: 14) : null,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _timer?.cancel();
          widget.onSearch(v.trim());
        },
        decoration: SearchBox.decoration(
          context,
          hint: widget.hint,
          compact: widget.compact,
          suffix: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar',
                  icon: const Icon(Icons.close),
                  onPressed: _clear,
                ),
        ),
      ),
    );
  }
}

/// El estilo de los buscadores de la tienda: campo blanco en forma de píldora,
/// borde rojo que se engrosa al escribir y una sombra suave del mismo color.
class SearchBox extends StatelessWidget {
  static const double radius = 28;

  final Widget child;

  /// Sin la sombra roja (para la barra clara del inicio).
  final bool flat;

  const SearchBox({super.key, required this.child, this.flat = false});

  /// Decoración del `TextField` que va dentro de un [SearchBox]. [suffix] es lo
  /// que va a la derecha (borrar, o el botón de buscar).
  ///
  /// Con [compact] el campo es más bajo (el del inicio, que comparte fila con
  /// los íconos de favoritos y carrito).
  static InputDecoration decoration(
    BuildContext context, {
    required String hint,
    Widget? suffix,
    bool compact = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: compact ? 13 : 14,
        color: const Color(0xFF8A8A8F),
      ),
      hintMaxLines: 1,
      prefixIcon: Icon(Icons.search_rounded, color: primary, size: compact ? 20 : 24),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: compact,
      // Sin esto los íconos reservan 48 px a cada lado y el botón de buscar se
      // sale del óvalo en el campo bajo.
      prefixIconConstraints:
          compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
      suffixIconConstraints:
          compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null,
      contentPadding: EdgeInsets.symmetric(vertical: compact ? 10 : 15, horizontal: 8),
      // El compacto va sobre una barra blanca: borde gris fino, sin el rojo.
      border: compact
          ? border(const Color(0xFFCFCFD6), 1)
          : border(primary.withValues(alpha: 0.55), 1.2),
      enabledBorder: compact
          ? border(const Color(0xFFCFCFD6), 1)
          : border(primary.withValues(alpha: 0.55), 1.2),
      focusedBorder: border(primary, compact ? 1.5 : 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sin sombra: el campo plano de la barra del inicio.
    if (flat) return child;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Botón redondo rojo con flecha, para enviar la búsqueda.
class SearchSubmitButton extends StatelessWidget {
  final VoidCallback onPressed;

  /// Más chico, para el buscador compacto del inicio.
  final bool compact;

  const SearchSubmitButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 36.0;

    return Padding(
      padding: EdgeInsets.only(right: compact ? 5 : 6),
      child: IconButton.filled(
        tooltip: 'Buscar',
        style: IconButton.styleFrom(
          minimumSize: Size(size, size),
          fixedSize: Size(size, size),
          padding: EdgeInsets.zero,
          // Blanco explícito: dentro del campo la flecha tomaba el color gris
          // de los íconos del campo y casi no se veía sobre el rojo.
          foregroundColor: Colors.white,
        ),
        icon: Icon(Icons.arrow_forward_rounded,
            size: compact ? 18 : 20, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
