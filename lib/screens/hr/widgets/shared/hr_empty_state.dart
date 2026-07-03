import 'package:flutter/material.dart';

/// Centered empty-state widget for HR list views.
/// Shows an icon, a primary message, and an optional hint below it.
class HrEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;

  const HrEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
