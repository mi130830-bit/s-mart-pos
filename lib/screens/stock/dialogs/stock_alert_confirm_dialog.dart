import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/shortage_provider.dart';

class StockAlertConfirmDialog {
  static Future<void> showDeleteConfirm(BuildContext context, int id, String name) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรายการ "$name" ใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<ShortageProvider>(context, listen: false)
                  .markAsDone(id);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
