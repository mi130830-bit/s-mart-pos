import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import 'dart:io';
import '../services/line_service.dart';
import '../firebase_config.dart';

class OrderController {
  Router get router {
    final router = Router();
    router.post('/', _createOrder);
    router.get('/daily-summary', _getDailySummary);
    return router;
  }

  // POST /api/v1/orders
  Future<Response> _createOrder(Request request) async {
    try {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      // Log for verification
      stdout.writeln('🧾 API: Creating Order...');
      stdout.writeln('📦 Payload: $payload');

      final conn = await DbConfig().connection;

      // Extract Header Data
      // ✅ Fix: Handle 0 or null customerId to avoid foreign key constraint errors
      var rawCustomerId = payload['customerId'];
      int? customerId;

      if (rawCustomerId != null) {
        if (rawCustomerId is int) {
          customerId = rawCustomerId > 0 ? rawCustomerId : null;
        } else if (rawCustomerId is String) {
          final parsed = int.tryParse(rawCustomerId);
          if (parsed != null && parsed > 0) {
            customerId = parsed;
          }
        }
      }

      final double total = double.tryParse(payload['total'].toString()) ?? 0.0;
      final double discount =
          double.tryParse(payload['discount'].toString()) ?? 0.0;
      final double grandTotal =
          double.tryParse(payload['grandTotal'].toString()) ?? 0.0;
      final String paymentMethod = payload['paymentMethod'] ?? 'CASH';
      final int? userId = payload['userId'];
      final String status = payload['status'] ?? 'COMPLETED';
      final String? note = payload['note']; // Delivery/Pickup information
      final List items = payload['items'] ?? [];
      // ✅ CREDIT = ยังไม่ได้รับเงิน (received = 0), CASH/PROMPTPAY = รับเต็มจำนวน
      final bool isCredit = paymentMethod.toUpperCase() == 'CREDIT';
      final double receivedAmount = isCredit ? 0.0 : grandTotal;

      int newOrderId = 0;

      // Start Transaction
      await conn.execute('START TRANSACTION');

      try {
        // 1. Insert Order Header
        final sqlOrder = customerId == null
            ? '''
          INSERT INTO `order` (customerId, total, discount, grandTotal, paymentMethod, received, userId, branchId, status, createdAt)
          VALUES (NULL, :total, :disc, :grand, :pay, :recv, :uid, :bid, :status, NOW())
        '''
            : '''
          INSERT INTO `order` (customerId, total, discount, grandTotal, paymentMethod, received, userId, branchId, status, createdAt)
          VALUES (:cid, :total, :disc, :grand, :pay, :recv, :uid, :bid, :status, NOW())
        ''';

        final resOrder = await conn.execute(sqlOrder, {
          ...(customerId != null ? {'cid': customerId} : {}),
          'total': total,
          'disc': discount,
          'grand': grandTotal,
          'pay': paymentMethod,
          'recv': receivedAmount, // ✅ CREDIT = 0, CASH/PROMPTPAY = grandTotal
          'uid': userId,
          'bid': 1, // Default branch
          'status': status,
        });

        newOrderId = resOrder.lastInsertID.toInt();
        if (newOrderId == 0) throw Exception('Failed to get Order ID');

        // 2. Insert Order Items
        for (var item in items) {
          await conn.execute(
            'INSERT INTO orderitem (orderId, productId, productName, quantity, price, costPrice, discount, total) VALUES (:oid, :pid, :pname, :qty, :price, :cost, :discount, :total)',
            {
              'oid': newOrderId,
              'pid': item['productId'],
              'pname': item['productName'],
              'qty': item['quantity'],
              'price': item['price'],
              'cost': item['costPrice'],
              // ✅ Fix: Handle null discount for items
              'discount': item['discount'] ?? 0.0,
              // ✅ Fix: Handle null total for items (Fallback calc)
              'total': item['total'] ?? (item['price'] * item['quantity']),
            },
          );
        }

        // ✅ 3. CREDIT: บันทึกหนี้ลูกค้าในตาราง debtor_transaction (ภายใน Transaction เดียวกัน)
        if (isCredit && customerId != null) {
          // ดึงยอดหนี้ปัจจุบันก่อน (FOR UPDATE ล็อกแถว)
          final debtRes = await conn.execute(
            'SELECT COALESCE(currentDebt, 0) as currentDebt FROM customer WHERE id = :id FOR UPDATE',
            {'id': customerId},
          );
          double currentDebt = 0.0;
          if (debtRes.numOfRows > 0) {
            currentDebt = double.tryParse(
                    debtRes.rows.first.colAt(0)?.toString() ?? '0') ??
                0.0;
          }
          final double balanceBefore = currentDebt;
          final double balanceAfter = currentDebt + grandTotal;

          // บันทึก Transaction Log
          await conn.execute(
            '''INSERT INTO debtor_transaction 
               (customerId, orderId, transactionType, amount, balanceBefore, balanceAfter, note, createdAt)
               VALUES (:cid, :oid, 'CREDIT_SALE', :amt, :bBefore, :bAfter, :note, NOW())''',
            {
              'cid': customerId,
              'oid': newOrderId,
              'amt': grandTotal,
              'bBefore': balanceBefore,
              'bAfter': balanceAfter,
              'note': 'ขายเชื่อจาก S-Link บิล #$newOrderId',
            },
          );

          // อัปเดต currentDebt ในตาราง customer
          await conn.execute(
            'UPDATE customer SET currentDebt = :amt WHERE id = :id',
            {'amt': balanceAfter, 'id': customerId},
          );

          stdout.writeln(
              '💳 CREDIT: Debt $grandTotal บาท บันทึกให้ Customer #$customerId แล้ว (หนี้รวม: $balanceAfter)');
        }

        // Commit
        await conn.execute('COMMIT');
        stdout.writeln('✅ API: Order #$newOrderId created successfully.');

        // ---------------------------------------------------------
        // 🚀 [Line CRM] Send E-Receipt
        // ---------------------------------------------------------
        if (customerId != null) {
          try {
            final custRes = await conn.execute(
              'SELECT line_user_id FROM customer WHERE id = :id',
              {'id': customerId},
            );

            if (custRes.numOfRows > 0) {
              final lineUserId = custRes.rows.first.colAt(0); // line_user_id

              if (lineUserId != null && lineUserId.toString().isNotEmpty) {
                final receiptText =
                    '🧾 ขอบคุณที่ใช้บริการครับ\n'
                    'บิลเลขที่: #$newOrderId\n'
                    'ยอดสุทธิ: ${grandTotal.toStringAsFixed(2)} บาท\n'
                    'แต้มสะสมปัจจุบัน: (ยังไม่เปิดใช้งาน...)\n\n'
                    'ขอบคุณที่ไว้วางใจ ร้านส.บริการ ท่าข้าม';

                await LineService().pushMessage(
                  lineUserId.toString(),
                  receiptText,
                );
                stdout.writeln('   📱 Sent E-Receipt to Line ID: $lineUserId');
              }
            }
          } catch (e) {
            stderr.writeln('⚠️ Failed to send E-Receipt: $e');
          }
        }
        // ---------------------------------------------------------

        // ---------------------------------------------------------
        // 📱 [Firestore Sync] บันทึกลง Firestore เพื่อ Trigger Cloud Function
        // ---------------------------------------------------------
        try {
          final itemsForFirestore = items
              .map(
                (item) => {
                  'productId': item['productId'],
                  'productName': item['productName'],
                  'quantity': item['quantity'],
                  'price': item['price'],
                  'total': item['total'],
                },
              )
              .toList();

          await FirebaseConfig.syncOrderToFirestore(
            orderId: newOrderId,
            customerId: customerId ?? 0,
            grandTotal: grandTotal,
            paymentMethod: paymentMethod,
            items: itemsForFirestore,
            note: note,
          );
        } catch (e) {
          stderr.writeln('⚠️ Firestore sync failed (non-critical): $e');
        }
        // ---------------------------------------------------------

        return Response.ok(
          jsonEncode({'message': 'Order created', 'orderId': newOrderId}),
          headers: {'content-type': 'application/json'},
        );
      } catch (e) {
        // Rollback
        await conn.execute('ROLLBACK');
        stdout.writeln(
          '❌ API: Create Order Failed. Rollback performed. Error: $e',
        );
        rethrow;
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create order: $e'}),
      );
    }
  }
  // GET /api/v1/orders/daily-summary
  Future<Response> _getDailySummary(Request request) async {
    try {
      final conn = await DbConfig().connection;

      final result = await conn.execute('''
        SELECT
          COUNT(*) as orderCount,
          COALESCE(SUM(grandTotal), 0) as totalSales,
          COALESCE(SUM(CASE WHEN paymentMethod = 'CASH' THEN grandTotal ELSE 0 END), 0) as cashTotal,
          COALESCE(SUM(CASE WHEN paymentMethod = 'CREDIT' THEN grandTotal ELSE 0 END), 0) as creditTotal
        FROM `order`
        WHERE DATE(createdAt) = CURDATE()
          AND status = 'COMPLETED'
      ''');

      final row = result.rows.first;
      final data = {
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'orderCount': int.tryParse(row.colAt(0).toString()) ?? 0,
        'totalSales': double.tryParse(row.colAt(1).toString()) ?? 0.0,
        'cashTotal': double.tryParse(row.colAt(2).toString()) ?? 0.0,
        'creditTotal': double.tryParse(row.colAt(3).toString()) ?? 0.0,
      };

      return Response.ok(
        jsonEncode(data),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('❌ API: Get Daily Summary Failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get daily summary: $e'}),
      );
    }
  }
}
