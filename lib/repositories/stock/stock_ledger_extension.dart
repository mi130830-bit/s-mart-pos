part of '../stock_repository.dart';

extension StockLedgerExtension on StockRepository {
  // ✅ แก้ไข: เพิ่ม parameter startDate, endDate, offset
  Future<List<Map<String, dynamic>>> getStockLedger({
    List<String>? types,
    int limit = 20,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
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

  Future<void> deleteAdjustmentGroup(List<int> ledgerIds) async {
    if (ledgerIds.isEmpty) return;
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      for (var id in ledgerIds) {
        final res = await _dbService.query(
            'SELECT * FROM stockledger WHERE id = :id FOR UPDATE', {'id': id});
        if (res.isEmpty) continue;

        final row = res.first;
        final pId = int.tryParse(row['productId'].toString()) ?? 0;
        final qtyChange =
            double.tryParse(row['quantityChange'].toString()) ?? 0.0;

        if (pId != 0 && qtyChange != 0) {
          await _adjustRecursive(pId, -qtyChange, 'ADJUST_CORRECT', 'Undo #$id',
              null,
              maxDepth: 10);
        }
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
