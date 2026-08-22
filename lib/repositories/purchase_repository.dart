import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../services/idempotency_payload.dart';
import 'stock_repository.dart';

class PurchaseRepository {
  final MySQLService _db = MySQLService();
  final StockRepository _stockRepository = StockRepository();

  // --- 1. PO Management ---

  Future<int> createPO({
    required String idempotencyKey,
    required int supplierId,
    required int branchId,
    required int? userId,
    required double totalAmount,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    if (idempotencyKey.trim().isEmpty || idempotencyKey.length > 64) {
      throw ArgumentError.value(
          idempotencyKey, 'idempotencyKey', 'ต้องเป็นรหัส UUID ที่ถูกต้อง');
    }
    await _db.ensurePurchaseOrderColumns();
    final payloadHash = canonicalPayloadHash({
      'supplierId': supplierId,
      'branchId': branchId,
      'userId': userId,
      'totalAmount': totalAmount.toStringAsFixed(4),
      'note': note ?? '',
      'items': items
          .map((item) => {
                'productId': item['productId'],
                'productName': item['productName'],
                'quantity': item['quantity'],
                'costPrice': item['costPrice'],
                'total': item['total'],
              })
          .toList(),
    });

    Future<int?> reconcile() async {
      final rows = await _db.query('''
        SELECT id, idempotencyPayloadHash FROM purchase_order
        WHERE idempotencyKey = :key LIMIT 1
      ''', {'key': idempotencyKey});
      if (rows.isEmpty) return null;
      if (rows.first['idempotencyPayloadHash']?.toString() != payloadHash) {
        throw StateError('รหัสคำสั่งซื้อเดิมถูกใช้กับข้อมูลคนละชุด');
      }
      return int.parse(rows.first['id'].toString());
    }

    try {
      return await _db.runExclusiveTransaction(() async {
        final existing = await reconcile();
        if (existing != null) return existing;
        await _db.execute('START TRANSACTION');
        try {
          final res = await _db.execute('''
            INSERT INTO purchase_order
              (supplierId, branchId, totalAmount, status, userId, note,
               idempotencyKey, idempotencyPayloadHash, createdAt)
            VALUES (:sid, :bid, :total, 'DRAFT', :uid, :note,
                    :idempotencyKey, :payloadHash, NOW())
          ''', {
            'sid': supplierId,
            'bid': branchId,
            'total': totalAmount,
            'uid': userId,
            'note': note,
            'idempotencyKey': idempotencyKey,
            'payloadHash': payloadHash,
          });
          final poId = res.lastInsertID.toInt();

          for (final item in items) {
            await _db.execute('''
              INSERT INTO purchase_order_item
                (poId, productId, productName, quantity, costPrice, total)
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

          await _db.execute('COMMIT');
          return poId;
        } catch (_) {
          try {
            await _db.execute('ROLLBACK');
          } catch (_) {
            // A lost reply is reconciled using the operation key below.
          }
          rethrow;
        }
      });
    } catch (e) {
      final existing = await reconcile();
      if (existing != null) return existing;
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

  /// Legacy supplier UI delegates to the safe receipt flow.  The operation key
  /// must stay unchanged while the user retries after a lost network response.
  Future<bool> receivePO(int poId, {required String operationKey}) async {
    try {
      await _stockRepository.receiveRemainingPurchaseOrder(
        poId: poId,
        operationKey: operationKey,
      );
      return true;
    } catch (e) {
      debugPrint('Error receiving legacy PO: $e');
      return false;
    }
  }

  Future<double> getTotalPurchasesByDateRange(
      DateTime start, DateTime end) async {
    final result = await _db.query('''
      SELECT SUM(totalAmount) as total 
      FROM purchase_order 
      WHERE createdAt BETWEEN :start AND :end
      AND status IN ('RECEIVED', 'COMPLETED')
    ''', {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
    });

    if (result.isEmpty || result.first['total'] == null) return 0.0;
    return double.tryParse(result.first['total'].toString()) ?? 0.0;
  }
}
