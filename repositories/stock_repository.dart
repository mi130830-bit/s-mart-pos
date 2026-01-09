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
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    if (!_dbService.isConnected()) return false;

    // Use a single transaction for parent + all children
    await _dbService.execute('START TRANSACTION;');

    try {
      await _adjustRecursive(productId, quantityChange, type, note, orderId);
      await _dbService.execute('COMMIT;');

      // --- Notification Logic (Fire & Forget) ---
      _checkAndNotify(productId, quantityChange, type, note);

      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error adjusting stock: $e');
      return false;
    }
  }

  // Helper for notifications
  Future<void> _checkAndNotify(
      int productId, double change, String type, String? note) async {
    try {
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

      // 1. Stock Adjustment Notification (Skip Sales/Cart)
      if (type != 'SALE_OUT' && type != 'CART_OUT') {
        if (await telegram.shouldNotify(TelegramService.keyNotifyStockAdjust)) {
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

      // 2. Low Stock Notification
      if (track && stock <= reorder) {
        if (await telegram.shouldNotify(TelegramService.keyNotifyLowStock)) {
          // Basic throttle check could be here, but for now simple trigger
          final msg = '⚠️ *สินค้าใกล้หมด* (Low Stock)\n'
              '━━━━━━━━━━━━━━━━━━\n'
              'สินค้า: $name\n'
              'คงเหลือ: $stock\n'
              'จุดสั่งซื้อ: $reorder\n'
              '━━━━━━━━━━━━━━━━━━';
          telegram.sendMessage(msg);
        }
      }
    } catch (e) {
      debugPrint('Notification Error: $e');
    }
  }

  Future<void> _adjustRecursive(
      int pId, double qty, String type, String? note, int? oId) async {
    // 1. Update Current Product
    const String updateSql = '''
      UPDATE product 
      SET stockQuantity = stockQuantity + :qty 
      WHERE id = :id;
    ''';
    await _dbService.execute(updateSql, {'qty': qty, 'id': pId});

    // 2. Insert Ledger
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

    // 3. Check for Components (Linked Products)
    // Only deduct components if we are SELLING (reducing stock)
    // If we are adding stock (e.g. cancelling order), we should arguably add components back too?
    // User logic implies "Linkage" = automatic deduction. Usually applies to both directions for strict inventory.
    final components = await _dbService.query(
      'SELECT child_product_id, quantity FROM product_components WHERE parent_product_id = :pid',
      {'pid': pId},
    );

    if (components.isNotEmpty) {
      for (var comp in components) {
        int childId = int.tryParse(comp['child_product_id'].toString()) ?? 0;
        double ratio = double.tryParse(comp['quantity'].toString()) ?? 0.0;
        double childQtyChange = qty * ratio; // Proportional change

        // Recursively adjust child (Pass 'LINKED' as transaction type or append to note)
        // We use the same 'type' (e.g. SALE_OUT) so it flows logically, or maybe 'COMPONENT_USAGE'
        // For simple recursion, let's keep it simple or ensure infinite loops don't happen (DAG expected).
        await _adjustRecursive(
            childId,
            childQtyChange,
            type == 'SALE_OUT'
                ? 'USAGE'
                : (type == 'CART_OUT' ? 'USAGE' : type),
            'Linked from Product #$pId',
            oId);
      }
    }

    // 4. Reverse Linkage: Update Parents who use THIS product as component
    // If we just adjusted 'pId', it might be a child of someone else.
    // We need to recalculate THEIR stock.
    await _updateParentStocks(pId);
  }

  // Recalculate and update parents when child stock changes
  Future<void> _updateParentStocks(int childId) async {
    // Find all parents that use this child
    final parents = await _dbService.query(
      'SELECT DISTINCT parent_product_id FROM product_components WHERE child_product_id = :cid',
      {'cid': childId},
    );

    for (var parent in parents) {
      int parentId = int.tryParse(parent['parent_product_id'].toString()) ?? 0;
      await _recalculateParentStock(parentId);
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

      // ถ้าเท่าเดิม ไม่ต้องทำอะไร
      if (diff == 0) {
        await _dbService.execute('COMMIT;');
        return true;
      }

      // 3. เรียกใช้ Logic เดิมเพื่อบันทึก Ledger และอัปเดตสต็อก
      // ใช้ type เป็น 'ADJUST_FIX' เพื่อสื่อว่ามาจากการตรวจนับ
      await _adjustRecursive(
          productId, diff, 'ADJUST_FIX', note ?? 'Stock Count', null);

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

  Future<void> _recalculateParentStock(int parentId) async {
    // 1. Get all components of this parent
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

      if (ratio <= 0) continue; // Avoid div by zero

      double possible = stock / ratio;
      if (possible < maxPossible) {
        maxPossible = possible;
      }
    }

    if (maxPossible != double.infinity) {
      // Update Parent Stock
      // We don't log this to ledger as a transaction because it's a "virtual" update derived from components.
      // Or we could, but it might spam. Let's just update the master table so POS sees correct Qty.
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
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // note usually stores: "Ref: ... | Sup: Name | Cost: 100"
      // or we can just return the note and let UI parse, or try to be smarter.
      // For now, allow retrieving the raw note.
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
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // Note parsing is tricky in SQL directly if format is text.
      // So we fetch last 20 PURCHASE_IN, parse in Dart, and find min cost.
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
        // Expected format: "Ref: ... | Sup: ... | Cost: 100.0000"
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
  // คืนค่า List ของประวัติการซื้อ พร้อม Supplier และ ราคา
  Future<List<Map<String, dynamic>>> getRestockSuggestions(
      int productId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
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
  // Purchase Order (PO) Management
  // ---------------------------------------------------------------------------

  Future<int> createPurchaseOrder({
    required int supplierId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? documentNo,
    String? note,
    String status = 'DRAFT',
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1. Insert Header
      final res = await _dbService.execute(
        '''
        INSERT INTO purchase_order (supplierId, documentNo, totalAmount, status, note, createdAt)
        VALUES (:supId, :docNo, :total, :status, :note, NOW())
        ''',
        {
          'supId': supplierId,
          'docNo': documentNo,
          'total': totalAmount,
          'status': status,
          'note': note,
        },
      );
      final poId = res.lastInsertID.toInt();

      // 2. Insert Items
      for (var item in items) {
        await _dbService.execute(
          '''
          INSERT INTO purchase_order_item (poId, productId, productName, quantity, costPrice, total)
          VALUES (:poId, :pId, :pName, :qty, :cost, :total)
          ''',
          {
            'poId': poId,
            'pId': item['productId'],
            'pName': item['productName'],
            'qty': item['quantity'],
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
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      // 1. Update Header
      await _dbService.execute(
        '''
        UPDATE purchase_order 
        SET totalAmount = :total, documentNo = :docNo, note = :note, status = :status
        WHERE id = :id
        ''',
        {
          'total': totalAmount,
          'docNo': documentNo,
          'note': note,
          'status': status,
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
        await _dbService.execute(
          '''
          INSERT INTO purchase_order_item (poId, productId, productName, quantity, costPrice, total)
          VALUES (:poId, :pId, :pName, :qty, :cost, :total)
          ''',
          {
            'poId': poId,
            'pId': item['productId'],
            'pName': item['productName'],
            'qty': item['quantity'],
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

    await _dbService.execute('START TRANSACTION;');

    try {
      for (var item in items) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;

        if (pId == 0) continue;

        // Adjust Stock
        await _adjustRecursive(
          pId,
          qty,
          'PURCHASE_IN',
          'Ref: $docNo | Cost: $cost | PO: #$poId',
          null,
        );

        // Update Cost
        await _dbService.execute(
          'UPDATE product SET costPrice = :cost WHERE id = :id',
          {'cost': cost, 'id': pId},
        );
      }

      // Update Status
      await _dbService.execute(
        "UPDATE purchase_order SET status = 'RECEIVED', updatedAt = NOW() WHERE id = :id",
        {'id': poId},
      );

      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrders({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    String where = '';
    final params = <String, dynamic>{'limit': limit, 'offset': offset};

    if (status != null) {
      where = 'WHERE po.status = :status';
      params['status'] = status;
    }

    final sql = '''
      SELECT po.*, s.name as supplierName, 
             (SELECT COUNT(*) FROM purchase_order_item WHERE poId = po.id) as itemCount
      FROM purchase_order po
      LEFT JOIN supplier s ON po.supplierId = s.id
      $where
      ORDER BY po.createdAt DESC
      LIMIT :limit OFFSET :offset
    ''';

    return await _dbService.query(sql, params);
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrderItems(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    return await _dbService.query(
      'SELECT * FROM purchase_order_item WHERE poId = :id',
      {'id': poId},
    );
  }
}
