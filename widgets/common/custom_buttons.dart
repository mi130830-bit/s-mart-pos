import 'package:flutter/material.dart';

enum ButtonType { primary, secondary, danger }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonType type;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  // ... factories can remain as is or be updated if needed, but not critical for now.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color bg;
    Color fg;

    if (backgroundColor != null) {
      bg = backgroundColor!;
    } else {
      switch (type) {
        case ButtonType.primary:
          bg = colorScheme.primary;
          break;
        case ButtonType.secondary:
          bg = colorScheme.secondaryContainer;
          break;
        case ButtonType.danger:
          bg = colorScheme.error;
          break;
      }
    }

    if (foregroundColor != null) {
      fg = foregroundColor!;
    } else {
      switch (type) {
        case ButtonType.primary:
          fg = colorScheme.onPrimary;
          break;
        case ButtonType.secondary:
          fg = colorScheme.onSecondaryContainer;
          break;
        case ButtonType.danger:
          fg = colorScheme.onError;
          break;
      }
    }

    final style = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: Colors.grey.shade300,
      disabledForegroundColor: Colors.grey.shade600,
    );

    if (isLoading) {
      return ElevatedButton(
        style: style,
        onPressed: null,
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(fg),
          ),
        ),
      );
    }

    if (icon != null) {
      return ElevatedButton.icon(
        style: style,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      );
    }

    return ElevatedButton(
      style: style,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
