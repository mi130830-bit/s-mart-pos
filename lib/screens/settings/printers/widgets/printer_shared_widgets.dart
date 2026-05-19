import 'package:flutter/material.dart';

/// Shared stateless widget: Section header with icon, title, and optional "เฉพาะเครื่องนี้" badge.
class PrinterSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isLocal;

  const PrinterSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800]),
          ),
        ),
        if (isLocal) ...[
          const Icon(Icons.computer, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          const Text('เฉพาะเครื่องนี้',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ],
    );
  }
}

/// Shared widget: Printer dropdown card with preview + test-print buttons.
/// Used by Tax and any single-printer section that doesn't need paper size.
class PrinterDropdownCard extends StatelessWidget {
  final List<dynamic> printers; // List<Printer>
  final dynamic selectedPrinter; // Printer?
  final ValueChanged<dynamic> onChanged; // ValueChanged<Printer?>
  final String label;
  final VoidCallback? onPreview;
  final VoidCallback? onTestPrint;

  const PrinterDropdownCard({
    super.key,
    required this.printers,
    required this.selectedPrinter,
    required this.onChanged,
    required this.label,
    this.onPreview,
    this.onTestPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'เลือกเครื่องพิมพ์',
                  border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: printers.any((p) => p.name == selectedPrinter?.name)
                      ? selectedPrinter?.name as String?
                      : null,
                  isExpanded: true,
                  hint: const Text('เลือกเครื่องพิมพ์'),
                  items: printers
                      .map<DropdownMenuItem<String>>(
                          (p) => DropdownMenuItem(value: p.name as String, child: Text(p.name as String)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) {
                      onChanged(null);
                    } else {
                      onChanged(printers.firstWhere((p) => p.name == val));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onPreview != null)
                  _ActionButton(
                    icon: Icons.visibility,
                    label: 'ดูตัวอย่าง',
                    onPressed: onPreview!,
                    isPrimary: false,
                  ),
                if (onPreview != null) const SizedBox(width: 10),
                if (onTestPrint != null && selectedPrinter != null)
                  _ActionButton(
                    icon: Icons.print,
                    label: 'ทดสอบพิมพ์',
                    onPressed: onTestPrint!,
                    isPrimary: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: isPrimary
          ? OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
    );
  }
}
