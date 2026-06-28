import 'package:flutter/material.dart';
import '../utils/hr_status_utils.dart';

class HrStatusBadge extends StatelessWidget {
  final String status;
  final HrItemType type;

  const HrStatusBadge({
    super.key,
    required this.status,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = HrStatusUtils.getStatusColor(status);
    final statusText = HrStatusUtils.formatStatus(status, type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
