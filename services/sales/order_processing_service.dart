import 'package:flutter/foundation.dart';

// Services
// Services
import '../mysql_service.dart';
//import '../firebase_service.dart';
import '../notification_service.dart';
// Repositories
import '../../repositories/stock_repository.dart';

// Models
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/payment_record.dart';
import '../../models/delivery_type.dart';

class OrderProcessingService {
  final MySQLService _dbService;
  final StockRepository _stockRepo;
  final NotificationService _notificationService;

  OrderProcessingService({
    MySQLService? dbService,
    StockRepository? stockRepo,
    NotificationService? notificationService,
  })  : _dbService = dbService ?? MySQLService(),
        _stockRepo = stockRepo ?? StockRepository(),
        _notificationService = notificationService ?? NotificationService();

  Future<int> processOrder({
    required List<OrderItem> cart,
    required Customer? currentCustomer,
    required List<PaymentRecord> payments,
    required double total,
    required double discountAmount,
    required double grandTotal,
    DeliveryType deliveryType = DeliveryType.none,
    Uint8List? billPdfData,
    int? userId, // ✅ เพิ่ม: รับ userId คนขาย
  }) async {
    if (cart.isEmpty) {
      throw Exception('Cart is empty.');
    }
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }

    // ---------------------------------------------------------
    // 1. คำนวณยอดรับเงินจริง (ตัด Credit ออก)
    // ---------------------------------------------------------
    double received = 0.0;
    Set<String> methods = {};

    for (var p in payments) {
      bool isCredit = p.method.toUpperCase().contains('CREDIT') ||
          p.method.contains('เงินเชื่อ');

      if (!isCredit) {
        received += p.amount;
      }
      methods.add(p.method);
    }
    String paymentMethodStr = methods.join(',');

    // คำนวณเงินทอน (ถ้าจ่ายด้วยเครดิต received จะน้อยกว่ายอดรวม เงินทอนจะเป็น 0)
    final currentChange = (received - grandTotal).clamp(0.0, double.infinity);

    await _dbService.execute('START TRANSACTION;');

    try {
      // 2. Determine Status
      String status = 'COMPLETED';
      double debtAmt = 0.0;

      if (deliveryType == DeliveryType.delivery) {
        status = (received < grandTotal - 0.01) ? 'UNPAID' : 'COMPLETED';
      } else {
        status = (received < grandTotal - 0.01) ? 'UNPAID' : 'COMPLETED';
      }

      debtAmt = (grandTotal - received).clamp(0.0, double.infinity);

      // 3. Insert Order Header (✅ เพิ่ม userId, changeAmount, deliveryType)
      final sqlOrder = '''
        INSERT INTO `order` (
          customerId, total, discount, grandTotal, 
          paymentMethod, received, changeAmount, 
          userId, branchId, status, deliveryType, createdAt
        )
        VALUES (
          :cid, :total, :disc, :grand, 
          :pm, :rcv, :chg, 
          :uid, :bid, :status, :dtype, NOW()
        )
      ''';

      final resOrder = await _dbService.execute(sqlOrder, {
        'cid': currentCustomer?.id,
        'total': total,
        'disc': discountAmount,
        'grand': grandTotal,
        'pm': paymentMethodStr,
        'rcv': received,
        'chg': currentChange,
        'uid': userId ?? 1, // ✅ ใส่ userId (ถ้าไม่มี Default เป็น 1/Admin)
        'bid': 1,
        'status': status,
        'dtype': deliveryType.name,
      });

      final orderId = resOrder.lastInsertID.toInt();

      // 4. Insert Items & Cut Stock
      final sqlItem = '''
        INSERT INTO orderitem (orderId, productId, productName, quantity, price, discount, total, conversionFactor)
        VALUES (:oid, :pid, :pname, :qty, :price, :disc, :total, :factor)
      ''';

      for (var item in cart) {
        await _dbService.execute(sqlItem, {
          'oid': orderId,
          'pid': item.productId,
          'pname': item.productName,
          'qty': item.quantity.toDouble(),
          'price': item.price.toDouble(),
          'disc': item.discount.toDouble(),
          'total': item.total.toDouble(),
          'factor': item.conversionFactor,
        });

        if (item.productId != 0 && item.productId != -999) {
          await _stockRepo.adjustStock(
            productId: item.productId,
            quantityChange: -(item.quantity.toDouble() * item.conversionFactor),
            note: 'Sale #$orderId',
            type: 'SALE',
          );
        }
      }

      // 5. Insert Payments
      final sqlPayment = '''
        INSERT INTO order_payment (orderId, paymentMethod, amount, createdAt)
        VALUES (:oid, :method, :amt, NOW())
      ''';

      for (var p in payments) {
        await _dbService.execute(sqlPayment, {
          'oid': orderId,
          'method': p.method,
          'amt': p.amount,
        });
      }

      // 6. Handle Debt
      if (debtAmt > 0.01 &&
          currentCustomer != null &&
          currentCustomer.id != 0) {
        double currentDebt = 0.0;
        final cRes = await _dbService.query(
            'SELECT currentDebt FROM customer WHERE id = :id FOR UPDATE',
            {'id': currentCustomer.id});
        if (cRes.isNotEmpty) {
          currentDebt =
              double.tryParse(cRes.first['currentDebt'].toString()) ?? 0.0;
        }

        double balanceAfter = currentDebt + debtAmt;

        await _dbService.execute('''
            INSERT INTO debtor_transaction 
            (customerId, orderId, transactionType, amount, balanceBefore, balanceAfter, note, createdAt)
            VALUES (:cid, :oid, 'CREDIT_SALE', :amt, :bef, :aft, :note, NOW())
          ''', {
          'cid': currentCustomer.id,
          'oid': orderId,
          'amt': debtAmt,
          'bef': currentDebt,
          'aft': balanceAfter,
          'note': 'ซื้อเชื่อ (Credit Sales)',
        });

        await _dbService.execute(
          'UPDATE customer SET currentDebt = currentDebt + :amt WHERE id = :id',
          {'amt': debtAmt, 'id': currentCustomer.id},
        );

        _notificationService.sendDebtNotification(
          customer: currentCustomer,
          orderId: orderId,
          debtAmount: debtAmt,
          totalDebt: balanceAfter,
        );
      }

      await _dbService.execute('COMMIT;');

      // Notification & Background Tasks
      _notificationService.sendSaleNotification(
        orderId: orderId,
        grandTotal: grandTotal,
        received: received,
        paymentMethodStr: paymentMethodStr,
        customer: currentCustomer,
      );

      // Image upload is now handled only within DeliveryIntegrationService
      // if (billPdfData != null) {
      //   _uploadBillImageInBackground(orderId, billPdfData);
      // }

      return orderId;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error processing order: $e');
      rethrow;
    }
  }

  /*
  void _uploadBillImageInBackground(int orderId, Uint8List pdfData) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      try {
        await for (var page in Printing.raster(pdfData, pages: [0], dpi: 200)) {
          final pngBytes = await page.toPng();
          await _firebaseService.uploadBillImage(pngBytes, 'order_$orderId');
          break;
        }
      } catch (innerError) {
        debugPrint('⚠️ Error inside Printing.raster loop: $innerError');
      }
    } catch (e) {
      debugPrint('⚠️ Background upload crash avoided: $e');
    }
  }
  */
}
