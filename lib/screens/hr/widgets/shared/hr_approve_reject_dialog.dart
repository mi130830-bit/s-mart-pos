import 'package:flutter/material.dart';

class HrApproveRejectDialog {
  static void show({
    required BuildContext context,
    required String title,
    required String content,
    required String actionLabel,
    required Color actionColor,
    required Future<void> Function(String remark) onConfirm,
    bool requireRemark = false,
  }) {
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            const SizedBox(height: 16),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(
                labelText: 'หมายเหตุ (ตัวเลือก)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              try {
                await onConfirm(remarkController.text);
                if (context.mounted) {
                  Navigator.pop(context); // pop loading
                  Navigator.pop(context); // pop dialog
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // pop loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: actionColor, foregroundColor: Colors.white),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
