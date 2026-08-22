import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../services/idempotency_payload.dart';
import '../services/telegram_service.dart';
import './activity_repository.dart';

part 'stock/stock_ledger_extension.dart';
part 'stock/purchase_order_query_extension.dart';
part 'stock/purchase_order_command_extension.dart';
part 'stock/purchase_order_receiving_extension.dart';

class StockRepository {
  final MySQLService _dbService = MySQLService();

  /// Applies rows imported from S-Link only.  It deliberately owns one
  /// transaction for the full sheet: the sheet is locked and verified open
  /// before a single product or ledger row can change, then marked checked in
  /// that same transaction.  Manual stock adjustments continue to use
  /// [updateStockToExact].
  Future<void> applySLinkStockCheckAdjustments(
    List<SLinkStockCheckAdjustment> adjustments, {
    int? checkedBy,
  }) async {
    if (adjustments.isEmpty) return;
    if (!_dbService.isConnected()) await _dbService.connect();
    if (!_dbService.isConnected()) {
      throw StateError('ไม่สามารถเชื่อมต่อฐานข้อมูลเพื่อปรับใบตรวจนับได้');
    }

    final sheetIds =
        adjustments.expand((adjustment) => adjustment.sourceWorkLogIds).toSet();
    if (sheetIds.isEmpty) {
      throw ArgumentError('S-Link stock adjustments require a source sheet');
    }

    await _dbService.execute('START TRANSACTION');
    try {
      // Lock every source sheet first.  This makes a concurrent POS session
      // wait and then fail here after the first session has closed the sheet.
      for (final sheetId in sheetIds) {
        final sheet = await _dbService.query(
          '''SELECT stock_checked_at FROM shop_work_logs
             WHERE sync_id = :syncId FOR UPDATE''',
          {'syncId': sheetId},
        );
        if (sheet.length != 1 || sheet.first['stock_checked_at'] != null) {
          throw StateError('ใบตรวจนับถูกยืนยันไปแล้วหรือไม่พบ: $sheetId');
        }
      }

      for (final adjustment in adjustments) {
        final product = await _dbService.query(
          'SELECT stockQuantity FROM product WHERE id = :id FOR UPDATE',
          {'id': adjustment.productId},
        );
        if (product.isEmpty) {
          throw StateError(
              'ไม่พบสินค้าสำหรับใบตรวจนับ: ${adjustment.productId}');
        }
        final current =
            double.tryParse(product.first['stockQuantity'].toString()) ?? 0.0;
        final difference = adjustment.countedQty - current;
        if (difference == 0) {
          await _dbService.execute(
            '''INSERT INTO stockledger
                 (productId, transactionType, quantityChange, note, createdAt)
               VALUES (:pid, 'ADJUST_FIX', 0, :note, NOW())''',
            {'pid': adjustment.productId, 'note': adjustment.note},
          );
        } else {
          await _adjustRecursive(
            adjustment.productId,
            difference,
            'ADJUST_FIX',
            adjustment.note,
            null,
            maxDepth: 10,
          );
        }
      }

      for (final sheetId in sheetIds) {
        final closed = await _dbService.execute(
          '''UPDATE shop_work_logs
             SET stock_checked_at = NOW(), stock_checked_by = :checkedBy,
                 stock_check_note = 'ปรับสต๊อกจากผลตรวจนับ S-Link'
             WHERE sync_id = :syncId AND stock_checked_at IS NULL''',
          {'checkedBy': checkedBy, 'syncId': sheetId},
        );
        if (closed.affectedRows.toInt() != 1) {
          throw StateError('ไม่สามารถปิดใบตรวจนับ: $sheetId');
        }
      }
      await _dbService.execute('COMMIT');
    } catch (e) {
      await _dbService.execute('ROLLBACK');
      rethrow;
    }
  }

  // ... (ฟังก์ชัน adjustStock ของเดิม ห้ามลบ เก็บไว้เหมือนเดิม) ...
  Future<bool> adjustStock({
    required int productId,
    required double quantityChange,
    required String type,
    String? note,
    int? orderId,
    bool useTransaction = true,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    if (!_dbService.isConnected()) return false;

    if (useTransaction) {
      await _dbService.execute('START TRANSACTION;');
    }

    try {
      // ✅ Add Max Depth to prevent infinite recursion
      await _adjustRecursive(productId, quantityChange, type, note, orderId,
          maxDepth: 10);

      if (useTransaction) {
        await _dbService.execute('COMMIT;');
      }

      // --- Notification Logic (Fire & Forget) ---
      // ✅ ย้ายออกนอก transaction เพื่อไม่ให้ block
      _checkAndNotify(productId, quantityChange, type, note);

      ActivityRepository().log(
        action: 'ADJUST_STOCK',
        details:
            'Product ID: $productId, Change: $quantityChange, Type: $type, Note: ${note ?? "-"}',
      );

      return true;
    } catch (e) {
      if (useTransaction) {
        await _dbService.execute('ROLLBACK;');
        debugPrint('Error adjusting stock: $e');
        return false;
      } else {
        rethrow;
      }
    }
  }

  /// Marks S-Link count sheets as reviewed only after every item in the sheet
  /// has been applied successfully. This keeps unreviewed sheets available
  /// for retry and prevents a second stock adjustment for the same sheet.
  Future<Set<String>> markShopWorkLogsStockChecked(
    Set<String> syncIds, {
    int? checkedBy,
  }) async {
    if (syncIds.isEmpty) return <String>{};
    if (!_dbService.isConnected()) await _dbService.connect();
    if (!_dbService.isConnected()) {
      throw StateError('ไม่สามารถเชื่อมต่อฐานข้อมูลเพื่อปิดใบตรวจนับได้');
    }

    final closed = <String>{};
    for (final syncId in syncIds) {
      final result = await _dbService.execute(
        '''
        UPDATE shop_work_logs
        SET stock_checked_at = NOW(),
            stock_checked_by = :checkedBy,
            stock_check_note = 'ปรับสต๊อกจากผลตรวจนับ S-Link'
        WHERE sync_id = :syncId AND stock_checked_at IS NULL
        ''',
        {'checkedBy': checkedBy, 'syncId': syncId},
      );
      if (result.affectedRows.toInt() == 1) {
        closed.add(syncId);
        continue;
      }

      // A zero-row update is safe only when this exact sheet was already
      // closed earlier (for example, after an interrupted UI retry).
      final verification = await _dbService.query(
        '''SELECT stock_checked_at FROM shop_work_logs
           WHERE sync_id = :syncId AND stock_checked_at IS NOT NULL''',
        {'syncId': syncId},
      );
      if (verification.isNotEmpty) {
        closed.add(syncId);
      } else {
        throw StateError('ไม่พบใบตรวจนับที่รอปิด: $syncId');
      }
    }
    return closed;
  }

  // Helper สำหรับแจ้งเตือน
  Future<void> _checkAndNotify(
      int productId, double change, String type, String? note) async {
    try {
      Future.microtask(() async {
        final telegram = TelegramService();
        final results = await _dbService.query(
            'SELECT name, stockQuantity, reorderPoint, trackStock FROM product WHERE id = :id',
            {'id': productId});

        if (results.isEmpty) return;
        final product = results.first;
        final String name = product['name'];
        final double stock =
            double.tryParse(product['stockQuantity'].toString()) ?? 0.0;
        final double reorder =
            double.tryParse(product['reorderPoint'].toString()) ?? 0.0;
        final bool track =
            (int.tryParse(product['trackStock'].toString()) ?? 0) == 1;

        // 1. แจ้งเตือนการปรับสต็อก (Stock Adjustment)
        if (['ADJUST_ADD', 'ADJUST_SUB', 'ADJUST_FIX', 'UPDATE_PRODUCT']
            .contains(type)) {
          if (await telegram
              .shouldNotify(TelegramService.keyNotifyStockAdjust)) {
            final msg = '📦 *ปรับสต็อกสินค้า* (Stock Adjust)\n'
                '━━━━━━━━━━━━━━━━━━\n'
                'สินค้า: $name\n'
                'เปลี่ยนแปลง: ${change > 0 ? '+' : ''}$change\n'
                'คงเหลือ: $stock\n'
                'เหตุผล: $type ${note != null ? "($note)" : ""}\n'
                '━━━━━━━━━━━━━━━━━━';
            telegram.sendMessage(msg);
          }
        }

        // 2. แจ้งเตือนสินค้าใกล้หมด (Low Stock)
        if (track && stock <= reorder) {
          if (await telegram.shouldNotify(TelegramService.keyNotifyLowStock)) {
            final msg = '⚠️ *สินค้าใกล้หมด* (Low Stock)\n'
                '━━━━━━━━━━━━━━━━━━\n'
                'สินค้า: $name\n'
                'คงเหลือ: $stock\n'
                'จุดสั่งซื้อ: $reorder\n'
                '━━━━━━━━━━━━━━━━━━';
            telegram.sendMessage(msg);
          }
        }
      });
    } catch (e) {
      debugPrint('Notification Error: $e');
    }
  }

  Future<void> _adjustRecursive(
      int pId, double qty, String type, String? note, int? oId,
      {Set<int>? visited, int maxDepth = 10}) async {
    // 0. ตรวจสอบความปลอดภัย (Safety Checks)
    if (maxDepth <= 0) {
      debugPrint(
          '⚠️ Recursion limit reached for Product #$pId. Stopping to prevent crash.');
      return;
    }

    visited ??= {};
    if (visited.contains(pId)) {
      debugPrint(
          '⚠️ Cycle detected in stock adjustment for Product #$pId. Skipping.');
      return;
    }
    visited.add(pId);

    try {
      // 1. อัปเดตสินค้าปัจจุบัน
      const String updateSql = '''
      UPDATE product 
      SET stockQuantity = stockQuantity + :qty 
      WHERE id = :id;
    ''';
      await _dbService.execute(updateSql, {'qty': qty, 'id': pId});

      // 2. บันทึกบัญชีคุมสินค้า (Ledger)
      const String insertLedgerSql = '''
      INSERT INTO stockledger (productId, transactionType, quantityChange, orderId, note, createdAt)
      VALUES (:pid, :type, :qty, :oid, :note, NOW());
    ''';
      await _dbService.execute(insertLedgerSql, {
        'pid': pId,
        'type': type,
        'qty': qty,
        'oid': oId,
        'note': note,
      });

      // 3. ตรวจสอบส่วนประกอบ (สินค้าที่ผูกกัน)
      final components = await _dbService.query(
        'SELECT child_product_id, quantity FROM product_components WHERE parent_product_id = :pid',
        {'pid': pId},
      );

      if (components.isNotEmpty) {
        for (var comp in components) {
          int childId = int.tryParse(comp['child_product_id'].toString()) ?? 0;
          double ratio = double.tryParse(comp['quantity'].toString()) ?? 0.0;
          double childQtyChange = qty * ratio;

          await _adjustRecursive(
            childId,
            childQtyChange,
            type == 'SALE_OUT'
                ? 'USAGE'
                : (type == 'CART_OUT' ? 'USAGE' : type),
            'Linked from Product #$pId',
            oId,
            visited: Set.from(
                visited), // ✅ Copy per branch — ป้องกัน false-positive cycle detection
            maxDepth: maxDepth - 1,
          );
        }
      }

      // 4. อัปเดตสต็อกแม่ (Parent Stocks)
      await updateParentStocks(pId);
    } finally {
      visited.remove(pId);
    }
  }

  // คำนวณและอัปเดตสต็อกแม่เมื่อลูกเปลี่ยนแปลง
  Future<void> updateParentStocks(int childId) async {
    final parents = await _dbService.query(
      'SELECT DISTINCT parent_product_id FROM product_components WHERE child_product_id = :cid',
      {'cid': childId},
    );

    for (var parent in parents) {
      int parentId = int.tryParse(parent['parent_product_id'].toString()) ?? 0;
      await recalculateParentStock(parentId);
    }
  }

  // ✅ ฟังก์ชั่นใหม่: ปรับสต็อกให้ตรงตามยอดที่นับจริง (แก้ปัญหาบวกทบ)
  Future<bool> updateStockToExact(int productId, double actualQty,
      {String? note}) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    await _dbService.execute('START TRANSACTION;');

    try {
      final res = await _dbService.query(
          'SELECT stockQuantity FROM product WHERE id = :id FOR UPDATE',
          {'id': productId});

      if (res.isEmpty) {
        await _dbService.execute('ROLLBACK;');
        return false;
      }

      double currentStock =
          double.tryParse(res.first['stockQuantity'].toString()) ?? 0.0;
      double diff = actualQty - currentStock;

      if (diff == 0) {
        await _dbService.execute(
          '''
          INSERT INTO stockledger (productId, transactionType, quantityChange, note, createdAt)
          VALUES (:pid, 'ADJUST_FIX', 0, :note, NOW());
          ''',
          {
            'pid': productId,
            'note': note ?? 'Stock Count (Verified)',
          },
        );
        await _dbService.execute('COMMIT;');
        return true;
      }

      await _adjustRecursive(
          productId, diff, 'ADJUST_FIX', note ?? 'Stock Count', null,
          maxDepth: 10);

      await _dbService.execute('COMMIT;');

      _checkAndNotify(productId, diff, 'ADJUST_FIX', note);

      ActivityRepository().log(
        action: 'ADJUST_STOCK_EXACT',
        details:
            'Product ID: $productId, Set to: $actualQty (Diff: $diff), Note: ${note ?? "-"}',
      );

      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error setting exact stock: $e');
      return false;
    }
  }

  Future<void> recalculateParentStock(int parentId) async {
    final components = await _dbService.query(
      '''
      SELECT pc.quantity as ratio, p.stockQuantity as currentStock 
      FROM product_components pc
      JOIN product p ON pc.child_product_id = p.id
      WHERE pc.parent_product_id = :pid
      ''',
      {'pid': parentId},
    );

    if (components.isEmpty) return;

    double maxPossible = double.infinity;

    for (var comp in components) {
      double ratio = double.tryParse(comp['ratio'].toString()) ?? 0.0;
      double stock = double.tryParse(comp['currentStock'].toString()) ?? 0.0;

      if (ratio <= 0) continue;

      double possible = stock / ratio;
      if (possible < maxPossible) {
        maxPossible = possible;
      }
    }

    if (maxPossible != double.infinity) {
      await _dbService.execute(
        'UPDATE product SET stockQuantity = :qty WHERE id = :pid',
        {'qty': maxPossible, 'pid': parentId},
      );
    }
  }
}

class SLinkStockCheckAdjustment {
  const SLinkStockCheckAdjustment({
    required this.productId,
    required this.countedQty,
    required this.note,
    required this.sourceWorkLogIds,
  });

  final int productId;
  final double countedQty;
  final String note;
  final Set<String> sourceWorkLogIds;
}
