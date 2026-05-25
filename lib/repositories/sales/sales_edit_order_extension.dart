part of '../sales_repository.dart';

/// Extension สำหรับแก้ไขบิลที่ยังไม่ได้ชำระเงิน (UNPAID)
/// ไม่แตะ logic การขายปกติเดิมเลย — เป็น Flow แยกต่างหากทั้งหมด
extension SalesEditOrderExtension on SalesRepository {
  /// ดึงบิล UNPAID/PAID มาแสดง เพื่อโหลดเข้าตะกร้าสำหรับการแก้ไข
  /// คืนค่า null ถ้าไม่พบบิลที่แก้ไขได้
  Future<Map<String, dynamic>?> getOrderForEdit(int orderId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final orderRes = await _dbService.query(
        '''
        SELECT o.*, c.firstName, c.lastName, c.phone, c.currentDebt
        FROM `order` o
        LEFT JOIN customer c ON o.customerId = c.id
        WHERE o.id = :id AND o.status IN ('UNPAID', 'COMPLETED', 'PAID')
        ''',
        {'id': orderId},
      );
      if (orderRes.isEmpty) return null;

      final itemsRes = await _dbService.query(
        '''
        SELECT oi.*, p.costPrice as productCostPrice
        FROM orderitem oi
        LEFT JOIN product p ON oi.productId = p.id
        WHERE oi.orderId = :id AND oi.quantity > 0
        ORDER BY oi.id ASC
        ''',
        {'id': orderId},
      );

      return {
        'order': orderRes.first,
        'items': itemsRes,
      };
    } catch (e) {
      LoggerService.error('SalesRepository', 'Error fetching unpaid order for edit', e);
      return null;
    }
  }

  /// อัปเดตบิลที่มีอยู่แล้ว (เพิ่ม/ลด รายการสินค้า)
  ///
  /// กระบวนการ:
  /// 1. ตรวจสอบว่าบิลแก้ไขได้ (UNPAID/PAID)
  /// 2. ดึงรายการเดิมมาคืนสต็อก
  /// 3. ลบ orderitem เดิม
  /// 4. Insert orderitem ใหม่ + ตัดสต็อก
  /// 5. อัปเดต order header (total, discount, grandTotal, status)
  /// 6. ปรับยอดหนี้ใน debtor_transaction (เฉพาะส่วนต่าง)
  Future<void> updateEditedOrder({
    required int orderId,
    required List<OrderItem> newItems,
    required double newTotal,
    required double newDiscountAmount,
    required double newGrandTotal,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    // ── 0. ตรวจสอบว่าบิลสามารถแก้ไขได้ ──────────────────────────────────
    final checkRes = await _dbService.query(
      "SELECT id, grandTotal, customerId, status FROM `order` WHERE id = :id AND status IN ('UNPAID', 'COMPLETED', 'PAID')",
      {'id': orderId},
    );
    if (checkRes.isEmpty) {
      throw Exception('ไม่พบบิล #$orderId หรือไม่อนุญาตให้แก้ไขสถานะนี้');
    }

    final oldGrandTotal = double.tryParse(checkRes.first['grandTotal'].toString()) ?? 0.0;
    final customerId = checkRes.first['customerId'];
    final oldStatus = checkRes.first['status'].toString().toUpperCase();

    final stockRepo = StockRepository();

    await _dbService.execute('START TRANSACTION;');
    try {
      // ── 1. ดึงรายการสินค้าเดิม ───────────────────────────────────────────
      final oldItemsRes = await _dbService.query(
        'SELECT productId, quantity, conversionFactor FROM orderitem WHERE orderId = :id AND quantity > 0',
        {'id': orderId},
      );

      // ── 2. คืนสต็อกสินค้าของรายการเดิมทั้งหมด ─────────────────────────
      for (final row in oldItemsRes) {
        final pid = int.tryParse(row['productId'].toString()) ?? 0;
        final qty = double.tryParse(row['quantity'].toString()) ?? 0.0;
        final factor = double.tryParse(row['conversionFactor']?.toString() ?? '1') ?? 1.0;
        if (pid > 0 && pid != -999) {
          await stockRepo.adjustStock(
            productId: pid,
            quantityChange: qty * factor, // คืนสต็อก (+)
            note: 'Edit Order #$orderId (Revert)',
            type: 'EDIT_REVERT',
            useTransaction: false,
          );
        }
      }

      // ── 3. ลบ orderitem เดิมทั้งหมด ────────────────────────────────────
      await _dbService.execute(
        'DELETE FROM orderitem WHERE orderId = :id',
        {'id': orderId},
      );

      // ── 4. Insert orderitem ใหม่ + ตัดสต็อก ────────────────────────────
      const sqlItem = '''
        INSERT INTO orderitem (orderId, productId, productName, quantity, price, discount, total, conversionFactor)
        VALUES (:oid, :pid, :pname, :qty, :price, :disc, :total, :factor)
      ''';

      final filteredNew = newItems.where((i) => i.quantity > Decimal.zero).toList();
      for (final item in filteredNew) {
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

        if (item.productId > 0 && item.productId != -999) {
          await stockRepo.adjustStock(
            productId: item.productId,
            quantityChange: -(item.quantity.toDouble() * item.conversionFactor), // ตัดสต็อก (-)
            note: 'Edit Order #$orderId (New)',
            type: 'SALE',
            useTransaction: false,
          );
        }
      }

      // ── 5. อัปเดต order header ──────────────────────────────────────────
      final debtDelta = newGrandTotal - oldGrandTotal;
      String newStatus = oldStatus;
      if ((oldStatus == 'COMPLETED' || oldStatus == 'PAID') && debtDelta > 0.001) {
        newStatus = 'UNPAID'; // ถ้ายอดใหม่มากกว่ายอดเดิมที่จ่ายไปแล้ว ให้เปลี่ยนเป็นค้างชำระ
      }

      await _dbService.execute(
        '''
        UPDATE `order`
        SET total = :total, discount = :disc, grandTotal = :grand, status = :status
        WHERE id = :id
        ''',
        {
          'total': newTotal,
          'disc': newDiscountAmount,
          'grand': newGrandTotal,
          'status': newStatus,
          'id': orderId,
        },
      );

      // ── 6. ปรับยอดหนี้ลูกค้า ────────────────────────────────────────────
      // คำนวณส่วนต่างยอดหนี้ (บวก = หนี้เพิ่ม, ลบ = หนี้ลด)
      if (customerId != null) {
        final cid = int.tryParse(customerId.toString()) ?? 0;
        if (cid > 0) {
          final debtDelta = newGrandTotal - oldGrandTotal;
          if (debtDelta.abs() > 0.001) {
            await _debtorRepo.transactDebt(
              customerId: cid,
              amountChange: Decimal.parse(debtDelta.toStringAsFixed(2)),
              transactionType: 'CREDIT_ADJUSTMENT',
              note: 'ปรับยอด (แก้ไขบิล #$orderId)',
              orderId: orderId,
            );
          }
        }
      }

      await _dbService.execute('COMMIT;');

      LoggerService.info('SalesRepository',
          'Order #$orderId updated successfully. Old: $oldGrandTotal, New: $newGrandTotal');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      LoggerService.error('SalesRepository', 'Error updating unpaid order #$orderId', e);
      rethrow;
    }
  }
}
