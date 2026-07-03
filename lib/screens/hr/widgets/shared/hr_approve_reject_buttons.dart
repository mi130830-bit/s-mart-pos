import 'package:flutter/material.dart';

/// Reusable approve / reject button pair for HR list items.
/// Used in Leave tab and Advance tab trailing buttons.
class HrApproveRejectButtons extends StatelessWidget {
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const HrApproveRejectButtons({
    super.key,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.green),
          tooltip: 'อนุมัติ',
          onPressed: onApprove,
        ),
        IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          tooltip: 'ปฏิเสธ',
          onPressed: onReject,
        ),
      ],
    );
  }
}
