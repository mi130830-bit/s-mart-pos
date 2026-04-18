import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../services/telegram_service.dart';
import '../services/settings_service.dart';
// import '../services/api_service.dart';
import '../models/order_item.dart';
import '../services/ai_office_service.dart'; // [Added] AI Office Webhook
import './activity_repository.dart';
import './debtor_repository.dart'; // Added
import './stock_repository.dart'; // ✅ Added for composite stock deduction
import 'package:decimal/decimal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/schema/order_collection.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';

class SalesRepository {
  final MySQLService _dbService;
  final ActivityRepository _activityRepo;
  final DebtorRepository _debtorRepo;

  SalesRepository({
    MySQLService? dbService,
    ActivityRepository? activityRepo,
    DebtorRepository? debtorRepo,
  })  : _dbService = dbService ?? MySQLService(),
        _activityRepo = activityRepo ?? ActivityRepository(),
        _debtorRepo = debtorRepo ?? DebtorRepository();

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
    // 💡 ส่งสัญญาณให้ AI นั่งคิดงาน (Dashboard)
    AIOfficeService.startThinking(agentId: 'Dev_Agent');

    // 1. Offline-First Strategy: Prepare Payload for Sync
    final payload = {
      'customerId': customerId,
      'total': total,
      'discount': discount,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      'userId': userId,
      'status': status,
      'items': items
          .map((e) => {
                'productId': e.productId,
                'productName': e.productName,
                'quantity': e.quantity,
                'price': e.price,
                'costPrice': e.costPrice.toDouble(),
                'discount': e.discount,
                'total': e.total,
              })
          .toList(),
    };

    // We will save to Isar OrderCollection (Queue) AFTER saving to local MySQL to ensure consistency
    // or BEFORE?
    // Let's do it after successful MySQL commit to ensure we have a valid local transaction.
    // Actually, to be truly Offline-First/Safe, we should save to Queue.
    // But since we rely on MySQL for receipts/stock logic locally in this phase,
    // we keep the MySQL save as the "Real" save, and Isar as the "Sync Mechanism".

    // 2. Local Fallback (Original Logic)
    if (!_dbService.isConnected()) await _dbService.connect();

    await _dbService.execute('START TRANSACTION;');

    try {
      // 1.1 สร้าง Order Header
      const sqlOrder = '''
        INSERT INTO `order` (customerId, total, discount, grandTotal, paymentMethod, received, userId, branchId, status, createdAt)
        VALUES (:cid, :total, :disc, :grand, :pay, :recv, :uid, :bid, :status, NOW());
      ''';

      // ✅ Validate Customer Logic (Prevent FK Error)
      dynamic validCid = (customerId == 0) ? null : customerId;
      if (validCid != null) {
        final checkCid = await _dbService
            .query('SELECT id FROM customer WHERE id = :id', {'id': validCid});
        if (checkCid.isEmpty) {
          debugPrint(
              '⚠️ Customer ID $validCid not found in MySQL. Fallback to Walk-in (NULL).');
          validCid = null;
        }
      }

      final bool isCredit = paymentMethod.toUpperCase() == 'CREDIT';
      final double receivedAmount =
          isCredit ? 0.0 : grandTotal; // If credit, received 0. Unless partial?
      // Note: Current UI passes full amount usually. If partial, logic needs update, but for now Standard Credit = 0 received.

      final resOrder = await _dbService.execute(sqlOrder, {
        'cid': validCid,
        'total': total,
        'disc': discount,
        'grand': grandTotal,
        'pay': paymentMethod,
        'recv': receivedAmount, // ✅ Fix: Credit = 0 received
        'uid': userId,
        'bid': 1,
        'status': status,
      });

      int orderId = resOrder.lastInsertID.toInt();
      if (orderId == 0) throw Exception('Failed to get Order ID');

      // 1.2 บันทึกรายการสินค้า (Order Items)
      final stockRepo = StockRepository();
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

        // ✅ ตัดสต๊อกผ่าน StockRepository เพื่อตัด/เพิ่มส่วนประกอบ (Components)
        await stockRepo.adjustStock(
          productId: item.productId,
          quantityChange: -item.quantity.toDouble(), // หักออก
          type: 'SALE_OUT',
          note: 'ขายหน้าร้านบิล #$orderId',
          orderId: orderId,
          useTransaction: false, // ⚠️ สำคัญมาก: เราอยู่ใน Transaction ของ saveOrder แล้ว
        );
      }

      await _dbService.execute('COMMIT;');

      // ✅ 1.3 Queue to Isar for Background Sync
      try {
        final isar = LocalDbService().db;
        await isar.writeTxn(() async {
          final orderCollection = OrderCollection()
            ..payload = jsonEncode(payload)
            ..isSynced = false
            ..createdAt = DateTime.now();
          await isar.orderCollections.put(orderCollection);
        });

        // 🚀 Trigger Background Sync (Fire & Forget)
        SyncService().pushOrders();
      } catch (e) {
        debugPrint('⚠️ Change to Isar Queue Failed: $e');
        // Don't fail the order if queueing fails, but log it.
      }

      // -----------------------------------------------------------------------
      // 📱 Line OA E-Receipt Trigger (Fire & Forget)
      // -----------------------------------------------------------------------
      if (customerId > 0) {
        _triggerLineReceipt(orderId, customerId, grandTotal);

        // ✅ Add Debt Transaction if Credit Sale
        if (paymentMethod.toUpperCase() == 'CREDIT') {
          // Wait, we are already in a transaction?
          // _debtorRepo.addDebt starts its own transaction!
          // Nested transactions in MySQL might be tricky or unsupported depending on driver/server.
          // `mysql_client` usually supports savepoints, but `addDebt` uses `START TRANSACTION`.
          // Better to call `transactDebt` directly here since we are inside `saveOrder`'s transaction.
          // BUT `transactDebt` is inside `DebtorRepository`.
          // And `SalesRepository` has `_debtorRepo`.
          // Let's look at `DebtorRepository`. It's independent.
          // If I call `addDebt`, it will try to `START TRANSACTION`.
          // If I am already in one, it might result in error or nested behavior.
          // Safer Approach:
          // 1. Commit `saveOrder` transaction FIRST.
          // 2. Then call `addDebt` (which manages its own transaction).
          // This implies `addDebt` is a separate atomic operation.
          // If `addDebt` fails, we have an Order but no Debt? That's bad.

          // Best Approach: Use `transactDebt` which expects to be part of a bigger flow?
          // `transactDebt` implementation in `DebtorRepository` accesses DB service directly.
          // If `DebtorRepository` uses the SAME `MySQLService` instance (Singleton), does `START TRANSACTION` nest?
          // MySQL `START TRANSACTION` inside another usually commits the first one!
          // Reference: "Transactions cannot be nested. This is a consequence of the implicit commit performed for any current transaction when you issue a START TRANSACTION statement or one of its synonyms."

          // SO: I CANNOT call `addDebt` (which has START TRANSACTION) inside `saveOrder` (which has START TRANSACTION).

          // Solution:
          // 1. Move `addDebt` logic into `SalesRepository` or make `transactDebt` public and capable of running without internal transaction management?
          // `transactDebt` (lines 20-68) DOES NOT have `START TRANSACTION`. It just executes queries.
          // So I CAN call `_debtorRepo.transactDebt` safely inside `saveOrder`'s transaction!

          await _debtorRepo.transactDebt(
            customerId: customerId,
            amountChange: Decimal.parse(grandTotal.toString()),
            transactionType: 'CREDIT_SALE',
            note: 'ขายเชื่อจากบิล #$orderId',
            orderId: orderId,
          );

          // And also trigger notification? `transactDebt` doesn't notify. `addDebt` does.
          // I'll call `_notifyTelegram` separately or just let `addDebt`'s equivalent logic handle it.
          // Telegram is fire-and-forget, safe to call.
        }
      }
      // -----------------------------------------------------------------------

      // -----------------------------------------------------------------------

      // ✅ Telegram Notification (Fire & Forget)
      _notifyTelegram(orderId, grandTotal, paymentMethod, items);

      // 💡 ส่งสัญญาณให้ AI กลับไปทำงานต่อ/พัก (สำเร็จ)
      AIOfficeService.startWorking(agentId: 'Dev_Agent');

      return orderId;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error saving order: $e');

      // 💡 ส่งสัญญาณให้ AI ทำท่าตกใจ/Error
      AIOfficeService.reportError(agentId: 'Dev_Agent');

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
      final Decimal totalRefundDecimal =
          Decimal.parse(returnQty.toString()) * Decimal.parse(price.toString());
      final double totalRefund = totalRefundDecimal.toDouble();

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

      // ✅ คืนสต๊อกให้สินค้าแม่ และ ส่วนประกอบ (Components)
      await StockRepository().adjustStock(
        productId: productId,
        quantityChange: returnQty, // รับคืน = บวกสต๊อก
        type: 'RETURN_IN',
        note: 'รับคืนสินค้าจากบิล #$orderId',
        orderId: orderId,
        useTransaction: false, // ใช้ Transaction จากบล็อกบน
      );

      await _dbService.execute(
        'UPDATE `order` SET grandTotal = grandTotal - :refund, total = total - :refund WHERE id = :id',
        {'refund': totalRefund, 'id': orderId},
      );

      if (isCredit && customerId > 0) {
        // ✅ Refactored: Centralized Debt Logic (Refund/Return)
        // Insert new transaction for refund (Negative Debt)
        await _debtorRepo.transactDebt(
          customerId: customerId,
          amountChange: -Decimal.parse(totalRefund.toString()),
          transactionType: 'RETURN_REFUND',
          note: 'คืนสินค้าจากบิล #$orderId',
          orderId: orderId,
        );
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

  // ✅ New Method for Credit Sales Summary
  Future<Map<String, dynamic>> getCreditStats(
      DateTime start, DateTime end) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT SUM(grandTotal) as totalAmount, COUNT(id) as billCount
        FROM `order`
        WHERE createdAt BETWEEN :start AND :end
          AND status IN ('UNPAID') -- Count only currently unpaid bills
      ''';
      final res = await _dbService.query(sql, {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      });

      if (res.isNotEmpty) {
        return {
          'amount': double.tryParse(res.first['totalAmount'].toString()) ?? 0.0,
          'count': int.tryParse(res.first['billCount'].toString()) ?? 0,
        };
      }
      return {'amount': 0.0, 'count': 0};
    } catch (e) {
      debugPrint('Error getting credit stats: $e');
      return {'amount': 0.0, 'count': 0};
    }
  }

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
      DateTime start, DateTime end,
      {int limit = 10}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final sql = '''
        SELECT oi.productName as name, SUM(oi.quantity) as qty, SUM(oi.total) as totalSales
        FROM orderitem oi JOIN `order` o ON oi.orderId = o.id
        WHERE o.createdAt BETWEEN :start AND :end AND o.status IN ('COMPLETED', 'UNPAID')
        GROUP BY oi.productId, oi.productName ORDER BY qty DESC LIMIT $limit;
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

  // Backward compatibility for existing code calls
  Future<void> deleteOrder(int orderId, {bool returnToStock = false}) async {
    return voidOrder(orderId,
        reason: 'Legacy Delete', returnToStock: returnToStock);
  }

  // --- 8. ยกเลิกบิล (Void Order) แทนการลบ ---
  Future<void> updateOrderCustomer(int orderId, int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // 1. Fetch current order info
    final orderRes = await _dbService.query(
        'SELECT customerId, grandTotal, status FROM `order` WHERE id = :id',
        {'id': orderId});
    if (orderRes.isEmpty) throw Exception('Order #$orderId not found');

    final order = orderRes.first;
    final int? oldCid = order['customerId'] != null
        ? int.parse(order['customerId'].toString())
        : null;
    final double grandTotal =
        double.tryParse(order['grandTotal'].toString()) ?? 0.0;

    // 2. Start Transaction
    await _dbService.execute('START TRANSACTION;');
    try {
      // 2.1 Update Order Table
      await _dbService.execute(
        'UPDATE `order` SET customerId = :cid WHERE id = :id',
        {'cid': customerId == 0 ? null : customerId, 'id': orderId},
      );

      // 2.2 Handle Points & Spending (Retroactive)
      final settings = SettingsService();
      if (settings.pointEnabled) {
        double rate = settings.pointPriceRate;
        if (rate <= 0) rate = 100.0;
        final int points = (grandTotal / rate).floor();

        // (A) Remove from OLD customer (if not walkthrough)
        if (oldCid != null && oldCid > 0) {
          await _dbService.execute(
            'UPDATE customer SET totalSpending = totalSpending - :s, currentPoints = currentPoints - :p WHERE id = :id',
            {'s': grandTotal, 'p': points, 'id': oldCid},
          );
        }

        // (B) Add to NEW customer
        if (customerId > 0) {
          await _dbService.execute(
            'UPDATE customer SET totalSpending = totalSpending + :s, currentPoints = currentPoints + :p WHERE id = :id',
            {'s': grandTotal, 'p': points, 'id': customerId},
          );
        }
      } else {
        // Just Update totalSpending if points disabled but tracking is on
        if (oldCid != null && oldCid > 0) {
          await _dbService.execute(
            'UPDATE customer SET totalSpending = totalSpending - :s WHERE id = :id',
            {'s': grandTotal, 'id': oldCid},
          );
        }
        if (customerId > 0) {
          await _dbService.execute(
            'UPDATE customer SET totalSpending = totalSpending + :s WHERE id = :id',
            {'s': grandTotal, 'id': customerId},
          );
        }
      }

      await _dbService.execute('COMMIT;');

      _activityRepo.log(
        action: 'UPDATE_ORDER_CUSTOMER',
        details:
            'เปลี่ยนลูกค้าบิล #$orderId จาก ID:$oldCid เป็น ID:$customerId',
      );
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      rethrow;
    }
  }

  Future<void> voidOrder(int orderId,
      {String reason = '', bool returnToStock = true}) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // ดึงข้อมูลก่อนลบเพื่อเอาไปแจ้งเตือนหรือคืนสต็อก
    final orderRes = await _dbService
        .query('SELECT * FROM `order` WHERE id = :id', {'id': orderId});
    if (orderRes.isEmpty) return;

    // Check if already voided
    if (orderRes.first['status'] == 'VOID') return;

    double grandTotal =
        double.tryParse(orderRes.first['grandTotal'].toString()) ?? 0.0;

    await _dbService.execute('START TRANSACTION;');
    try {
      // 8.1 คืนสต็อก (ถ้าเลือก) - Default TRUE for Void
      if (returnToStock) {
        final items = await _dbService.query(
            'SELECT * FROM orderitem WHERE orderId = :id', {'id': orderId});
        final stockRepo = StockRepository();
        for (var item in items) {
          int pid = int.tryParse(item['productId'].toString()) ?? 0;
          double qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          if (pid > 0 && qty > 0) {
            // ✅ คืนสต๊อกผ่าน StockRepository เพื่อให้จัดการตัวประกอบแบบ Recursive ด้วย
            await stockRepo.adjustStock(
              productId: pid,
              quantityChange: qty, // คืนกลับคือการบวก
              type: 'VOID_RETURN',
              note: 'คืนสินค้าจากการยกเลิกบิล #$orderId',
              orderId: orderId,
              useTransaction: false, // สำคัญ: ใช้ Transaction ร่วมกัน
            );
          }
        }
      }

      // 8.2 จัดการยอดเงินและหนี้ (Revert Financials)

      // (A) ลบ/ยกเลิก Delivery Jobs
      try {
        await _dbService.execute(
            'DELETE FROM delivery_jobs WHERE orderId = :oid', {'oid': orderId});
      } catch (_) {}

      // (B) ลบลูกหนี้/เครดิต และคืนยอดหนี้ (Revert Balance)
      final debtTrans = await _dbService.query(
          'SELECT amount, customerId FROM debtor_transaction WHERE orderId = :oid FOR UPDATE',
          {'oid': orderId});

      for (var t in debtTrans) {
        final double amount = double.tryParse(t['amount'].toString()) ?? 0.0;
        final int cid = int.tryParse(t['customerId'].toString()) ?? 0;
        if (cid > 0) {
          // Revert balance: new = current - amount
          await _dbService.execute(
              'UPDATE customer SET currentDebt = currentDebt - :amt WHERE id = :id',
              {'amt': amount, 'id': cid});
        }
      }

      // Mark trans as VOID or Delete? Ideally mark VOID if schema supports, but for now DELETE to clear debt history impact
      // OR better: Insert a cancelling transaction?
      // Current logic was DELETE. soft delete implies we should keep it but mark void using `transactionType`?
      // Let's stick to cleaning up debt transaction to avoid double counting, or use a "VOID" flag on it.
      // Since `debtor_transaction` doesn't have `status`, DELETE is safer for consistency unless we add schema.
      // User accepted "Void Order" -> "Keep Bill Evidence".

      await _dbService.execute('''
          UPDATE debtor_transaction 
          SET isDeleted = 1, deletedAt = NOW(), deleteReason = :reason 
          WHERE orderId = :oid
          ''', {'oid': orderId, 'reason': 'Void Order #$orderId'});

      try {
        await _dbService.execute(
            'DELETE FROM customer_ledger WHERE orderId = :oid',
            {'oid': orderId});
      } catch (_) {}

      // (C) Update Order Status to VOID
      await _dbService.execute(
          "UPDATE `order` SET status = 'VOID', voidReason = :reason WHERE id = :id",
          {'id': orderId, 'reason': reason});

      // (D) ลบ Payment Records? Or keep?
      // Keep payment records but maybe mark them? Or just rely on Order Status.
      // System usually sums from `order` table. If `status='VOID'`, it's excluded from sales stats.

      await _dbService.execute('COMMIT;');

      // Log Activity
      await _activityRepo.log(
          action: 'VOID_BILL',
          details:
              'ยกเลิกบิล #$orderId ยอด ${grandTotal.toStringAsFixed(2)} บาท สาเหตุ: $reason');

      // แจ้งเตือน Telegram
      if (await TelegramService()
          .shouldNotify(TelegramService.keyNotifyDeleteBill)) {
        TelegramService().sendMessage('🚫 *แจ้งเตือนการยกเลิกบิล* (Void Bill)\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '🧾 *เลขที่บิล:* #$orderId\n'
            '💰 *ยอดเงิน:* ${grandTotal.toStringAsFixed(2)} บาท\n'
            '📝 *สาเหตุ:* $reason\n'
            '⚠️ *สถานะ:* ยกเลิกรายการ');
      }
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error voiding order: $e');
      rethrow;
    }
  }

  // --- 9. Helpers ---
  Future<void> _triggerLineReceipt(
      int orderId, int customerId, double amount) async {
    try {
      // 1. Get Customer Line ID & Points from Local DB
      if (!_dbService.isConnected()) await _dbService.connect();
      final res = await _dbService.query(
        'SELECT line_user_id, currentPoints FROM customer WHERE id = :id',
        {'id': customerId},
      );

      if (res.isNotEmpty) {
        final lineUserId = res.first['line_user_id'];
        final currentPoints = res.first['currentPoints'];

        if (lineUserId != null && lineUserId.toString().isNotEmpty) {
          // 2. Call Backend API (Fire & Forget)
          final url =
              Uri.parse('http://127.0.0.1:8080/api/v1/line/push-receipt');
          http
              .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lineUserId': lineUserId.toString(),
              'orderId': orderId.toString(),
              'amount': amount,
              'points': currentPoints ?? 0,
            }),
          )
              .timeout(const Duration(seconds: 5), onTimeout: () {
            return http.Response('Timeout', 408);
          }).then((response) {
            if (response.statusCode != 200) {
              debugPrint('⚠️ Line Receipt Push Failed: ${response.body}');
            } else {
              debugPrint('✅ Line Receipt Triggered for Order #$orderId');
            }
          }).catchError((e) {
            debugPrint('⚠️ Line Receipt Connection Error: $e');
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ Line Receipt Logic Error: $e');
    }
  }

  // 10. กู้คืนบิล (Un-Void)
  // Warning: This only restores Sales Amount & Debt. It DOES NOT re-deduct stock.
  Future<void> unvoidOrder(int orderId, String reason) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute('START TRANSACTION;');

      // 1. Restore Order Status
      await _dbService.query(
        "UPDATE `order` SET status = 'COMPLETED', voidReason = NULL WHERE id = :id",
        {'id': orderId},
      );

      // 2. Restore Debt Transaction (if any)
      // Reverse the soft-delete done in voidOrder
      await _dbService.query(
        "UPDATE debtor_transaction SET isDeleted = 0, deletedAt = NULL, deleteReason = NULL WHERE transactionType = 'CREDIT_SALE' AND ref_id = :id",
        {'id': orderId},
      );

      // 3. Log Activity
      await ActivityRepository().log(
        action: 'UNVOID_ORDER',
        details: 'กู้คืนบิล #$orderId',
      );

      await _dbService.execute('COMMIT;');
      debugPrint('Un-voided order #$orderId');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error un-voiding order: $e');
      rethrow;
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
      debugPrint('Error fetching voided orders: $e');
      return [];
    }
  }

  // ✅ Helper for Telegram Notification
  Future<void> _notifyTelegram(
      int orderId, double amount, String method, List<OrderItem> items) async {
    debugPrint('🔔 Triggering Telegram Notify for Order #$orderId...');
    try {
      if (await TelegramService()
          .shouldNotify(TelegramService.keyNotifyPayment)) {
        final time = DateTime.now().toString().substring(11, 16); // HH:mm

        // Format Items List
        String itemsList = '';
        for (var item in items) {
          itemsList += '- ${item.productName} x ${item.quantity}\n';
        }
        if (itemsList.length > 500) {
          itemsList = '${itemsList.substring(0, 500)}... (มีต่อ)';
        }

        final msg = '💰 *แจ้งเตือนการขาย* (New Sale)\n'
            '━━━━━━━━━━━━━━━━━━\n'
            '🧾 *บิล:* #$orderId\n'
            '⏰ *เวลา:* $time\n'
            '💵 *ยอดเงิน:* ${amount.toStringAsFixed(2)} บาท\n'
            '📥 *รับเงิน:* ${amount.toStringAsFixed(2)} บาท\n'
            '💸 *เงินทอน:* 0.00 บาท\n'
            '💳 *ชำระโดย:* $method\n'
            '📦 *รายการสินค้า:* ${items.length} รายการ\n'
            '$itemsList'
            '━━━━━━━━━━━━━━━━━━';
        TelegramService().sendMessage(msg);
      }
    } catch (e) {
      debugPrint('⚠️ Telegram Notify Error: $e');
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
      debugPrint('Error fetching order for delivery: $e');
      return null;
    }
  }
}
