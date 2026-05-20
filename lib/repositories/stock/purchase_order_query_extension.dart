part of '../stock_repository.dart';

extension PurchaseOrderQueryExtension on StockRepository {
  Future<List<Map<String, dynamic>>> getPurchaseOrders({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? supplierId,
    bool? isPaid,
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
    if (isPaid != null) {
      conditions.add('po.isPaid = :isPaid');
      params['isPaid'] = isPaid ? 1 : 0;
    }

    String whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(" AND ")}' : '';

    final sql = '''
      SELECT po.id, po.supplierId, po.documentNo, po.totalAmount, po.status,
             po.note, po.vatType, po.isPaid, po.createdAt, po.updatedAt,
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
    const sql = 'SELECT * FROM purchase_order_item WHERE poId = :id';
    return await _dbService.query(sql, {'id': poId});
  }

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
}
