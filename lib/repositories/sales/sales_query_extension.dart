part of '../sales_repository.dart';

extension SalesQueryExtension on SalesRepository {
  // --- 2. ดึงข้อมูลการขาย (สำหรับ Dashboard) ---
  Future<List<Map<String, dynamic>>> getOrdersByDateRange(
      DateTime start, DateTime end) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        (SELECT 
          o.id, 
          o.grandTotal as amount, 
          o.received, 
          o.paymentMethod, 
          o.createdAt, 
          o.status,
          c.firstName as customerName,
          (SELECT COUNT(*) FROM orderitem WHERE orderId = o.id) as itemCount,
          (SELECT COALESCE(SUM(p.costPrice * oi.quantity), 0) FROM orderitem oi LEFT JOIN product p ON oi.productId = p.id WHERE oi.orderId = o.id) as totalCost,
          o.id as refId,
          '' as note,
          'ORDER' as type
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.createdAt BETWEEN :start AND :end
          AND o.status IN ('COMPLETED', 'HELD', 'UNPAID'))

        UNION ALL

        (SELECT 
          dt.id, 
          ABS(dt.amount) as amount, 
          ABS(dt.amount) as received,
          'Cash/Transfer' as paymentMethod, 
          dt.createdAt, 
          'COMPLETED' as status,
          c.firstName as customerName,
          0 as itemCount,
          0 as totalCost,
          dt.orderId as refId,
          dt.note,
          'DEBT_PAYMENT' as type
        FROM debtor_transaction dt
        JOIN customer c ON dt.customerId = c.id
        WHERE dt.createdAt BETWEEN :start AND :end
          AND dt.transactionType = 'DEBT_PAYMENT'
          AND (dt.isDeleted = 0 OR dt.isDeleted IS NULL))

        ORDER BY createdAt DESC;
      ''';
      return await _dbService.query(sql, {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      });
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error in getOrdersByDateRange', e);
      return [];
    }
  }

  // --- 3. ดึงรายละเอียดบิล ---
  Future<Map<String, dynamic>?> getOrderWithItems(int orderId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sqlOrder = '''
        SELECT o.*, c.firstName, c.lastName, c.phone, c.line_user_id
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.id = :id
      ''';

      final orderRes = await _dbService.query(sqlOrder, {'id': orderId});
      if (orderRes.isEmpty) return null;

      final orderData = orderRes.first;
      final itemsRes = await _dbService.query(
        '''
        SELECT oi.*, COALESCE(p.costPrice, oi.costPrice) as costPrice 
        FROM orderitem oi 
        LEFT JOIN product p ON oi.productId = p.id 
        WHERE oi.orderId = :id ORDER BY oi.id ASC
        ''',
        {'id': orderId},
      );

      final List<OrderItem> items = [];
      final List<OrderItem> returns = [];
      final Map<int, double> returnedMap = {};

      for (var row in itemsRes) {
        double qty = double.tryParse(row['quantity'].toString()) ?? 0;
        if (qty < 0) {
          final item = OrderItem.fromJson(row);
          returns.add(item);
          returnedMap[item.productId] =
              (returnedMap[item.productId] ?? 0) + qty.abs();
        } else {
          items.add(OrderItem.fromJson(row));
        }
      }

      return {
        'order': orderData,
        'items': items,
        'returns': returns,
        'returnedMap': returnedMap,
      };
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error fetching order details', e);
      return null;
    }
  }

  // --- 4. ค้นหาบิลจากสินค้า ---
  Future<List<Map<String, dynamic>>> findOrdersByProduct(int productId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT 
          o.id as orderId, 
          o.createdAt, 
          oi.quantity, 
          oi.price, 
          c.firstName, 
          c.lastName, 
          c.phone
        FROM orderitem oi
        JOIN `order` o ON oi.orderId = o.id
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE oi.productId = :pid AND o.status IN ('COMPLETED', 'UNPAID')
        ORDER BY o.createdAt DESC
        LIMIT 20;
      ''';
      return await _dbService.query(sql, {'pid': productId});
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error finding orders by product', e);
      return [];
    }
  }

  // --- 6. ประวัติการซื้อลูกค้า ---
  Future<List<Map<String, dynamic>>> getOrdersByCustomer(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT o.id, o.grandTotal, o.paymentMethod, o.createdAt, o.status,
               (SELECT COUNT(*) FROM orderitem WHERE orderId = o.id) as itemCount
        FROM `order` o
        WHERE o.customerId = :cid
        ORDER BY o.createdAt DESC;
      ''';
      return await _dbService.query(sql, {'cid': customerId});
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error in getOrdersByCustomer', e);
      return [];
    }
  }

  // 11. Helper to get Voided Orders
  Future<List<Map<String, dynamic>>> getVoidedOrders() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT o.*, c.firstName, c.lastName
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.status = 'VOID'
        ORDER BY o.createdAt DESC
        LIMIT 100;
      ''';
      return await _dbService.query(sql);
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error fetching voided orders', e);
      return [];
    }
  }

  // Fix 6 Phase 7.1: ย้าย raw SQL ออกจาก PosStateManager.sendToDeliveryFromHistory
  // Manager ไม่ควรรู้จัก SQL — ให้ Repository จัดการแทน
  Future<Map<String, dynamic>?> getOrderForDelivery(int orderId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sqlOrder = '''
        SELECT o.*, c.*, o.id AS orderId, c.id AS customerId
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.id = :id
      ''';
      final orderRes = await _dbService.query(sqlOrder, {'id': orderId});
      if (orderRes.isEmpty) return null;

      final orderData = orderRes.first;
      final itemsRes = await _dbService.query(
        'SELECT * FROM orderitem WHERE orderId = :id',
        {'id': orderId},
      );

      return {
        'orderData': orderData,
        'items': itemsRes,
      };
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error fetching order for delivery', e);
      return null;
    }
  }

  // --- 12. ค้นหาบิลตามรหัสบิล, ชื่อลูกค้า หรือเบอร์โทรศัพท์ ---
  Future<List<Map<String, dynamic>>> searchOrders(String query) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final cleanQuery = query.replaceAll('#', '').trim();
      final isNum = int.tryParse(cleanQuery) != null;
      final queryId = isNum ? int.parse(cleanQuery) : -1;
      final searchPattern = '%$cleanQuery%';

      const sql = '''
        (SELECT 
          o.id, 
          o.grandTotal as amount, 
          o.received, 
          o.paymentMethod, 
          o.createdAt, 
          o.status,
          c.firstName as customerName,
          (SELECT COUNT(*) FROM orderitem WHERE orderId = o.id) as itemCount,
          (SELECT COALESCE(SUM(p.costPrice * oi.quantity), 0) FROM orderitem oi LEFT JOIN product p ON oi.productId = p.id WHERE oi.orderId = o.id) as totalCost,
          o.id as refId,
          '' as note,
          'ORDER' as type
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE (o.id = :queryId 
               OR c.firstName LIKE :pattern 
               OR c.lastName LIKE :pattern 
               OR c.phone LIKE :pattern)
          AND o.status IN ('COMPLETED', 'HELD', 'UNPAID', 'VOID', 'CANCELLED'))

        UNION ALL

        (SELECT 
          dt.id, 
          ABS(dt.amount) as amount, 
          ABS(dt.amount) as received,
          'Cash/Transfer' as paymentMethod, 
          dt.createdAt, 
          'COMPLETED' as status,
          c.firstName as customerName,
          0 as itemCount,
          0 as totalCost,
          dt.orderId as refId,
          dt.note,
          'DEBT_PAYMENT' as type
        FROM debtor_transaction dt
        JOIN customer c ON dt.customerId = c.id
        WHERE (dt.id = :queryId 
               OR dt.orderId = :queryId
               OR c.firstName LIKE :pattern 
               OR c.lastName LIKE :pattern 
               OR c.phone LIKE :pattern)
          AND dt.transactionType = 'DEBT_PAYMENT'
          AND (dt.isDeleted = 0 OR dt.isDeleted IS NULL))

        ORDER BY createdAt DESC
        LIMIT 100;
      ''';

      return await _dbService.query(sql, {
        'queryId': queryId,
        'pattern': searchPattern,
      });
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error searching orders', e);
      return [];
    }
  }

}
