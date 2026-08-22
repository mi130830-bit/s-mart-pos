part of '../stock_repository.dart';

extension PurchaseOrderReceivingExtension on StockRepository {
  /// Receives only quantities still outstanding on this PO.  A supplied
  /// operation key is retained by the caller while it retries, so a lost
  /// response cannot add stock a second time.
  Future<int> receiveRemainingPurchaseOrder({
    required int poId,
    required String operationKey,
  }) async {
    final payloadHash = canonicalPayloadHash({'poId': poId, 'mode': 'FULL'});
    final outcome = await _runReceiptOperation(
      poId: poId,
      operationKey: operationKey,
      payloadHash: payloadHash,
      mode: 'FULL',
      apply: (header, items, notifyQueue) async {
        _validateReceivableHeader(header);
        _validateResolvedItems(items);
        final docNo = header['documentNo']?.toString() ?? '-';
        var receivedAny = false;
        for (final item in items) {
          final productId = _asInt(item['productId']);
          final ordered = _asDouble(item['quantity']);
          final received = _asDouble(item['receivedQuantity']);
          final remaining = ordered - received;
          if (remaining <= _receiptEpsilon) continue;
          final cost = _asDouble(item['costPrice']);
          receivedAny = true;
          await _dbService.execute('''
            UPDATE purchase_order_item
            SET receivedQuantity = quantity
            WHERE id = :itemId AND poId = :poId
          ''', {'itemId': item['id'], 'poId': poId});
          await _adjustRecursive(productId, remaining, 'PURCHASE_IN',
              'Ref: $docNo | Cost: $cost | PO: #$poId', null,
              maxDepth: 10);
          await _dbService.execute(
            'UPDATE product SET costPrice = :cost WHERE id = :id',
            {'cost': cost, 'id': productId},
          );
          notifyQueue.add({
            'id': productId,
            'qty': remaining,
            'type': 'PURCHASE_IN',
            'note': 'PO #$poId',
          });
        }
        if (!receivedAny) {
          throw StateError('ไม่มีจำนวนสินค้าคงเหลือให้รับเข้า');
        }
        await _updateReceiptHeader(poId, items, forceReceived: true);
      },
    );
    _notifyReceipt(outcome.notifications);
    return outcome.poId;
  }

  Future<int> receivePartialPurchaseOrder({
    required int originalPoId,
    required List<Map<String, dynamic>> receivedItems,
    required String operationKey,
  }) async {
    if (receivedItems.isEmpty) throw Exception('No items to receive');
    final normalizedItems = receivedItems
        .map((item) => {
              'productId': _asInt(item['productId']),
              'quantity': _asDouble(item['quantity']).toStringAsFixed(4),
              'costPrice': _asDouble(item['costPrice']).toStringAsFixed(4),
              'retailPrice': _asDouble(item['retailPrice']).toStringAsFixed(4),
            })
        .toList();
    final payloadHash = canonicalPayloadHash({
      'poId': originalPoId,
      'mode': 'PARTIAL',
      'items': normalizedItems,
    });
    final outcome = await _runReceiptOperation(
      poId: originalPoId,
      operationKey: operationKey,
      payloadHash: payloadHash,
      mode: 'PARTIAL',
      apply: (header, lockedItems, notifyQueue) async {
        _validateReceivableHeader(header);
        _validateResolvedItems(lockedItems);
        final byProduct = <int, Map<String, dynamic>>{};
        for (final item in lockedItems) {
          final productId = _asInt(item['productId']);
          if (byProduct.containsKey(productId)) {
            throw StateError('PO มีสินค้าเดิมซ้ำ จึงไม่ปลอดภัยที่จะรับสินค้า');
          }
          byProduct[productId] = item;
        }
        final seen = <int>{};
        final docNo = header['documentNo']?.toString() ?? '-';
        for (final requested in receivedItems) {
          final productId = _asInt(requested['productId']);
          final quantity = _asDouble(requested['quantity']);
          if (productId <= 0 ||
              quantity <= _receiptEpsilon ||
              !seen.add(productId)) {
            throw StateError('รายการรับสินค้าไม่ถูกต้องหรือมีสินค้าซ้ำ');
          }
          final line = byProduct[productId];
          if (line == null) {
            throw StateError('สินค้า #$productId ไม่อยู่ในใบสั่งซื้อ');
          }
          final remaining =
              _asDouble(line['quantity']) - _asDouble(line['receivedQuantity']);
          if (quantity - remaining > _receiptEpsilon) {
            throw StateError(
                'จำนวนรับสินค้าเกินยอดคงเหลือของสินค้า #$productId');
          }
          final cost = _asDouble(requested['costPrice']);
          final retail = _asDouble(requested['retailPrice']);
          await _dbService.execute('''
            UPDATE purchase_order_item
            SET receivedQuantity = receivedQuantity + :qty,
                costPrice = :cost, total = quantity * :cost
            WHERE id = :itemId AND poId = :poId
          ''', {
            'qty': quantity,
            'cost': cost,
            'itemId': line['id'],
            'poId': originalPoId,
          });
          await _adjustRecursive(productId, quantity, 'PURCHASE_IN',
              'Ref: $docNo | Cost: $cost | PO: #$originalPoId (Partial)', null,
              maxDepth: 10);
          await _dbService.execute(
            'UPDATE product SET costPrice = :cost, retailPrice = :retail WHERE id = :id',
            {'cost': cost, 'retail': retail, 'id': productId},
          );
          notifyQueue.add({
            'id': productId,
            'qty': quantity,
            'type': 'PURCHASE_IN',
            'note': 'PO #$originalPoId (Partial)',
          });
        }
        final refreshedItems = await _dbService.query(
          'SELECT id, productId, quantity, receivedQuantity, costPrice FROM purchase_order_item WHERE poId = :id FOR UPDATE',
          {'id': originalPoId},
        );
        await _updateReceiptHeader(originalPoId, refreshedItems);
      },
    );
    _notifyReceipt(outcome.notifications);
    return outcome.poId;
  }

  Future<_ReceiptOutcome> _runReceiptOperation({
    required int poId,
    required String operationKey,
    required String payloadHash,
    required String mode,
    required Future<void> Function(
            Map<String, dynamic> header,
            List<Map<String, dynamic>> items,
            List<Map<String, dynamic>> notifications)
        apply,
  }) async {
    if (operationKey.trim().isEmpty || operationKey.length > 64) {
      throw ArgumentError.value(
          operationKey, 'operationKey', 'ต้องเป็นรหัส UUID ที่ถูกต้อง');
    }
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.ensurePurchaseOrderReceiptOperationSchema();

    Future<_ReceiptOutcome?> reconcile() async {
      final rows = await _dbService.query('''
        SELECT poId, payloadHash, receiptMode FROM purchase_order_receipt_operation
        WHERE operationKey = :key LIMIT 1
      ''', {'key': operationKey});
      if (rows.isEmpty) return null;
      if (rows.first['payloadHash']?.toString() != payloadHash ||
          rows.first['receiptMode']?.toString() != mode ||
          _asInt(rows.first['poId']) != poId) {
        throw StateError('รหัสการรับสินค้าเดิมถูกใช้กับข้อมูลคนละชุด');
      }
      return _ReceiptOutcome(poId: poId, notifications: const []);
    }

    try {
      return await _dbService.runExclusiveTransaction(() async {
        await _dbService.execute('START TRANSACTION');
        try {
          final existing = await _lockOrCreateReceiptOperation(
            poId: poId,
            operationKey: operationKey,
            payloadHash: payloadHash,
            mode: mode,
          );
          if (existing) {
            await _dbService.execute('COMMIT');
            return _ReceiptOutcome(poId: poId, notifications: const []);
          }
          final headers = await _dbService.query(
            'SELECT id, documentNo, status, vatType FROM purchase_order WHERE id = :id FOR UPDATE',
            {'id': poId},
          );
          if (headers.length != 1) throw StateError('ไม่พบใบสั่งซื้อ');
          final items = await _dbService.query('''
            SELECT id, productId, quantity, receivedQuantity, costPrice
            FROM purchase_order_item WHERE poId = :id FOR UPDATE
          ''', {'id': poId});
          if (items.isEmpty) throw StateError('ไม่พบรายการสินค้าในใบสั่งซื้อ');
          final notifications = <Map<String, dynamic>>[];
          await apply(headers.first, items, notifications);
          await _writePurchaseOrderAudit(
            poId: poId,
            eventType: 'RECEIPT_$mode',
            operationKey: operationKey,
            payload: {
              'header': headers.first,
              'items': items,
              'payloadHash': payloadHash,
            },
          );
          await _dbService.execute('''
            UPDATE purchase_order_receipt_operation
            SET completedAt = NOW() WHERE operationKey = :key
          ''', {'key': operationKey});
          await _dbService.execute('COMMIT');
          return _ReceiptOutcome(poId: poId, notifications: notifications);
        } catch (_) {
          try {
            await _dbService.execute('ROLLBACK');
          } catch (_) {
            // The operation-key reconciliation below is the only safe retry.
          }
          rethrow;
        }
      });
    } catch (_) {
      final completed = await reconcile();
      if (completed != null) return completed;
      rethrow;
    }
  }

  Future<bool> _lockOrCreateReceiptOperation({
    required int poId,
    required String operationKey,
    required String payloadHash,
    required String mode,
  }) async {
    final insert = await _dbService.execute('''
      INSERT INTO purchase_order_receipt_operation
        (poId, operationKey, payloadHash, receiptMode)
      VALUES (:poId, :key, :hash, :mode)
      ON DUPLICATE KEY UPDATE operationKey = VALUES(operationKey)
    ''',
        {'poId': poId, 'key': operationKey, 'hash': payloadHash, 'mode': mode});
    final rows = await _dbService.query('''
      SELECT poId, payloadHash, receiptMode FROM purchase_order_receipt_operation
      WHERE operationKey = :key FOR UPDATE
    ''', {'key': operationKey});
    if (rows.length != 1) throw StateError('ไม่สามารถยืนยันรหัสการรับสินค้า');
    final row = rows.first;
    if (_asInt(row['poId']) != poId ||
        row['payloadHash']?.toString() != payloadHash ||
        row['receiptMode']?.toString() != mode) {
      throw StateError('รหัสการรับสินค้าเดิมถูกใช้กับข้อมูลคนละชุด');
    }
    // The row can only exist here if a previous transaction committed it.
    // `affectedRows == 1` means this transaction created the operation row.
    return insert.affectedRows.toInt() != 1;
  }

  void _validateReceivableHeader(Map<String, dynamic> header) {
    final status = header['status']?.toString() ?? '';
    if (!{'DRAFT', 'ORDERED', 'PARTIAL'}.contains(status)) {
      throw StateError('ใบสั่งซื้อนี้ไม่อยู่ในสถานะที่รับสินค้าได้');
    }
  }

  void _validateResolvedItems(List<Map<String, dynamic>> items) {
    if (items.any((item) => _asInt(item['productId']) <= 0)) {
      throw StateError(
          'มีรายการที่ยังไม่ได้จับคู่สินค้า กรุณาแก้ไขใบสั่งซื้อก่อนรับสินค้า');
    }
  }

  Future<void> _updateReceiptHeader(int poId, List<Map<String, dynamic>> items,
      {bool forceReceived = false}) async {
    final allCompleted = forceReceived ||
        items.every((item) =>
            _asDouble(item['receivedQuantity']) + _receiptEpsilon >=
            _asDouble(item['quantity']));
    final anyReceived = items
        .any((item) => _asDouble(item['receivedQuantity']) > _receiptEpsilon);
    var status = 'ORDERED';
    if (allCompleted) {
      status = 'RECEIVED';
    } else if (anyReceived) {
      status = 'PARTIAL';
    }
    final totalRows = await _dbService.query(
      'SELECT COALESCE(SUM(total), 0) AS total FROM purchase_order_item WHERE poId = :id',
      {'id': poId},
    );
    var total = totalRows.isEmpty ? 0.0 : _asDouble(totalRows.first['total']);
    final vatRows = await _dbService.query(
        'SELECT vatType FROM purchase_order WHERE id = :id', {'id': poId});
    if (vatRows.isNotEmpty && _asInt(vatRows.first['vatType']) == 1) {
      total *= 1.07;
    }
    await _dbService.execute('''
      UPDATE purchase_order
      SET status = :status, totalAmount = :total, updatedAt = NOW()
      WHERE id = :id
    ''', {'status': status, 'total': total, 'id': poId});
  }

  void _notifyReceipt(List<Map<String, dynamic>> notifications) {
    for (final item in notifications) {
      _checkAndNotify(item['id'] as int, item['qty'] as double,
          item['type'] as String, item['note'] as String);
    }
  }

  int _asInt(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;
  double _asDouble(Object? value) =>
      double.tryParse(value?.toString() ?? '') ?? 0.0;

  Future<int> closePartialPurchaseOrder({
    required int poId,
    required String operationKey,
  }) async {
    final payloadHash = canonicalPayloadHash({'poId': poId, 'mode': 'CLOSE'});
    final outcome = await _runReceiptOperation(
      poId: poId,
      operationKey: operationKey,
      payloadHash: payloadHash,
      mode: 'CLOSE',
      apply: (header, items, _) async {
        if (header['status']?.toString() != 'PARTIAL') {
          throw StateError('ปิดได้เฉพาะใบสั่งซื้อที่รับบางส่วนเท่านั้น');
        }
        // Keep the immutable pre-close snapshot in the audit log, then cancel
        // every outstanding quantity by reducing each line to what was received.
        await _dbService.execute('''
          UPDATE purchase_order_item
          SET quantity = receivedQuantity,
              total = receivedQuantity * costPrice
          WHERE poId = :id
        ''', {'id': poId});
        final totalRows = await _dbService.query('''
          SELECT COALESCE(SUM(total), 0) AS total
          FROM purchase_order_item WHERE poId = :id
        ''', {'id': poId});
        var total =
            totalRows.isEmpty ? 0.0 : _asDouble(totalRows.first['total']);
        if (_asInt(header['vatType']) == 1) total *= 1.07;
        await _dbService.execute('''
          UPDATE purchase_order
          SET status = 'RECEIVED', totalAmount = :total, updatedAt = NOW()
          WHERE id = :id AND status = 'PARTIAL'
        ''', {'id': poId, 'total': total});
      },
    );
    return outcome.poId;
  }

  Future<void> updateReceivedPurchaseOrderQty({
    required int poId,
    required List<Map<String, dynamic>> newItems,
    required double totalAmount,
    String? documentNo,
    String? note,
    int vatType = 0,
    bool isPaid = false,
  }) async {
    throw StateError(
        'ไม่อนุญาตให้แก้ไขใบที่เริ่มรับสินค้าแล้ว กรุณาใช้การรับสินค้าแบบปลอดภัยแทน');
  }

  Future<void> _writePurchaseOrderAudit({
    required int poId,
    required String eventType,
    String? operationKey,
    required Map<String, dynamic> payload,
  }) =>
      _dbService.execute('''
        INSERT INTO purchase_order_audit_log
          (poId, eventType, operationKey, payloadJson)
        VALUES (:poId, :eventType, :operationKey, :payload)
      ''', {
        'poId': poId,
        'eventType': eventType,
        'operationKey': operationKey,
        'payload': jsonEncode(payload),
      });
}

class _ReceiptOutcome {
  const _ReceiptOutcome({required this.poId, required this.notifications});

  final int poId;
  final List<Map<String, dynamic>> notifications;
}

const double _receiptEpsilon = 0.000001;
