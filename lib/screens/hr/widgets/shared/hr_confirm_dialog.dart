import 'package:flutter/material.dart';

/// Generic reusable confirmation dialog for HR module.
/// Replaces 7+ identical inline AlertDialog patterns across the module.
///
/// Usage:
/// ```dart
/// final ok = await HrConfirmDialog.show(
///   context,
///   title: 'ลบรายการ',
///   content: 'ยืนยันการลบ?',
///   actionLabel: 'ลบ',
///   actionColor: Colors.red,
/// );
/// if (ok == true) { ... }
/// ```
class HrConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String actionLabel;
  final Color actionColor;
  final IconData? titleIcon;
  final IconData? actionIcon;

  const HrConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actionLabel,
    required this.actionColor,
    this.titleIcon,
    this.actionIcon,
  });

  /// Convenience static method to show and await result.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String content,
    required String actionLabel,
    required Color actionColor,
    IconData? titleIcon,
    IconData? actionIcon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => HrConfirmDialog(
        title: title,
        content: content,
        actionLabel: actionLabel,
        actionColor: actionColor,
        titleIcon: titleIcon,
        actionIcon: actionIcon,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: titleIcon != null
          ? Row(
              children: [
                Icon(titleIcon, color: actionColor, size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            )
          : Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        actionIcon != null
            ? ElevatedButton.icon(
                icon: Icon(actionIcon),
                label: Text(actionLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
      ],
    );
  }
}
