import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../services/telegram_service.dart';

part 'stock/stock_ledger_extension.dart';
part 'stock/purchase_order_extension.dart';

class StockRepository {
  final MySQLService _dbService = MySQLService();

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
            visited: Set.from(visited), // ✅ Copy per branch — ป้องกัน false-positive cycle detection
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
