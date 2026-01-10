import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../services/telegram_service.dart';
import '../models/order_item.dart';
import './activity_repository.dart';

class SalesRepository {
  final MySQLService _dbService = MySQLService();
  final ActivityRepository _activityRepo = ActivityRepository();

  // --- 1. บันทึกการขาย (Save Order) ---
  Future<int> saveOrder({
    required int customerId,
    required double total,
    required double discount,
    required double grandTotal,
    required String paymentMethod, // 'CASH', 'qr', 'card', 'credit'
    required List<OrderItem> items,
    int? userId,
    String status = 'COMPLETED',
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    await _dbService.execute('START TRANSACTION;');

    try {
      // 1.1 สร้าง Order Header
      const sqlOrder = '''
        INSERT INTO `order` (customerId, total, discount, grandTotal, paymentMethod, received, userId, branchId, status, createdAt)
        VALUES (:cid, :total, :disc, :grand, :pay, :recv, :uid, :bid, :status, NOW());
      ''';

      final resOrder = await _dbService.execute(sqlOrder, {
        'cid': (customerId == 0) ? null : customerId,
        'total': total,
        'disc': discount,
        'grand': grandTotal,
        'pay': paymentMethod,
        'recv': grandTotal,
        'uid': userId,
        'bid': 1,
        'status': status,
      });

      int orderId = resOrder.lastInsertID.toInt();
      if (orderId == 0) throw Exception('Failed to get Order ID');

      // 1.2 บันทึกรายการสินค้า (Order Items)
      for (var item in items) {
        await _dbService.execute(
          'INSERT INTO orderitem (orderId, productId, productName, quantity, price, costPrice, discount, total) VALUES (:oid, :pid, :pname, :qty, :price, :cost, :discount, :total)',
          {
            'oid': orderId,
            'pid': item.productId,
            'pname': item.productName,
            'qty': item.quantity,
            'price': item.price,
            'cost': item.costPrice.toDouble(),
            'discount': item.discount,
            'total': item.total,
          },
        );
      }

      await _dbService.execute('COMMIT;');
      return orderId;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error saving order: $e');
      rethrow;
    }
  }

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
          'DEBT_PAYMENT' as type
        FROM debtor_transaction dt
        JOIN customer c ON dt.customerId = c.id
        WHERE dt.createdAt BETWEEN :start AND :end
          AND dt.transactionType = 'DEBT_PAYMENT')

        ORDER BY createdAt DESC;
      ''';
      return await _dbService.query(sql, {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      });
    } catch (e) {
      return [];
    }
  }

  // --- 3. ดึงรายละเอียดบิล ---
  Future<Map<String, dynamic>?> getOrderWithItems(int orderId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sqlOrder = '''
        SELECT o.*, c.firstName, c.lastName, c.phone
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.id = :id
      ''';

      final orderRes = await _dbService.query(sqlOrder, {'id': orderId});
      if (orderRes.isEmpty) return null;

      final orderData = orderRes.first;
      final itemsRes = await _dbService.query(
        'SELECT * FROM orderitem WHERE orderId = :id ORDER BY id ASC',
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
      debugPrint('Error fetching order details: $e');
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
      debugPrint('Error finding orders by product: $e');
      return [];
    }
  }

  // --- 5. ประมวลผลการรับคืนสินค้า ---
  Future<bool> processReturn({
    required int orderId,
    required int productId,
    required String productName,
    required double returnQty,
    required double price,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      final checkRes = await _dbService.query(
          'SELECT quantity FROM orderitem WHERE orderId = :oid AND productId = :pid',
          {'oid': orderId, 'pid': productId});

      double bought = 0;
      double returned = 0;

      for (var row in checkRes) {
        double q = double.tryParse(row['quantity'].toString()) ?? 0;
        if (q > 0) {
          bought += q;
        } else {
          returned += q.abs();
        }
      }

      if (returned + returnQty > bought) return false;
    } catch (e) {
      return false;
    }

    final orderDetails = await _dbService.query(
      'SELECT customerId, paymentMethod FROM `order` WHERE id = :id',
      {'id': orderId},
    );

    bool isCredit = false;
    int customerId = 0;
    if (orderDetails.isNotEmpty) {
      isCredit = orderDetails.first['paymentMethod']
          .toString()
          .toLowerCase()
          .contains('credit');
      customerId =
          int.tryParse(orderDetails.first['customerId'].toString()) ?? 0;
    }

    await _dbService.execute('START TRANSACTION;');
    try {
      final double totalRefund = returnQty * price;

      await _dbService.execute(
        'INSERT INTO orderitem (orderId, productId, productName, quantity, price, total) VALUES (:oid, :pid, :pname, :qty, :price, :total)',
        {
          'oid': orderId,
          'pid': productId,
          'pname': '$productName (คืน)',
          'qty': -returnQty,
          'price': price,
          'total': -totalRefund,
        },
      );

      await _dbService.execute(
        'UPDATE product SET stockQuantity = stockQuantity + :qty WHERE id = :id',
        {'qty': returnQty, 'id': productId},
      );

      await _dbService.execute('''
        INSERT INTO stockledger (productId, transactionType, quantityChange, orderId, note, createdAt)
        VALUES (:pid, 'RETURN_IN', :qty, :oid, 'รับคืนสินค้าจากบิล #$orderId', NOW())
      ''', {'pid': productId, 'qty': returnQty, 'oid': orderId});

      await _dbService.execute(
        'UPDATE `order` SET grandTotal = grandTotal - :refund, total = total - :refund WHERE id = :id',
        {'refund': totalRefund, 'id': orderId},
      );

      if (isCredit && customerId > 0) {
        await _dbService.execute(
            'UPDATE customer SET currentDebt = currentDebt - :amt WHERE id = :id',
            {'amt': totalRefund, 'id': customerId});
        await _dbService.execute(
            'UPDATE debtor_transaction SET amount = amount - :amt WHERE orderId = :oid AND transactionType = \'CREDIT_SALE\'',
            {'amt': totalRefund, 'oid': orderId});
      }

      await _dbService.execute('COMMIT;');
      await _activityRepo.log(
        action: 'RETURN',
        details: 'คืนสินค้า: $productName จำนวน $returnQty บิล #$orderId',
      );
      return true;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getReturnHistory() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT oi.productName, oi.quantity, oi.total, o.id as orderId, o.createdAt, c.firstName
        FROM orderitem oi
        JOIN `order` o ON oi.orderId = o.id
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE oi.quantity < 0
        ORDER BY o.createdAt DESC LIMIT 50;
      ''';
      return await _dbService.query(sql);
    } catch (e) {
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
      return [];
    }
  }

  // --- 7. Analytics & Schema ---
  Future<void> initTable() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final result = await _dbService.query('''
        SELECT count(*) as count FROM information_schema.columns 
        WHERE table_schema = DATABASE() AND table_name = 'orderitem' AND column_name = 'costPrice'
      ''');
      if (result.isNotEmpty && result.first['count'] == 0) {
        await _dbService.execute(
            'ALTER TABLE `orderitem` ADD COLUMN `costPrice` DECIMAL(10,2) DEFAULT 0.0 AFTER `price`;');
      }
      await _dbService.execute(
          'ALTER TABLE `order` MODIFY COLUMN `status` VARCHAR(20) DEFAULT \'COMPLETED\';');
    } catch (e) {
      // Ignored: Schema update may fail if already updated
    }
  }

  Future<List<Map<String, dynamic>>> getSalesStatsByDateRange(
      DateTime start, DateTime end, String periodType) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      String groupByFormat = periodType == 'DAILY'
          ? '%Y-%m-%d'
          : (periodType == 'MONTHLY' ? '%Y-%m' : '%Y');

      // 1. Sales Query (From Order Header) - Correct calculation of Sales & Count
      final sqlSales = '''
        SELECT DATE_FORMAT(createdAt, '$groupByFormat') as label, 
               SUM(grandTotal) as totalSales,
               COUNT(id) as orderCount
        FROM `order`
        WHERE createdAt BETWEEN :start AND :end AND status IN ('COMPLETED', 'UNPAID')
        GROUP BY label ORDER BY label ASC;
      ''';
      final salesRes = await _dbService.query(sqlSales,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});

      // 2. Cost Query (From Items) - Correct calculation of Cost with Fallback to Current Product Cost
      final sqlCost = '''
        SELECT DATE_FORMAT(o.createdAt, '$groupByFormat') as label, 
               SUM(
                 (CASE WHEN oi.costPrice > 0 THEN oi.costPrice ELSE COALESCE(p.costPrice, 0) END) 
                 * oi.quantity
               ) as totalCost
        FROM `order` o 
        JOIN orderitem oi ON o.id = oi.orderId
        LEFT JOIN product p ON oi.productId = p.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        GROUP BY label ORDER BY label ASC;
      ''';
      final costRes = await _dbService.query(sqlCost,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});

      // 3. Merge Data
      Map<String, Map<String, dynamic>> merged = {};

      for (var row in salesRes) {
        String label = row['label'].toString();
        merged[label] = {
          'label': label,
          'totalSales': double.tryParse(row['totalSales'].toString()) ?? 0.0,
          'orderCount': int.tryParse(row['orderCount'].toString()) ?? 0,
          'totalCost': 0.0,
        };
      }

      for (var row in costRes) {
        String label = row['label'].toString();
        double cost = double.tryParse(row['totalCost'].toString()) ?? 0.0;
        if (merged.containsKey(label)) {
          merged[label]!['totalCost'] = cost;
        } else {
          // If there's cost but no sales (unlikely but possible if logic changes), default sales to 0
          merged[label] = {
            'label': label,
            'totalSales': 0.0,
            'orderCount': 0,
            'totalCost': cost,
          };
        }
      }

      return merged.values.toList();
    } catch (e) {
      debugPrint('Error getting sales stats: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopProductsByDateRange(
      DateTime start, DateTime end) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sql = '''
        SELECT oi.productName as name, SUM(oi.quantity) as qty, SUM(oi.total) as totalSales
        FROM orderitem oi JOIN `order` o ON oi.orderId = o.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        GROUP BY oi.productId, oi.productName ORDER BY qty DESC LIMIT 10;
      ''';
      return await _dbService.query(sql,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDetailedOrdersForExport(
      DateTime start, DateTime end) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT o.id as orderId, o.createdAt, c.id as customerId, c.memberCode, c.firstName as customerName,
               oi.productName, oi.quantity, oi.price as unitPrice, oi.total as amount
        FROM `order` o JOIN orderitem oi ON o.id = oi.orderId LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        ORDER BY o.createdAt DESC;
      ''';
      return await _dbService.query(sql,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodStats(
      DateTime start, DateTime end) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT op.paymentMethod as method, SUM(op.amount) as total, COUNT(DISTINCT o.id) as count
        FROM order_payment op JOIN `order` o ON op.orderId = o.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        GROUP BY op.paymentMethod ORDER BY total DESC;
      ''';
      return await _dbService.query(sql,
          {'start': start.toIso8601String(), 'end': end.toIso8601String()});
    } catch (e) {
      return [];
    }
  }

  // --- 8. ลบบิล (Delete Order) [ฉบับแก้ไข: ลบแบบไล่ลำดับ Manual Cascade] ---
  Future<void> deleteOrder(int orderId, {bool returnToStock = false}) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // ดึงข้อมูลก่อนลบเพื่อเอาไปแจ้งเตือนหรือคืนสต็อก
    final orderRes = await _dbService
        .query('SELECT * FROM `order` WHERE id = :id', {'id': orderId});
    if (orderRes.isEmpty) return;

    double grandTotal =
        double.tryParse(orderRes.first['grandTotal'].toString()) ?? 0.0;

    await _dbService.execute('START TRANSACTION;');
    try {
      // 8.1 คืนสต็อก (ถ้าเลือก)
      if (returnToStock) {
        final items = await _dbService.query(
            'SELECT * FROM orderitem WHERE orderId = :id', {'id': orderId});
        for (var item in items) {
          int pid = int.tryParse(item['productId'].toString()) ?? 0;
          double qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          if (pid > 0 && qty > 0) {
            await _dbService.execute(
                'UPDATE product SET stockQuantity = stockQuantity + :qty WHERE id = :pid',
                {'qty': qty, 'pid': pid});

            // บันทึก Stock Ledger (คืนจากการลบบิล)
            await _dbService.execute('''
               INSERT INTO stockledger (productId, transactionType, quantityChange, orderId, note, createdAt)
               VALUES (:pid, 'VOID_RETURN', :qty, :oid, 'คืนสินค้าจากการลบบิล #$orderId', NOW())
            ''', {'pid': pid, 'qty': qty, 'oid': orderId});
          }
        }
      }

      // 8.2 ลบข้อมูลที่เกี่ยวข้อง (เรียงจากลูกไปหาแม่)

      // (A) ลบรายการในใบวางบิล
      try {
        await _dbService.execute(
            'DELETE FROM billing_note_items WHERE orderId = :oid',
            {'oid': orderId});
      } catch (_) {}
      try {
        // เผื่อชื่อตารางไม่มี s
        await _dbService.execute(
            'DELETE FROM billing_note_item WHERE orderId = :oid',
            {'oid': orderId});
      } catch (_) {}

      // (B) ลบประวัติสต็อกเดิม
      await _dbService.execute(
          'DELETE FROM stockledger WHERE orderId = :oid', {'oid': orderId});

      // (C) ลบงานขนส่ง (Delivery Jobs) **จุดสำคัญที่เคยทำให้ลบไม่ได้**
      try {
        await _dbService.execute(
            'DELETE FROM delivery_jobs WHERE orderId = :oid', {'oid': orderId});
      } catch (_) {}

      // (D) ลบลูกหนี้/เครดิต
      await _dbService.execute(
          'DELETE FROM debtor_transaction WHERE orderId = :oid',
          {'oid': orderId});

      try {
        await _dbService.execute(
            'DELETE FROM customer_ledger WHERE orderId = :oid',
            {'oid': orderId});
      } catch (_) {}

      // (E) ลบรายการสินค้าและชำระเงิน
      await _dbService.execute(
          'DELETE FROM orderitem WHERE orderId = :id', {'id': orderId});
      await _dbService.execute(
          'DELETE FROM order_payment WHERE orderId = :id', {'id': orderId});

      // (F) สุดท้าย ลบหัวบิล
      await _dbService
          .execute('DELETE FROM `order` WHERE id = :id', {'id': orderId});

      await _dbService.execute('COMMIT;');

      // แจ้งเตือน Telegram
      if (await TelegramService()
          .shouldNotify(TelegramService.keyNotifyDeleteBill)) {
        TelegramService().sendMessage('🗑️ *แจ้งเตือนการลบบิล* (Void Bill)\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '🧾 *เลขที่บิล:* #$orderId\n'
            '💰 *ยอดเงิน:* ${grandTotal.toStringAsFixed(2)} บาท\n'
            '⚠️ *สถานะ:* ลบออกจากระบบถาวร');
      }
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error deleting order: $e');
      rethrow;
    }
  }
}
