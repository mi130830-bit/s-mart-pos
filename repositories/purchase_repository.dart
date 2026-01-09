import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

class PurchaseRepository {
  final MySQLService _db = MySQLService();

  // --- 1. PO Management ---

  Future<int> createPO({
    required int supplierId,
    required int branchId,
    required int? userId,
    required double totalAmount,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    await _db.execute('START TRANSACTION;');
    try {
      // 1. Insert Header
      final res = await _db.execute('''
        INSERT INTO purchase_order (supplierId, branchId, totalAmount, status, userId, note, createdAt)
        VALUES (:sid, :bid, :total, 'DRAFT', :uid, :note, NOW())
      ''', {
        'sid': supplierId,
        'bid': branchId,
        'total': totalAmount,
        'uid': userId,
        'note': note,
      });

      final poId = res.lastInsertID.toInt();

      // 2. Insert Items
      for (var item in items) {
        await _db.execute('''
          INSERT INTO purchase_order_item (poId, productId, productName, quantity, costPrice, total)
          VALUES (:poid, :pid, :pname, :qty, :cost, :total)
        ''', {
          'poid': poId,
          'pid': item['productId'],
          'pname': item['productName'],
          'qty': item['quantity'],
          'cost': item['costPrice'],
          'total': item['total'],
        });
      }

      await _db.execute('COMMIT;');
      return poId;
    } catch (e) {
      await _db.execute('ROLLBACK;');
      debugPrint('Error creating PO: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getPOs({int? branchId}) async {
    String sql = '''
      SELECT po.*, s.name as supplierName, u.displayName as userName
      FROM purchase_order po
      LEFT JOIN supplier s ON po.supplierId = s.id
      LEFT JOIN user u ON po.userId = u.id
    ''';
    if (branchId != null) sql += ' WHERE po.branchId = :bid';
    sql += ' ORDER BY po.createdAt DESC';

    return await _db.query(sql, {if (branchId != null) 'bid': branchId});
  }

  Future<Map<String, dynamic>?> getPODetails(int poId) async {
    final header = await _db
        .query('SELECT * FROM purchase_order WHERE id = :id', {'id': poId});
    if (header.isEmpty) return null;

    final items = await _db.query(
        'SELECT * FROM purchase_order_item WHERE poId = :id', {'id': poId});

    return {
      'header': header.first,
      'items': items,
    };
  }

  // --- 2. Workflow: Receive Stock ---

  Future<bool> receivePO(int poId) async {
    final details = await getPODetails(poId);
    if (details == null) return false;
    if (details['header']['status'] == 'RECEIVED') return false;

    await _db.execute('START TRANSACTION;');
    try {
      final items = details['items'] as List<Map<String, dynamic>>;
      final branchId =
          int.tryParse(details['header']['branchId'].toString()) ?? 1;

      for (var item in items) {
        final productId = int.parse(item['productId'].toString());
        final qty = double.parse(item['quantity'].toString());
        final cost = double.parse(item['costPrice'].toString());

        // Update Stock
        await _db.execute('''
          UPDATE product 
          SET stockQuantity = stockQuantity + :qty, costPrice = :cost
          WHERE id = :pid
        ''', {'qty': qty, 'cost': cost, 'pid': productId});

        // Log Stock Change
        await _db.execute('''
          INSERT INTO stockledger (productId, branchId, transactionType, quantityChange, note, createdAt)
          VALUES (:pid, :bid, 'PO_IN', :qty, :note, NOW())
        ''', {
          'pid': productId,
          'bid': branchId,
          'qty': qty,
          'note': 'รับสินค้าจาก PO #$poId',
        });
      }

      // Update PO Status
      await _db.execute(
          'UPDATE purchase_order SET status = "RECEIVED" WHERE id = :id',
          {'id': poId});

      await _db.execute('COMMIT;');
      return true;
    } catch (e) {
      await _db.execute('ROLLBACK;');
      debugPrint('Error receiving PO: $e');
      return false;
    }
  }
}
