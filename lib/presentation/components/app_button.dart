import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

enum AppButtonVariant { primary, secondary, outline, text }

/// Botón estándar de la app. Deshabilita y muestra un spinner mientras
/// [isLoading] es true.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final VoidCallback? action = isLoading ? null : onPressed;
    final child = _content(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
    );
    const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: action,
          style: FilledButton.styleFrom(shape: shape, padding: padding),
          child: child,
        ),
      AppButtonVariant.secondary => FilledButton.tonal(
          onPressed: action,
          style: FilledButton.styleFrom(shape: shape, padding: padding),
          child: child,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: action,
          style: OutlinedButton.styleFrom(shape: shape, padding: padding),
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: action,
          style: TextButton.styleFrom(shape: shape, padding: padding),
          child: child,
        ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _content(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
