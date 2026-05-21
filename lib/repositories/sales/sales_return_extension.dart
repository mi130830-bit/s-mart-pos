part of '../sales_repository.dart';

extension SalesReturnExtension on SalesRepository {
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
      // ✅ คำนวณด้วย double ปกติ ลด Overhead ของการแปลงไปมา
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
      LoggerService.error('SalesRepository', 'Error in getReturnHistory', e);
      return [];
    }
  }

}
