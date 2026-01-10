import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final String? initialValue;
  final bool? filled;
  final Color? fillColor;
  final FocusNode? focusNode;
  final TextStyle? style;
  final TextAlign textAlign;

  final bool selectAllOnFocus;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.prefixText,
    this.inputFormatters,
    this.initialValue,
    this.filled,
    this.fillColor,
    this.focusNode,
    this.style,
    this.textAlign = TextAlign.start,
    this.selectAllOnFocus = false,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late TextEditingController _controller;
  bool _isInternalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue);
      _isInternalController = true;
    }
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && widget.controller != _controller) {
      // Switched to external controller
      if (_isInternalController) {
        _controller.dispose();
      }
      _controller = widget.controller!;
      _isInternalController = false;
    } else if (widget.controller == null && !_isInternalController) {
      // Switched from external to internal (rare, but possible)
      _controller = TextEditingController(text: widget.initialValue);
      _isInternalController = true;
    } else if (_isInternalController &&
        widget.initialValue != oldWidget.initialValue) {
      // Initial value changed for internal controller
      // Only update if the text is different to avoid cursor jumps loops if used incorrectly
      if (_controller.text != widget.initialValue) {
        // _controller.text = widget.initialValue ?? '';
        // Note: Resetting text here might disrupt typing if parent rebuilds on every char.
        // But since standard TextFormField with initialValue does NOT update on rebuilds,
        // we should mimic that or follow the user's need.
        // For recreating widgets (key change), initState handles it.
        // For same widget update, we usually don't overwrite text unless specific need.
        // Let's stick to standard behavior: initialValue is for INITIAL only.
      }
    }
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: widget.focusNode,
      // initialValue: widget.initialValue, // CANNOT use both controller and initialValue
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      readOnly: widget.readOnly,
      onTap: () {
        if (widget.selectAllOnFocus) {
          if (_controller.text.isNotEmpty) {
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
          }
        }
        if (widget.onTap != null) widget.onTap!();
      },
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      inputFormatters: widget.inputFormatters,
      textAlign: widget.textAlign,
      style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: widget.suffixIcon,
        prefixText: widget.prefixText,
        filled: widget.filled,
        fillColor: widget.fillColor,
      ),
    );
  }
}
