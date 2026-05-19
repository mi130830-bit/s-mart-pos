import 'package:flutter/material.dart';

/// Reusable section header for Settings screens.
/// Shows an icon, title, and optional "เฉพาะเครื่องนี้" badge.
class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isLocal;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
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
      ),
    );
  }
}
