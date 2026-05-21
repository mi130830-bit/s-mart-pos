import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../pos_state_manager.dart';
import '../../../services/logger_service.dart';
import '../../../services/alert_service.dart';

/// Dialog that shows the list of held bills.
/// Reads [PosStateManager] directly from context — no Prop Drilling.
class HeldBillsDialog extends ConsumerWidget {
  const HeldBillsDialog({super.key});

  Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('ยืนยัน',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(posProvider);
    final posState = ref.read(posProvider.notifier);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('รายการพักบิล (ล่าสุด 50)'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'clear_old') {
                final confirm = await _confirmDialog(context,
                    title: 'ล้างบิลเก่า',
                    content: 'ลบบิลที่ค้างนานกว่า 7 วันทั้งหมด?');
                if (confirm) {
                  await posState.clearOldHeldBills(7);
                  if (context.mounted) Navigator.pop(context);
                }
              } else if (val == 'clear_all') {
                final confirm = await _confirmDialog(context,
                    title: 'ล้างทั้งหมด',
                    content: 'คุณแน่ใจหรือไม่ที่จะลบรายการพักบิลทั้งหมด?');
                if (confirm) {
                  await posState.clearAllHeldBills();
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_old',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('ล้างบิลเก่า (> 7 วัน)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ล้างทั้งหมด (Clear All)'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 300,
        child: posState.heldBills.isEmpty
            ? const Center(child: Text('ไม่มีรายการพักบิล'))
            : ListView.separated(
                itemCount: posState.heldBills.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final bill = posState.heldBills[i];
                  return ListTile(
                    title: Text(bill.customer?.firstName ?? 'ลูกค้าทั่วไป'),
                    subtitle: Text(
                      '${bill.items.length} รายการ - ฿${NumberFormat('#,##0.00').format(bill.total)}\n'
                      '${DateFormat('dd/MM HH:mm').format(bill.timestamp)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await _confirmDialog(ctx,
                            title: 'ลบรายการ', content: 'ยืนยันการลบ?');
                        if (confirm) {
                          await posState.deleteHeldBill(i);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                    ),
                    onTap: () => _onRecallBill(ctx, posState, i),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _onRecallBill(
      BuildContext ctx, PosStateNotifier posState, int index) async {
    // Show loading spinner while checking stock
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('กำลังตรวจสอบสต็อก...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final warnings = await posState.checkHeldBillStock(index);

      if (ctx.mounted) Navigator.pop(ctx); // close loading

      if (warnings.isEmpty) {
        await posState.recallHeldBill(index);
        if (ctx.mounted) Navigator.pop(ctx); // close list
      } else {
        if (!ctx.mounted) return;
        _showStockWarningDialog(ctx, posState, index, warnings);
      }
    } catch (e, stackTrace) {
      LoggerService.error(
          'POS_HeldBillsDialog', 'Error recalling held bill: $e', e, stackTrace);
      if (ctx.mounted) Navigator.pop(ctx); // close loading
      if (ctx.mounted) {
        AlertService.show(
          context: ctx,
          message: 'ไม่สามารถโหลดบิลได้: $e',
          type: 'error',
        );
      }
    }
  }

  void _showStockWarningDialog(
    BuildContext ctx,
    PosStateNotifier posState,
    int index,
    List<String> warnings,
  ) {
    showDialog(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('สินค้าไม่เพียงพอ'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('รายการต่อไปนี้มีสินค้าในคลังไม่พอจ่าย:'),
              const SizedBox(height: 8),
              ...warnings.map(
                  (w) => Text(w, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 16),
              const Text('คุณต้องการดึงบิลคืนมาหรือไม่?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(context); // close warning
              await posState.recallHeldBill(index); // force recall
              if (ctx.mounted) Navigator.pop(ctx); // close list
            },
            child: const Text('ทำต่อ (Proceed Anyway)'),
          ),
        ],
      ),
    );
  }
}
