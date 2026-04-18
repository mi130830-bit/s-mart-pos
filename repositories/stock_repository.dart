import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../services/telegram_service.dart';

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
      // ✅ ย้ายออกนอก transaction (เหมือนเดิม) เพื่อไม่ให้ block
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
    // ... (logic remains same, just ensuring it's async safe)
    try {
      // รันใน microtask เพื่อไม่ให้ขัดจังหวะ UI ถ้าเรียกแบบ sync
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
        // ✅ Only notify manual adjustments
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

          // ปรับสต็อกลูกแบบ Recursive
          await _adjustRecursive(
            childId,
            childQtyChange,
            type == 'SALE_OUT'
                ? 'USAGE'
                : (type == 'CART_OUT' ? 'USAGE' : type),
            'Linked from Product #$pId',
            oId,
            visited: visited,
            maxDepth: maxDepth - 1, // ✅ Decrement depth
          );
        }
      }

      // 4. อัปเดตสต็อกแม่ (Parent Stocks)
      // การทำงานส่วนนี้ใช้ทรัพยากรสูง ควรระวัง
      // การปรับปรุง: อาจจะอัปเดตเฉพาะแม่ระดับบนสุด หรือจำกัดความถี่?
      // สำหรับตอนนี้ ให้คง Logic นี้ไว้แต่ต้องแน่ใจว่าจะไม่ค้าง
      await updateParentStocks(pId);
    } finally {
      visited.remove(pId);
    }
  }

  // คำนวณและอัปเดตสต็อกแม่เมื่อลูกเปลี่ยนแปลง
  Future<void> updateParentStocks(int childId) async {
    // ค้นหาแม่ทั้งหมดที่ใช้ลูกตัวนี้
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

    // เริ่ม Transaction
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1. ดึงสต็อก "ณ ปัจจุบันใน DB" ออกมาก่อน (Lock Row เพื่อความชัวร์)
      final res = await _dbService.query(
          'SELECT stockQuantity FROM product WHERE id = :id FOR UPDATE',
          {'id': productId});

      if (res.isEmpty) {
        await _dbService.execute('ROLLBACK;');
        return false;
      }

      double currentStock =
          double.tryParse(res.first['stockQuantity'].toString()) ?? 0.0;

      // 2. คำนวณส่วนต่าง (Diff)
      // เช่น ใน DB มี 40, นับได้ 50 -> Diff = +10
      // ถ้ากดซ้ำ: ใน DB เป็น 50, นับได้ 50 -> Diff = 0 (จะไม่บวกเพิ่มแล้ว)
      double diff = actualQty - currentStock;

      // ถ้าเท่าเดิม (Diff = 0) -> บันทึก Ledger อย่างเดียวว่ามีการเช็คสต็อก
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

      // 3. เรียกใช้ Logic เดิมเพื่อบันทึก Ledger และอัปเดตสต็อก
      // ใช้ type เป็น 'ADJUST_FIX' เพื่อสื่อว่ามาจากการตรวจนับ
      await _adjustRecursive(
          productId, diff, 'ADJUST_FIX', note ?? 'Stock Count', null,
          maxDepth: 10); // ✅ Fix: Pass max depth

      await _dbService.execute('COMMIT;');

      // แจ้งเตือน Telegram
      _checkAndNotify(productId, diff, 'ADJUST_FIX', note);

      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error setting exact stock: $e');
      return false;
    }
  }

  Future<void> recalculateParentStock(int parentId) async {
    // 1. ดึงส่วนประกอบทั้งหมดของแม่ตัวนี้
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

      if (ratio <= 0) continue; // ป้องกันหารด้วยศูนย์

      double possible = stock / ratio;
      if (possible < maxPossible) {
        maxPossible = possible;
      }
    }

    if (maxPossible != double.infinity) {
      // อัปเดตสต็อกแม่
      // เราจะไม่บันทึกลง Ledger เป็น Transaction เพราะนี่คือการอัปเดต "เสมือน" ที่คำนวณจากลูก
      // หรือเราอาจจะบันทึกก็ได้ แต่อาจจะรกเกินไป ให้แค่อัปเดตตารางหลักเพื่อให้ POS เห็นยอดที่ถูกต้อง
      await _dbService.execute(
        'UPDATE product SET stockQuantity = :qty WHERE id = :pid',
        {'qty': maxPossible, 'pid': parentId}, // Store as float/double
      );
    }
  }

  // ✅ แก้ไข: เพิ่ม parameter startDate, endDate, offset
  Future<List<Map<String, dynamic>>> getStockLedger({
    List<String>? types,
    int limit = 20, // เปลี่ยน default เป็น 20
    int offset = 0, // เพิ่ม offset สำหรับเปลี่ยนหน้า
    DateTime? startDate, // เพิ่มวันที่เริ่มต้น
    DateTime? endDate, // เพิ่มวันที่สิ้นสุด
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    if (!_dbService.isConnected()) return [];

    try {
      List<String> conditions = [];
      Map<String, dynamic> params = {
        'limit': limit,
        'offset': offset,
      };

      // 1. กรองประเภท
      if (types != null && types.isNotEmpty) {
        final placeholders = <String>[];
        for (var i = 0; i < types.length; i++) {
          final key = 'type$i';
          placeholders.add(':$key');
          params[key] = types[i];
        }
        conditions.add('sl.transactionType IN (${placeholders.join(',')})');
      }

      // 2. กรองวันที่ (ถ้ามีการส่งมา)
      if (startDate != null && endDate != null) {
        // ตัดเวลาออก ให้เหลือแค่ YYYY-MM-DD 00:00:00 ถึง 23:59:59
        // แต่ใน SQL ถ้าใช้ DATE() จะง่ายกว่า
        conditions.add('DATE(sl.createdAt) BETWEEN :start AND :end');
        params['start'] = startDate.toIso8601String().substring(0, 10);
        params['end'] = endDate.toIso8601String().substring(0, 10);
      }

      String whereClause =
          conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

      final sql = '''
        SELECT sl.*, p.name as productName
        FROM stockledger sl
        LEFT JOIN product p ON sl.productId = p.id
        $whereClause
        ORDER BY sl.createdAt DESC
        LIMIT :limit OFFSET :offset;
      ''';

      return await _dbService.query(sql, params);
    } catch (e) {
      debugPrint('Error fetching stock ledger: $e');
      return [];
    }
  }

  // ✅ แก้ไข: อัปเดตให้รองรับ params ใหม่
  Future<List<Map<String, dynamic>>> getHistoryByType(
    String? type, {
    bool isAdjustment = false,
    int limit = 20,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    List<String>? targetTypes;
    if (isAdjustment) {
      targetTypes = ['ADJUST_ADD', 'ADJUST_SUB', 'ADJUST_FIX'];
    } else if (type != null) {
      targetTypes = [type];
    }

    return await getStockLedger(
      types: targetTypes,
      limit: limit,
      offset: offset,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ... (ฟังก์ชันอื่นๆ getStockInHistory, getStockMovements คงเดิม) ...
  Future<List<Map<String, dynamic>>> getStockMovements(int productId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT * FROM stockledger 
        WHERE productId = :pid 
        ORDER BY createdAt DESC 
        LIMIT 200;
      ''';
      return await _dbService.query(sql, {'pid': productId});
    } catch (e) {
      debugPrint('Error fetching stock card: $e');
      return [];
    }
  }

  // ✅ ดึงข้อมูลการรับเข้าล่าสุด (Last Purchase)
  Future<Map<String, dynamic>?> getLastPurchase(int productId) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (_) {}
    }
    try {
      // note usually stores: "Ref: ... | Sup: Name | Cost: 100"
      // or we can just return the raw note.
      const sql = '''
        SELECT * FROM stockledger 
        WHERE productId = :pid 
        AND transactionType = 'PURCHASE_IN'
        ORDER BY createdAt DESC 
        LIMIT 1;
      ''';
      final res = await _dbService.query(sql, {'pid': productId});
      return res.isNotEmpty ? res.first : null;
    } catch (e) {
      debugPrint('Error getting last purchase: $e');
      return null;
    }
  }

  // ✅ ดึงข้อมูลการรับเข้าที่ราคาดีที่สุด (Best Price) จาก 20 รายการล่าสุด
  Future<Map<String, dynamic>?> getBestPricePurchase(int productId) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (_) {}
    }
    try {
      const sql = '''
        SELECT * FROM stockledger 
        WHERE productId = :pid 
        AND transactionType = 'PURCHASE_IN'
        ORDER BY createdAt DESC 
        LIMIT 20;
      ''';
      final res = await _dbService.query(sql, {'pid': productId});
      if (res.isEmpty) return null;

      Map<String, dynamic>? bestRow;
      double minCost = double.infinity;

      for (var row in res) {
        final note = row['note'].toString();
        if (note.contains('Cost:')) {
          try {
            final costPart = note.split('Cost:')[1].trim();
            final costVal = double.tryParse(costPart) ?? double.infinity;
            if (costVal < minCost && costVal > 0) {
              minCost = costVal;
              bestRow = row;
            }
          } catch (_) {}
        }
      }
      return bestRow;
    } catch (e) {
      debugPrint('Error getting best price purchase: $e');
      return null;
    }
  }

  // ✅ ดึงข้อมูลแนะนำการสั่งซื้อ (Restock Suggestions)
  Future<List<Map<String, dynamic>>> getRestockSuggestions(
      int productId) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (_) {}
    }
    try {
      const sql = '''
        SELECT 
          po.id as poId,
          po.createdAt,
          s.name as supplierName,
          poi.costPrice,
          poi.quantity
        FROM purchase_order_item poi
        JOIN purchase_order po ON poi.poId = po.id
        LEFT JOIN supplier s ON po.supplierId = s.id
        WHERE poi.productId = :pid
        AND po.status != 'CANCELLED'
        ORDER BY po.createdAt DESC
        LIMIT 50; 
      ''';
      return await _dbService.query(sql, {'pid': productId});
    } catch (e) {
      debugPrint('Error getting restock suggestions: $e');
      return [];
    }
  }
  // ---------------------------------------------------------------------------
  // การจัดการใบสั่งซื้อ (PO - Purchase Order)
  // ---------------------------------------------------------------------------

  Future<int> createPurchaseOrder({
    required int supplierId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? documentNo,
    String? note,
    String status = 'DRAFT',
    int vatType = 0, // 0=Included, 1=Excluded, 2=NoVAT
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1. Insert Header
      final res = await _dbService.execute(
        '''
        INSERT INTO purchase_order (supplierId, documentNo, totalAmount, status, note, vatType, createdAt)
        VALUES (:supId, :docNo, :total, :status, :note, :vat, NOW())
        ''',
        {
          'supId': supplierId,
          'docNo': documentNo,
          'total': totalAmount,
          'status': status,
          'note': note,
          'vat': vatType, // New Param
        },
      );
      final poId = res.lastInsertID.toInt();

      // 2. Insert Items
      for (var item in items) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final recvQty = (status == 'RECEIVED') ? qty : 0.0;
        await _dbService.execute(
          '''
          INSERT INTO purchase_order_item (poId, productId, productName, quantity, receivedQuantity, costPrice, total)
          VALUES (:poId, :pId, :pName, :qty, :recvQty, :cost, :total)
          ''',
          {
            'poId': poId,
            'pId': item['productId'],
            'pName': item['productName'],
            'qty': qty,
            'recvQty': recvQty,
            'cost': item['costPrice'],
            'total': item['total'],
          },
        );
      }

      // 3. If Status is RECEIVED (Ad-hoc Receive), process stock immediately
      if (status == 'RECEIVED') {
        for (var item in items) {
          final pId = int.tryParse(item['productId'].toString()) ?? 0;
          final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
          final doc = documentNo ?? '-';

          if (pId == 0) continue; // Skip invalid items

          // Use the internal adjust but skip transaction (already in one)
          await _adjustRecursive(
            pId,
            qty,
            'PURCHASE_IN',
            'Ref: $doc | Cost: $cost | PO: #$poId', // Note format
            null, // orderId is for Sales usually, can reuse for PO ID if needed but logic differs
          );

          // Update Cost & Stock directly (Main Product)
          await _dbService.execute(
            'UPDATE product SET costPrice = :cost WHERE id = :id',
            {'cost': cost, 'id': pId},
          );
        }
      }

      await _dbService.execute('COMMIT;');
      return poId;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error creating PO: $e');
      rethrow;
    }
  }

  Future<void> updatePurchaseOrder({
    required int poId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? documentNo,
    String? note,
    String status = 'ORDERED',
    int vatType = 0,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // 0. Check Previous Status & Items (For Stock Reversal)
      final oldPoRes = await _dbService.query(
        'SELECT status FROM purchase_order WHERE id = :id FOR UPDATE',
        {'id': poId},
      );

      if (oldPoRes.isNotEmpty) {
        final oldStatus = oldPoRes.first['status'];

        if (oldStatus == 'RECEIVED' || oldStatus == 'PARTIAL') {
          // Revert old stock BEFORE deleting items
          final oldItems = await _dbService.query(
            'SELECT productId, quantity, receivedQuantity FROM purchase_order_item WHERE poId = :id',
            {'id': poId},
          );

          for (var item in oldItems) {
            final pId = int.tryParse(item['productId'].toString()) ?? 0;
            double revertQty = 0.0;
            if (oldStatus == 'RECEIVED') {
              revertQty = double.tryParse(item['quantity'].toString()) ?? 0.0;
            } else if (oldStatus == 'PARTIAL') {
              revertQty = double.tryParse(item['receivedQuantity'].toString()) ?? 0.0;
            }

            if (pId > 0 && revertQty > 0) {
              await _adjustRecursive(
                pId,
                -revertQty, // Negative to reverse
                'ADJUST_CORRECT',
                'Edit PO #$poId (Reversal)',
                null,
              );
            }
          }
        }
      }

      // 1. Update Header
      await _dbService.execute(
        '''
        UPDATE purchase_order 
        SET totalAmount = :total, documentNo = :docNo, note = :note, status = :status, vatType = :vat,
            updatedAt = NOW()
        WHERE id = :id
        ''',
        {
          'total': totalAmount,
          'docNo': documentNo,
          'note': note,
          'status': status,
          'vat': vatType,
          'id': poId,
        },
      );

      // 2. Clear Old Items
      await _dbService.execute(
        'DELETE FROM purchase_order_item WHERE poId = :id',
        {'id': poId},
      );

      // 3. Insert New Items
      for (var item in items) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final recvQty = (status == 'RECEIVED') ? qty : 0.0;
        await _dbService.execute(
          '''
          INSERT INTO purchase_order_item (poId, productId, productName, quantity, receivedQuantity, costPrice, total)
          VALUES (:poId, :pId, :pName, :qty, :recvQty, :cost, :total)
          ''',
          {
            'poId': poId,
            'pId': item['productId'],
            'pName': item['productName'],
            'qty': qty,
            'recvQty': recvQty,
            'cost': item['costPrice'],
            'total': item['total'],
          },
        );
      }

      // 4. If Status is RECEIVED, process stock now
      if (status == 'RECEIVED') {
        // We reuse the logic from createPurchaseOrder (copy-paste logic for safety or refactor later)
        // Since we already inserted items, we can iterate 'items' map directly loop
        for (var item in items) {
          final pId = int.tryParse(item['productId'].toString()) ?? 0;
          final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
          final doc = documentNo ?? '-';

          if (pId == 0) continue;

          // Adjust Stock (Internal)
          await _adjustRecursive(
            pId,
            qty,
            'PURCHASE_IN',
            'Ref: $doc | Cost: $cost | PO: #$poId', // Note format
            null,
          );

          // Update Cost & Stock directly (Main Product)
          await _dbService.execute(
            'UPDATE product SET costPrice = :cost WHERE id = :id',
            {'cost': cost, 'id': pId},
          );
        }

        // Notification Logic injected here or by caller?
        // Caller (UI) can't easily do it for each item.
        // But adjustRecursive has manual notification injection?
        // No, I added `_checkAndNotify` in `adjustStock` wrapper, NOT in `_adjustRecursive`.
        // So I must call `_checkAndNotify` here manually if I want alerts.
        for (var item in items) {
          final pId = int.tryParse(item['productId'].toString()) ?? 0;
          final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          if (pId != 0) {
            _checkAndNotify(pId, qty, 'PURCHASE_IN', 'PO #$poId');
          }
        }
      }

      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error updating PO: $e');
      rethrow;
    }
  }

  Future<void> receivePurchaseOrder(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    // Get PO Items
    final items = await _dbService.query(
        'SELECT * FROM purchase_order_item WHERE poId = :id', {'id': poId});
    final header = await _dbService
        .query('SELECT * FROM purchase_order WHERE id = :id', {'id': poId});

    if (items.isEmpty || header.isEmpty) throw Exception('PO not found');

    final docNo = header.first['documentNo'] ?? '-';

    // Queue for notifications
    final List<Map<String, dynamic>> notifyQueue = [];

    await _dbService.execute('START TRANSACTION;');

    try {
      for (var item in items) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;

        if (pId == 0) continue;

        // Adjust Stock (with depth limit)
        await _adjustRecursive(
          pId,
          qty,
          'PURCHASE_IN',
          'Ref: $docNo | Cost: $cost | PO: #$poId',
          null,
          maxDepth: 10,
        );

        // Update Cost
        await _dbService.execute(
          'UPDATE product SET costPrice = :cost WHERE id = :id',
          {'cost': cost, 'id': pId},
        );

        notifyQueue.add({
          'id': pId,
          'qty': qty,
          'type': 'PURCHASE_IN',
          'note': 'PO #$poId'
        });
      }

      // Update Status
      await _dbService.execute(
        "UPDATE purchase_order SET status = 'RECEIVED', updatedAt = NOW() WHERE id = :id",
        {'id': poId},
      );

      await _dbService.execute('COMMIT;');

      // ✅ Send Notifications AFTER Commit
      for (var n in notifyQueue) {
        _checkAndNotify(n['id'], n['qty'], n['type'], n['note']);
      }
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      rethrow;
    }
  }

  // ✅ New Method: Delete (Cancel) Purchase Order
  Future<void> deletePurchaseOrder(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // 1. Check Status
    final headerRes = await _dbService.query(
        'SELECT status FROM purchase_order WHERE id = :id', {'id': poId});
    if (headerRes.isEmpty) return; // Not found

    final status = headerRes.first['status'];
    if (status == 'CANCELLED') return; // Already cancelled

    // 2. Start Transaction
    await _dbService.execute('START TRANSACTION;');

    try {
      // 3. If RECEIVED or PARTIAL, Revert Stock
      if (status == 'RECEIVED' || status == 'PARTIAL') {
        final items = await _dbService.query(
            'SELECT productId, quantity, receivedQuantity FROM purchase_order_item WHERE poId = :id',
            {'id': poId});

        for (var item in items) {
          final pId = int.tryParse(item['productId'].toString()) ?? 0;
          double revertQty = 0.0;
          if (status == 'RECEIVED') {
            revertQty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          } else if (status == 'PARTIAL') {
            revertQty = double.tryParse(item['receivedQuantity'].toString()) ?? 0.0;
          }

          if (pId > 0 && revertQty > 0) {
            // Revert Stock (Negative Quantity)
            await _adjustRecursive(
              pId,
              -revertQty, // Decrease Stock
              'ADJUST_CORRECT', // Type
              'Void PO #$poId', // Note
              null,
            );
          }
        }
      }

      // 4. Update Status to CANCELLED
      await _dbService.execute(
        "UPDATE purchase_order SET status = 'CANCELLED', updatedAt = NOW() WHERE id = :id",
        {'id': poId},
      );

      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error deleting PO: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrders({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? supplierId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    final List<String> conditions = [];
    final params = <String, dynamic>{'limit': limit, 'offset': offset};

    if (status != null) {
      conditions.add('po.status = :status');
      params['status'] = status;
    }

    if (startDate != null) {
      conditions.add('po.createdAt >= :startDate');
      params['startDate'] = startDate.toIso8601String();
    }

    if (endDate != null) {
      conditions.add('po.createdAt <= :endDate');
      params['endDate'] = endDate.toIso8601String();
    }

    if (supplierId != null) {
      conditions.add('po.supplierId = :supplierId');
      params['supplierId'] = supplierId;
    }

    String whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(" AND ")}' : '';

    final sql = '''
      SELECT po.id, po.supplierId, po.documentNo, po.totalAmount, po.status,
             po.note, po.vatType, po.createdAt, po.updatedAt,
             s.name as supplierName, 
             (SELECT COUNT(*) FROM purchase_order_item WHERE poId = po.id) as itemCount
      FROM purchase_order po
      LEFT JOIN supplier s ON po.supplierId = s.id
      $whereClause
      ORDER BY po.createdAt DESC
      LIMIT :limit OFFSET :offset
    ''';

    return await _dbService.query(sql, params);
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrderItems(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    const sql = '''
      SELECT * FROM purchase_order_item WHERE poId = :id
    ''';
    return await _dbService.query(sql, {'id': poId});
  }

  // ✅ New Method: Get Single PO by ID
  Future<Map<String, dynamic>?> getPurchaseOrderById(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    final sql = '''
      SELECT po.*, s.name as supplierName, 
             (SELECT COUNT(*) FROM purchase_order_item WHERE poId = po.id) as itemCount
      FROM purchase_order po
      LEFT JOIN supplier s ON po.supplierId = s.id
      WHERE po.id = :id
    ''';

    final res = await _dbService.query(sql, {'id': id});
    return res.isNotEmpty ? res.first : null;
  }

  // ✅ [Partial Receive] Tracked Receipt Logic
  Future<int> receivePartialPurchaseOrder({
    required int originalPoId,
    required List<Map<String, dynamic>>
        receivedItems, // {productId, quantity (this time), costPrice}
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    if (receivedItems.isEmpty) throw Exception('No items to receive');

    await _dbService.execute('START TRANSACTION;');

    try {
      final docNoRes = await _dbService.query(
          'SELECT documentNo FROM purchase_order WHERE id = :id',
          {'id': originalPoId});
      final docNo = docNoRes.isNotEmpty ? docNoRes.first['documentNo'] : '-';

      // 1. Process Received Items
      for (var item in receivedItems) {
        final int pId = int.tryParse(item['productId'].toString()) ?? 0;
        final double qtyReceivedNow =
            double.tryParse(item['quantity'].toString()) ?? 0;
        final double cost = double.tryParse(item['costPrice'].toString()) ?? 0;

        if (pId == 0 || qtyReceivedNow <= 0) continue;

        // 1.1 Update 'receivedQuantity' in purchase_order_item
        // We add to existing receivedQuantity
        await _dbService.execute(
          '''
          UPDATE purchase_order_item 
          SET receivedQuantity = receivedQuantity + :qty,
              costPrice = :cost, 
              total = quantity * :cost 
          WHERE poId = :poId AND productId = :pId
          ''',
          {
            'qty': qtyReceivedNow,
            'cost': cost,
            'poId': originalPoId,
            'pId': pId,
          },
        );
        // Note: Updating 'total' here might be tricky if cost changes.
        // Standard PO: Total = Quantity * Cost. If Cost changes, Total changes.
        // Let's assume we update cost to latest.

        // 1.2 Adjust Stock (Real Inventory)
        await _adjustRecursive(
          pId,
          qtyReceivedNow,
          'PURCHASE_IN',
          'Ref: $docNo | Cost: $cost | PO: #$originalPoId (Partial)',
          null,
        );

        // 1.3 Update Master Product Cost
        await _dbService.execute(
          'UPDATE product SET costPrice = :cost WHERE id = :id',
          {'cost': cost, 'id': pId},
        );
      }

      // 2. Check & Update PO Status
      // Logic:
      // - If ALL items have receivedQuantity >= quantity -> RECEIVED
      // - If ANY item has receivedQuantity > 0 -> PARTIAL
      // - Else -> ORDERED

      final itemsRes = await _dbService.query(
        'SELECT quantity, receivedQuantity FROM purchase_order_item WHERE poId = :id',
        {'id': originalPoId},
      );

      bool allCompleted = true;
      bool anyReceived = false;

      for (var row in itemsRes) {
        double qty = double.tryParse(row['quantity'].toString()) ?? 0;
        double recv = double.tryParse(row['receivedQuantity'].toString()) ?? 0;

        if (recv > 0) anyReceived = true;
        if (recv < qty) allCompleted = false;
      }

      String newStatus = 'ORDERED';
      if (allCompleted && itemsRes.isNotEmpty) {
        newStatus = 'RECEIVED';
      } else if (anyReceived) {
        newStatus = 'PARTIAL';
      }

      await _dbService.execute(
        'UPDATE purchase_order SET status = :status, updatedAt = NOW() WHERE id = :id',
        {'status': newStatus, 'id': originalPoId},
      );

      await _dbService.execute('COMMIT;');
      return originalPoId;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error partial receiving PO: $e');
      rethrow;
    }
  }

  // ✅ New Method: Close Partial Purchase Order (Drop unreceived items)
  Future<void> closePartialPurchaseOrder(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    
    // Check status
    final headerRes = await _dbService.query('SELECT status FROM purchase_order WHERE id = :id', {'id': poId});
    if (headerRes.isEmpty || headerRes.first['status'] != 'PARTIAL') return;
    
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1. Delete items with 0 receivedQuantity
      await _dbService.execute(
        'DELETE FROM purchase_order_item WHERE poId = :id AND receivedQuantity <= 0',
        {'id': poId}
      );

      // 2. Adjust quantity to match receivedQuantity and update total
      await _dbService.execute(
        '''
        UPDATE purchase_order_item 
        SET quantity = receivedQuantity,
            total = receivedQuantity * costPrice
        WHERE poId = :id AND receivedQuantity > 0
        ''',
        {'id': poId}
      );

      // 3. Recalculate and update PO totalAmount
      final totalRes = await _dbService.query(
        'SELECT SUM(total) as newTotal FROM purchase_order_item WHERE poId = :id',
         {'id': poId}
      );
      
      double newTotal = 0.0;
      if (totalRes.isNotEmpty && totalRes.first['newTotal'] != null) {
        newTotal = double.tryParse(totalRes.first['newTotal'].toString()) ?? 0.0;
      }
      
      final vatRes = await _dbService.query('SELECT vatType FROM purchase_order WHERE id = :id', {'id': poId});
      int vatType = 0;
      if (vatRes.isNotEmpty) vatType = int.tryParse(vatRes.first['vatType'].toString()) ?? 0;
      
      if (vatType == 1) { // Excluded
        newTotal = newTotal * 1.07;
      }

      await _dbService.execute(
        "UPDATE purchase_order SET status = 'RECEIVED', totalAmount = :total, updatedAt = NOW() WHERE id = :id",
        {'id': poId, 'total': newTotal}
      );

      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error closing partial PO: $e');
      rethrow;
    }
  }

  // ✅ แก้ไขจำนวนในใบรับเข้าที่ RECEIVED แล้ว (พร้อมคำนวณต้นทุนใหม่)
  Future<void> updateReceivedPurchaseOrderQty({
    required int poId,
    required List<Map<String, dynamic>>
        newItems, // {productId, productName, quantity, costPrice}
    required double totalAmount,
    String? documentNo,
    String? note,
    int vatType = 0,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // ── 1. อ่านรายการเดิมก่อน Revert ────────────────────────────────────
      final oldItems = await _dbService.query(
        'SELECT productId, quantity, costPrice FROM purchase_order_item WHERE poId = :id FOR UPDATE',
        {'id': poId},
      );

      final docNo = documentNo ?? '-';

      // ── 2. Revert stock เดิมออก (ลบออกจาก stock ก่อน) ──────────────────
      for (var item in oldItems) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final oldQty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        if (pId > 0 && oldQty > 0) {
          await _adjustRecursive(
            pId,
            -oldQty, // ลบของเก่าออก
            'ADJUST_CORRECT',
            'Edit PO #$poId (Revert Old)',
            null,
          );
        }
      }

      // ── 3. ลบ items เก่าออก แล้ว insert ใหม่ ────────────────────────────
      await _dbService.execute(
        'DELETE FROM purchase_order_item WHERE poId = :id',
        {'id': poId},
      );

      for (var item in newItems) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        final total = qty * cost;
        await _dbService.execute(
          '''
          INSERT INTO purchase_order_item (poId, productId, productName, quantity, receivedQuantity, costPrice, total)
          VALUES (:poId, :pId, :pName, :qty, :recvQty, :cost, :total)
          ''',
          {
            'poId': poId,
            'pId': item['productId'],
            'pName': item['productName'],
            'qty': qty,
            'recvQty': qty,
            'cost': cost,
            'total': total,
          },
        );
      }

      // ── 4. เพิ่ม stock ใหม่ตามจำนวนที่แก้ไข ──────────────────────────────
      for (var item in newItems) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;

        if (pId == 0 || qty <= 0) continue;

        await _adjustRecursive(
          pId,
          qty, // บวก stock ใหม่
          'PURCHASE_IN',
          'Ref: $docNo | Cost: $cost | PO: #$poId (Edited)',
          null,
        );

        // ── 5. อัปเดตต้นทุนสินค้า (weighted average หรือ latest cost) ──
        // ใช้ latest cost (simple) ซึ่งเป็น standard สำหรับระบบ POS นี้
        await _dbService.execute(
          'UPDATE product SET costPrice = :cost WHERE id = :id',
          {'cost': cost, 'id': pId},
        );
      }

      // ── 6. อัปเดต header ──────────────────────────────────────────────────
      // คำนวณยอดรวมใหม่ (sum จาก newItems)
      double recalcTotal = newItems.fold(0.0, (sum, item) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        return sum + (qty * cost);
      });
      // ถ้า caller ส่ง totalAmount มาให้ใช้ ถ้าไม่ก็ใช้ที่คำนวณ
      final finalTotal = totalAmount > 0 ? totalAmount : recalcTotal;

      await _dbService.execute(
        '''
        UPDATE purchase_order 
        SET totalAmount = :total, vatType = :vat, note = :note,
            updatedAt = NOW()
        WHERE id = :id
        ''',
        {
          'total': finalTotal,
          'vat': vatType,
          'note': note,
          'id': poId,
        },
      );

      await _dbService.execute('COMMIT;');

      // ── 7. Telegram notification ──────────────────────────────────────────
      for (var item in newItems) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        if (pId != 0 && qty > 0) {
          _checkAndNotify(pId, qty, 'PURCHASE_IN', 'แก้ไข PO #$poId');
        }
      }
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error updating received PO qty: $e');
      rethrow;
    }
  }

  // ✅ New Method: Delete Adjustment Group (Revert Stock)
  Future<void> deleteAdjustmentGroup(List<int> ledgerIds) async {
    if (ledgerIds.isEmpty) return;

    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // Loop to fetch and revert one by one
      for (var id in ledgerIds) {
        final res = await _dbService.query(
            'SELECT * FROM stockledger WHERE id = :id FOR UPDATE', {'id': id});
        if (res.isEmpty) continue;

        final row = res.first;
        final pId = int.tryParse(row['productId'].toString()) ?? 0;
        final qtyChange =
            double.tryParse(row['quantityChange'].toString()) ?? 0.0;

        // Revert Stock if product is valid and qty is non-zero
        // Note: For ADJUST_FIX (Diff=0), qtyChange is 0, so no stock reversion needed, just delete ledger.
        if (pId != 0 && qtyChange != 0) {
          await _adjustRecursive(
              pId,
              -qtyChange, // Invert value
              'ADJUST_CORRECT', // Special type for correction
              'Undo #$id',
              null,
              maxDepth: 10);
        }

        // Delete Ledger Entry
        await _dbService
            .execute('DELETE FROM stockledger WHERE id = :id', {'id': id});
      }

      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error deleting adjustment group: $e');
      rethrow;
    }
  }
}
