import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

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
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (v) {
        _timer?.cancel();
        widget.onSearch(v.trim());
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(icon: const Icon(Icons.close), onPressed: _clear),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
