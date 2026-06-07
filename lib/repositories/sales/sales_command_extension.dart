part of '../sales_repository.dart';

extension SalesCommandExtension on SalesRepository {
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
          LoggerService.warning('SalesRepository', 'Customer ID $validCid not found in MySQL. Fallback to Walk-in (NULL).');
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

      // -----------------------------------------------------------------------
      // 📱 Line OA E-Receipt Trigger & Debt Management
      // -----------------------------------------------------------------------
      if (customerId > 0) {
        _triggerLineReceipt(orderId, customerId, grandTotal);

        // ✅ Add Debt Transaction if Credit Sale (Before COMMIT)
        if (paymentMethod.toUpperCase() == 'CREDIT') {
          await _debtorRepo.transactDebt(
            customerId: customerId,
            amountChange: Decimal.parse(grandTotal.toString()),
            transactionType: 'CREDIT_SALE',
            note: 'ขายเชื่อจากบิล #$orderId',
            orderId: orderId,
          );
        }
      }
      // -----------------------------------------------------------------------

      await _dbService.execute('COMMIT;'); // ✅ Commit หลังจากจัดการหนี้เสร็จแล้ว

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
        LoggerService.warning('SalesRepository', 'Change to Isar Queue Failed: $e');
        // Don't fail the order if queueing fails, but log it.
      }

      // ✅ Telegram Notification (Fire & Forget)
      _notifyTelegram(orderId, grandTotal, paymentMethod, items);

      // 💡 ส่งสัญญาณให้ AI กลับไปทำงานต่อ/พัก (สำเร็จ)
      AIOfficeService.startWorking(agentId: 'Dev_Agent');

      return orderId;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      LoggerService.error('SalesRepository', 'Error saving order', e);

      // 💡 ส่งสัญญาณให้ AI ทำท่าตกใจ/Error
      AIOfficeService.reportError(agentId: 'Dev_Agent');

      rethrow;
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

    // ✅ ป้องกันการ Void บิลที่มีการชำระหนี้ไปแล้ว
    final paymentCheck = await _dbService.query(
      "SELECT id FROM debtor_transaction WHERE orderId = :oid AND transactionType = 'DEBT_PAYMENT' AND (isDeleted = 0 OR isDeleted IS NULL)",
      {'oid': orderId}
    );
    if (paymentCheck.isNotEmpty) {
      throw Exception('ไม่สามารถยกเลิกบิลที่ชำระหนี้แล้วได้ กรุณายกเลิกรายการรับชำระหนี้ก่อน');
    }

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
      LoggerService.error('SalesRepository', 'Error voiding order', e);
      rethrow;
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

      // ✅ ตัดสต๊อกออกอีกครั้งเมื่อมีการกู้คืนบิล
      final items = await _dbService.query('SELECT productId, quantity FROM orderitem WHERE orderId = :id', {'id': orderId});
      final stockRepo = StockRepository();
      for (var item in items) {
        int pid = int.tryParse(item['productId'].toString()) ?? 0;
        double qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        if (pid > 0 && qty > 0) {
          await stockRepo.adjustStock(
            productId: pid,
            quantityChange: -qty, // ตัดออก
            type: 'UNVOID_OUT',
            note: 'ตัดสต๊อกจากการกู้คืนบิล #$orderId',
            orderId: orderId,
            useTransaction: false,
          );
        }
      }

      // 3. Log Activity
      await ActivityRepository().log(
        action: 'UNVOID_ORDER',
        details: 'กู้คืนบิล #$orderId',
      );

      await _dbService.execute('COMMIT;');
      LoggerService.info('SalesRepository', 'Un-voided order #$orderId');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      LoggerService.error('SalesRepository', 'Error un-voiding order', e);
      rethrow;
    }
  }

  // 11. เปลี่ยนบิลที่จ่ายแล้วเป็น "ยังไม่ได้จ่าย" (Mark as Unpaid)
  Future<void> markOrderAsUnpaid(int orderId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    
    // 1. Fetch current order
    final orderRes = await _dbService.query(
      'SELECT status, paymentMethod, customerId, grandTotal FROM `order` WHERE id = :id FOR UPDATE',
      {'id': orderId}
    );
    if (orderRes.isEmpty) throw Exception('ไม่พบบิล #$orderId');
    
    final order = orderRes.first;
    if (order['status'] == 'VOID') throw Exception('บิลถูกยกเลิกไปแล้ว ไม่สามารถเปลี่ยนสถานะได้');
    if (order['status'] == 'UNPAID') return; // Already unpaid
    
    // ป้องกันการเปลี่ยนบิลที่มีการชำระหนี้ไปแล้ว
    final paymentCheck = await _dbService.query(
      "SELECT id FROM debtor_transaction WHERE orderId = :oid AND transactionType = 'DEBT_PAYMENT' AND (isDeleted = 0 OR isDeleted IS NULL)",
      {'oid': orderId}
    );
    if (paymentCheck.isNotEmpty) {
      throw Exception('ไม่สามารถเปลี่ยนสถานะบิลที่ชำระหนี้แล้วได้ กรุณายกเลิกรายการรับชำระหนี้ก่อน');
    }

    final paymentMethod = order['paymentMethod']?.toString().toUpperCase() ?? '';
    final grandTotal = double.tryParse(order['grandTotal'].toString()) ?? 0.0;
    
    await _dbService.execute('START TRANSACTION;');
    try {
      // 2. ถ้าเป็นเครดิตที่ลงบัญชีไปแล้ว ต้องคืนยอดหนี้
      if (paymentMethod == 'CREDIT') {
        final debtTrans = await _dbService.query(
          "SELECT amount, customerId FROM debtor_transaction WHERE orderId = :oid AND transactionType = 'CREDIT_SALE' AND (isDeleted = 0 OR isDeleted IS NULL) FOR UPDATE",
          {'oid': orderId}
        );
        for (var t in debtTrans) {
          final double amount = double.tryParse(t['amount'].toString()) ?? 0.0;
          final int cid = int.tryParse(t['customerId'].toString()) ?? 0;
          if (cid > 0) {
            await _dbService.execute(
              'UPDATE customer SET currentDebt = currentDebt - :amt WHERE id = :id',
              {'amt': amount, 'id': cid}
            );
          }
        }
        await _dbService.execute(
          "UPDATE debtor_transaction SET isDeleted = 1, deletedAt = NOW(), deleteReason = 'เปลี่ยนเป็นยังไม่ได้จ่าย' WHERE orderId = :oid AND transactionType = 'CREDIT_SALE'",
          {'oid': orderId}
        );
        try {
          await _dbService.execute('DELETE FROM customer_ledger WHERE orderId = :oid AND action = "CREDIT_SALE"', {'oid': orderId});
        } catch (_) {}
      }

      // 3. เปลี่ยนสถานะบิลและลดยอดรับเงิน
      await _dbService.execute(
        "UPDATE `order` SET status = 'UNPAID', received = 0, paymentMethod = '' WHERE id = :id",
        {'id': orderId}
      );
      
      // 4. บันทึกประวัติ
      await _activityRepo.log(
        action: 'MARK_UNPAID',
        details: 'เปลี่ยนสถานะบิล #$orderId กลับเป็นยังไม่ได้จ่าย'
      );
      
      await _dbService.execute('COMMIT;');
      
      // 5. แจ้งเตือน Telegram (ใช้คีย์ลบบิล/ยกเลิกบิลแทน)
      if (await TelegramService().shouldNotify(TelegramService.keyNotifyDeleteBill)) {
        TelegramService().sendMessage(
          '🔄 *แจ้งเตือนแก้ไขบิล*\n'
          '━━━━━━━━━━━━━━━━━━\n'
          '🧾 *เลขที่บิล:* #$orderId\n'
          '💰 *ยอดเงิน:* ${grandTotal.toStringAsFixed(2)} บาท\n'
          '⚠️ *สถานะ:* ถูกเปลี่ยนเป็น "ยังไม่ได้จ่าย"'
        );
      }
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      LoggerService.error('SalesRepository', 'Error marking order as unpaid', e);
      rethrow;
    }
  }

}
