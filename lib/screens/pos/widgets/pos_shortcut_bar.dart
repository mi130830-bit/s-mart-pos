import 'package:flutter/material.dart';

/// แถบ Shortcut Keys ที่ด้านล่างหน้าจอ POS
class PosShortcutBar extends StatelessWidget {
  const PosShortcutBar({super.key});

  static const _shortcuts = [
    {'key': 'F1', 'label': 'จำนวน'},
    {'key': 'F2', 'label': 'ลูกค้า'},
    {'key': 'F3', 'label': 'ค้นหา'},
    {'key': 'F4', 'label': 'สินค้าด่วน'},
    {'key': 'F5', 'label': 'ยกเลิกบิล'},
    {'key': 'F9', 'label': 'คิดเงิน'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Colors.grey[850] : Colors.grey[200],
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _shortcuts.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s['key']!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 4),
                Text(s['label']!,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.color)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
