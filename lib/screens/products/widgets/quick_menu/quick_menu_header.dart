import 'package:flutter/material.dart';

class QuickMenuHeader extends StatelessWidget {
  final String pageName;
  final bool isEditMode;
  final ValueChanged<bool> onEditModeChanged;
  final VoidCallback? onRenamePage;
  final VoidCallback onRestoreDefaults;
  final VoidCallback onClose;

  const QuickMenuHeader({
    super.key,
    required this.pageName,
    required this.isEditMode,
    required this.onEditModeChanged,
    required this.onRenamePage,
    required this.onRestoreDefaults,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          pageName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            const Text('โหมดแก้ไข: '),
            Switch(
              value: isEditMode,
              onChanged: onEditModeChanged,
            ),
            if (isEditMode && onRenamePage != null)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'เปลี่ยนชื่อหน้า',
                onPressed: onRenamePage,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'คืนค่าเริ่มต้น (Reload Defaults)',
              onPressed: onRestoreDefaults,
            ),
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            )
          ],
        ),
      ],
    );
  }
}
