import 'package:flutter/material.dart';

class HrTabHeader extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final IconData createIcon;
  final String createLabel;
  final String refreshLabel;

  const HrTabHeader({
    super.key,
    required this.title,
    required this.onRefresh,
    required this.onCreate,
    this.createIcon = Icons.add,
    required this.createLabel,
    this.refreshLabel = 'รีเฟรช',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(refreshLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: Icon(createIcon),
              label: Text(createLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        )
      ],
    );
  }
}
