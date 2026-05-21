import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import '../../../repositories/product_repository.dart';
import '../../../repositories/stock_repository.dart';
import '../../../services/alert_service.dart';
import '../../../services/logger_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/telegram_service.dart';
import '../../../widgets/dialogs/admin_pin_dialog.dart';
import '../cloud_stock_import_dialog.dart';

class AdjustmentItem {
  final Product product;
  final double systemQty;
  final double countedQty;
  final String note;

  AdjustmentItem({
    required this.product,
    required this.systemQty,
    required this.countedQty,
    this.note = '',
  });

  double get diff => countedQty - systemQty;

  String get type {
    if (diff > 0) return 'OVER';
    if (diff < 0) return 'SHORT';
    return 'MATCH';
  }
}

class StockAdjustmentState {
  final List<AdjustmentItem> pendingItems;

  StockAdjustmentState({this.pendingItems = const []});

  StockAdjustmentState copyWith({
    List<AdjustmentItem>? pendingItems,
  }) {
    return StockAdjustmentState(
      pendingItems: pendingItems ?? this.pendingItems,
    );
  }
}

final stockAdjustmentProvider = AutoDisposeNotifierProvider<StockAdjustmentController, StockAdjustmentState>(
  () => StockAdjustmentController(),
);

class StockAdjustmentController extends AutoDisposeNotifier<StockAdjustmentState> {
  final ProductRepository productRepo = ProductRepository();
  final StockRepository _stockRepo = StockRepository();
  bool _mounted = true;

  @override
  StockAdjustmentState build() {
    _mounted = true;
    ref.onDispose(() => _mounted = false);
    return StockAdjustmentState();
  }

  void addPendingItem(AdjustmentItem item) {
    if (!_mounted) return;
    state = state.copyWith(
      pendingItems: [...state.pendingItems, item],
    );
  }

  void removePendingItem(int index) {
    if (!_mounted) return;
    if (index >= 0 && index < state.pendingItems.length) {
      final newItems = List<AdjustmentItem>.from(state.pendingItems);
      newItems.removeAt(index);
      state = state.copyWith(pendingItems: newItems);
    }
  }

  Future<void> openCloudImportDialog(BuildContext context) async {
    final List<Map<String, dynamic>>? importedItems = await showDialog(
      context: context,
      builder: (context) => const CloudStockImportDialog(),
    );

    if (importedItems != null && importedItems.isNotEmpty) {
      int addedCount = 0;
      final newItems = List<AdjustmentItem>.from(state.pendingItems);
      for (var item in importedItems) {
        try {
          final prodMap = item['product'] as Map<String, dynamic>;
          prodMap['stockQuantity'] =
              double.tryParse(prodMap['stockQuantity'].toString()) ?? 0.0;
          
          final product = Product.fromJson(prodMap);

          newItems.add(AdjustmentItem(
            product: product,
            systemQty: double.tryParse(item['systemQty'].toString()) ?? 0.0,
            countedQty: double.tryParse(item['actualQty'].toString()) ?? 0.0,
            note: 'Import from Cloud',
          ));
          addedCount++;
        } catch (e, stackTrace) {
          LoggerService.error('StockAdjust', 'Product Map Error: $e', e, stackTrace);
        }
      }

      if (addedCount > 0) {
        if (_mounted) {
          state = state.copyWith(pendingItems: newItems);
        }
        if (context.mounted) {
          AlertService.show(
            context: context,
            message: 'นำเข้า $addedCount รายการแล้ว กรุณากดบันทึกอีกครั้ง',
            type: 'info'
          );
        }
      } else {
        if (context.mounted) {
          AlertService.show(
            context: context, 
            message: 'เกิดข้อผิดพลาดในการโหลดข้อมูลสินค้า', 
            type: 'error'
          );
        }
      }
    }
  }

  Future<void> saveAllAdjustments(BuildContext context) async {
    LoggerService.info('StockAdjust', 'saveAllAdjustments called');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการปรับปรุงสต็อก'),
        content: Text(
            'คุณต้องการบันทึกการปรับปรุงสต็อกจำนวน ${state.pendingItems.length} รายการ หรือไม่?\n\n'
            '⚠️ สต็อกสินค้าจะถูกเปลี่ยนแปลงตามยอดที่นับจริงทันที'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;
    if (state.pendingItems.isEmpty) return;

    final itemsToAdjust = List<AdjustmentItem>.from(state.pendingItems);

    if (SettingsService().requireAdminForStockAdjust) {
      final authorized = await AdminPinDialog.show(
        context,
        title: 'ยืนยันสิทธิ์',
        message: 'กรุณากรอกรหัสแอดมินเพื่อปรับปรุงสต็อก',
      );
      if (!authorized) return;
    }

    if (!context.mounted) return;

    int successCount = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    for (var item in itemsToAdjust) {
      try {
        bool success = await _stockRepo.updateStockToExact(
          item.product.id,
          item.countedQty,
          note: item.note.isNotEmpty
              ? item.note
              : 'Stock Check: System=${item.systemQty.toStringAsFixed(0)}, Counted=${item.countedQty.toStringAsFixed(0)}',
        );

        if (success) {
          successCount++;
        } else {
          if (context.mounted) {
            AlertService.show(context: context, message: 'บันทึกสต็อก ${item.product.name} ไม่สำเร็จ', type: 'warning');
          }
        }
      } catch (e, stackTrace) {
        LoggerService.error('StockAdjust', 'Failed to update stock for ${item.product.name}', e, stackTrace);
        if (context.mounted) {
          AlertService.show(context: context, message: 'เกิดข้อผิดพลาดในการอัปเดตสต็อก', type: 'error');
        }
      }
    }

    if (!context.mounted) return;
    Navigator.pop(context); // close loading dialog
    
    AlertService.show(
      context: context,
      message: 'บันทึกสำเร็จ $successCount รายการ',
      type: 'success',
    );

    try {
      if (successCount > 0 &&
          await TelegramService()
              .shouldNotify(TelegramService.keyNotifyStockAdjust)) {
        String msg = '🔧 *ปรับปรุงสต็อก (Check Stock)*\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '📅 รายการที่ตรวจนับ: $successCount รายการ\n';

        for (var i = 0; i < (itemsToAdjust.length > 5 ? 5 : itemsToAdjust.length); i++) {
          final item = itemsToAdjust[i];
          final diff = item.diff;
          final isPos = diff > 0;
          final isZero = diff == 0;

          final String changeText = isZero
              ? "✅ Verified"
              : "${isPos ? "+" : ""}${diff.toStringAsFixed(0)}";

          msg += '📦 ${item.product.name}: $changeText (Sys:${item.systemQty.toStringAsFixed(0)}->Cnt:${item.countedQty.toStringAsFixed(0)})\n';
        }
        if (itemsToAdjust.length > 5) {
          msg += '... และรายการอื่นอีก ${itemsToAdjust.length - 5} รายการ\n';
        }
        msg += '━━━━━━━━━━━━━━━━━━';
        TelegramService().sendMessage(msg);
      }
    } catch (e, stackTrace) {
      LoggerService.error('StockAdjust', 'Telegram Stock Adjust Error: $e', e, stackTrace);
    }

    if (_mounted) {
      state = state.copyWith(pendingItems: []);
    }
  }
}
