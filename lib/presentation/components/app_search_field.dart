import 'dart:async';
import 'package:flutter/material.dart';

/// Buscador que espera [debounce] tras la última tecla antes de notificar,
/// para no disparar una petición por cada letra.
class AppSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onSearch;
  final Duration debounce;
  final String? initialValue;

  const AppSearchField({
    super.key,
    required this.onSearch,
    this.hint = 'Buscar productos',
    this.debounce = const Duration(milliseconds: 400),
    this.initialValue,
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
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _timer?.cancel();
          widget.onSearch(v.trim());
        },
        decoration: SearchBox.decoration(
          context,
          hint: widget.hint,
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

  const SearchBox({super.key, required this.child});

  /// Decoración del `TextField` que va dentro de un [SearchBox]. [suffix] es lo
  /// que va a la derecha (borrar, o el botón de buscar).
  static InputDecoration decoration(
    BuildContext context, {
    required String hint,
    Widget? suffix,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8A8A8F)),
      hintMaxLines: 1,
      prefixIcon: Icon(Icons.search_rounded, color: primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      border: border(primary.withValues(alpha: 0.55), 1.2),
      enabledBorder: border(primary.withValues(alpha: 0.55), 1.2),
      focusedBorder: border(primary, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
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

  const SearchSubmitButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton.filled(
        tooltip: 'Buscar',
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          fixedSize: const Size(40, 40),
        ),
        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
