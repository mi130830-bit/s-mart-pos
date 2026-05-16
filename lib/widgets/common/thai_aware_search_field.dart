import 'package:flutter/material.dart';
import '../../utils/thai_keyboard_converter.dart';
import 'custom_text_field.dart';

/// ✅ ThaiAwareSearchField
/// Drop-in replacement สำหรับ CustomTextField ในช่องค้นหา
///
/// เพิ่มความสามารถ: ตรวจจับเมื่อผู้ใช้พิมพ์อังกฤษแทนไทย
/// และแสดง Chip แนะนำ "แปลงเป็นภาษาไทย: ..." ให้กดยืนยัน 1 ครั้ง
///
/// Usage (แทนที่ CustomTextField เดิม):
/// ```dart
/// ThaiAwareSearchField(
///   controller: _searchCtrl,
///   focusNode: _searchFocus,
///   label: 'ค้นหาสินค้า',
///   onChanged: _onSearchChanged,
/// )
/// ```
class ThaiAwareSearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final Widget? suffixIcon;

  const ThaiAwareSearchField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.suffixIcon,
  });

  @override
  State<ThaiAwareSearchField> createState() => _ThaiAwareSearchFieldState();
}

class _ThaiAwareSearchFieldState extends State<ThaiAwareSearchField> {
  String? _suggestion;

  void _handleChanged(String value) {
    // ตรวจหาการพิมพ์ผิดภาษา
    if (ThaiKeyboardConverter.isLikelyWrongLang(value)) {
      final converted = ThaiKeyboardConverter.convert(value);
      if (converted != value && mounted) {
        setState(() => _suggestion = converted);
      }
    } else {
      if (_suggestion != null && mounted) {
        setState(() => _suggestion = null);
      }
    }

    widget.onChanged?.call(value);
  }

  void _applyConversion() {
    final converted = _suggestion;
    if (converted == null) return;

    widget.controller.text = converted;
    widget.controller.selection =
        TextSelection.collapsed(offset: converted.length);

    setState(() => _suggestion = null);

    // แจ้ง parent ให้ทำการค้นหาด้วยค่าใหม่
    widget.onChanged?.call(converted);
    widget.focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search Field ───────────────────────────────────────────
        CustomTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          label: widget.label,
          prefixIcon: Icons.search,
          suffixIcon: widget.suffixIcon ??
              (widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.controller.clear();
                        setState(() => _suggestion = null);
                        widget.onChanged?.call('');
                        widget.focusNode?.requestFocus();
                      },
                    )
                  : null),
          onChanged: _handleChanged,
          onSubmitted: widget.onSubmitted,
        ),

        // ── Thai Conversion Chip ───────────────────────────────────
        if (_suggestion != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              onTap: _applyConversion,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.translate,
                        size: 15, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'แปลงเป็นภาษาไทย: "$_suggestion"',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_outline,
                        size: 15, color: Colors.orange.shade700),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
