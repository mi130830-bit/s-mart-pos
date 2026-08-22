part of '../stock_repository.dart';

extension PurchaseOrderCommandExtension on StockRepository {
  Future<int> createPurchaseOrder({
    required String idempotencyKey,
    required int supplierId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? documentNo,
    String? note,
    String status = 'DRAFT',
    int vatType = 0,
    bool isPaid = false,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    if (!{'DRAFT', 'ORDERED'}.contains(status)) {
      throw StateError(
          'สร้าง PO ได้เฉพาะ DRAFT หรือ ORDERED; กรุณาใช้ขั้นตอนรับสินค้าแบบปลอดภัย');
    }
    await _dbService.ensurePurchaseOrderAuditSchema();
    final payloadHash = canonicalPayloadHash({
      'supplierId': supplierId,
      'totalAmount': totalAmount.toStringAsFixed(4),
      'documentNo': documentNo ?? '',
      'note': note ?? '',
      'status': status,
      'vatType': vatType,
      'isPaid': isPaid,
      'items': items
          .map((item) => {
                'productId': item['productId'].toString(),
                'productName': item['productName'].toString(),
                'quantity': item['quantity'].toString(),
                'costPrice': item['costPrice'].toString(),
                'retailPrice': item['retailPrice'].toString(),
                'total': item['total'].toString(),
              })
          .toList(),
    });

    Future<int?> reconcile() async {
      final rows = await _dbService.query('''
        SELECT id, idempotencyPayloadHash FROM purchase_order
        WHERE idempotencyKey = :key LIMIT 1
      ''', {'key': idempotencyKey});
      if (rows.isEmpty) return null;
      if (rows.first['idempotencyPayloadHash']?.toString() != payloadHash) {
        throw StateError('รหัสคำสั่งซื้อเดิมถูกใช้กับข้อมูลคนละชุด');
      }
      return int.parse(rows.first['id'].toString());
    }

    try {
      return await _dbService.runExclusiveTransaction(() async {
        final previous = await reconcile();
        if (previous != null) return previous;
        await _dbService.execute('START TRANSACTION;');
        try {
          final res = await _dbService.execute(
            '''
        INSERT INTO purchase_order (supplierId, documentNo, totalAmount, status, note, vatType, isPaid, idempotencyKey, idempotencyPayloadHash, createdAt)
        VALUES (:supId, :docNo, :total, :status, :note, :vat, :paid, :idempotencyKey, :payloadHash, NOW())
        ''',
            {
              'supId': supplierId,
              'docNo': documentNo,
              'total': totalAmount,
              'status': status,
              'note': note,
              'vat': vatType,
              'paid': isPaid ? 1 : 0,
              'idempotencyKey': idempotencyKey,
              'payloadHash': payloadHash,
            },
          );
          final poId = res.lastInsertID.toInt();

          for (var item in items) {
            final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
            await _dbService.execute(
              '''
          INSERT INTO purchase_order_item (poId, productId, productName, quantity, receivedQuantity, costPrice, total)
          VALUES (:poId, :pId, :pName, :qty, :recvQty, :cost, :total)
          ''',
              {
                'poId': poId,
                'pId': item['productId'],
                'pName': item['productName'],
                'qty': qty,
                'recvQty': 0,
                'cost': item['costPrice'],
                'total': item['total'],
              },
            );
          }

          await _writePurchaseOrderAudit(
            poId: poId,
            eventType: 'PO_CREATED',
            payload: {
              'status': status,
              'supplierId': supplierId,
              'totalAmount': totalAmount,
              'items': items,
            },
          );

          await _dbService.execute('COMMIT;');
          return poId;
        } catch (e) {
          try {
            await _dbService.execute('ROLLBACK;');
          } catch (_) {
            // The outer reconciliation handles a lost COMMIT/ROLLBACK reply.
          }
          rethrow;
        }
      });
    } catch (e) {
      // If MySQL committed but its reply was lost (or another workstation won
      // the unique-key race), return only the matching original operation.
      final previous = await reconcile();
      if (previous != null) return previous;
      debugPrint('Error creating PO: $e');
      rethrow;
    }
  }

  Future<void> updatePurchaseOrder({
    required int poId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? documentNo,
    String? note,
    String status = 'ORDERED',
    int vatType = 0,
    bool isPaid = false,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    if (!{'DRAFT', 'ORDERED'}.contains(status)) {
      throw StateError('แก้ไขใบสั่งซื้อได้เฉพาะสถานะ DRAFT หรือ ORDERED');
    }
    await _dbService.ensurePurchaseOrderAuditSchema();
    await _dbService.runExclusiveTransaction(() async {
      await _dbService.execute('START TRANSACTION');
      try {
        await _lockMutablePurchaseOrder(poId);

        await _dbService.execute(
          '''
        UPDATE purchase_order 
        SET totalAmount = :total, documentNo = :docNo, note = :note, status = :status, vatType = :vat,
            isPaid = :paid, updatedAt = NOW()
        WHERE id = :id
        ''',
          {
            'total': totalAmount,
            'docNo': documentNo,
            'note': note,
            'status': status,
            'vat': vatType,
            'paid': isPaid ? 1 : 0,
            'id': poId,
          },
        );

        await _dbService.execute(
          'DELETE FROM purchase_order_item WHERE poId = :id',
          {'id': poId},
        );

        for (var item in items) {
          final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          final recvQty = (status == 'RECEIVED') ? qty : 0.0;
          await _dbService.execute(
            '''
          INSERT INTO purchase_order_item (poId, productId, productName, quantity, receivedQuantity, costPrice, total)
          VALUES (:poId, :pId, :pName, :qty, :recvQty, :cost, :total)
          ''',
            {
              'poId': poId,
              'pId': item['productId'],
              'pName': item['productName'],
              'qty': qty,
              'recvQty': recvQty,
              'cost': item['costPrice'],
              'total': item['total'],
            },
          );
        }

        await _writePurchaseOrderAudit(
          poId: poId,
          eventType: 'PO_UPDATED',
          payload: {
            'status': status,
            'totalAmount': totalAmount,
            'items': items
          },
        );
        await _dbService.execute('COMMIT');
      } catch (_) {
        try {
          await _dbService.execute('ROLLBACK');
        } catch (_) {}
        rethrow;
      }
    });
  }

  Future<void> deletePurchaseOrder(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    await _dbService.ensurePurchaseOrderAuditSchema();
    await _dbService.runExclusiveTransaction(() async {
      await _dbService.execute('START TRANSACTION');
      try {
        await _lockMutablePurchaseOrder(poId);
        await _dbService.execute(
          "UPDATE purchase_order SET status = 'CANCELLED', updatedAt = NOW() WHERE id = :id",
          {'id': poId},
        );
        await _writePurchaseOrderAudit(
          poId: poId,
          eventType: 'PO_CANCELLED',
          payload: const {'reason': 'User cancelled mutable purchase order'},
        );
        await _dbService.execute('COMMIT');
      } catch (_) {
        try {
          await _dbService.execute('ROLLBACK');
        } catch (_) {}
        rethrow;
      }
    });
  }

  Future<void> updatePaymentStatus(int poId, bool isPaid) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute(
      'UPDATE purchase_order SET isPaid = :paid, updatedAt = NOW() WHERE id = :id',
      {'paid': isPaid ? 1 : 0, 'id': poId},
    );
  }

  Future<void> _lockMutablePurchaseOrder(int poId) async {
    final headers = await _dbService.query('''
      SELECT id, status FROM purchase_order WHERE id = :id FOR UPDATE
    ''', {'id': poId});
    if (headers.length != 1) throw StateError('ไม่พบใบสั่งซื้อ');
    final status = headers.first['status']?.toString() ?? '';
    if (!{'DRAFT', 'ORDERED'}.contains(status)) {
      throw StateError('ใบที่เริ่มรับสินค้าแล้วหรือปิดแล้วห้ามแก้ไข/ลบ');
    }
    final received = await _dbService.query('''
      SELECT id FROM purchase_order_item
      WHERE poId = :id AND receivedQuantity > 0 LIMIT 1 FOR UPDATE
    ''', {'id': poId});
    if (received.isNotEmpty) {
      throw StateError('ใบที่มีการรับสินค้าแล้วห้ามแก้ไข/ลบ');
    }
  }

  Future<void> _writePurchaseOrderAudit({
    required int poId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) =>
      _dbService.execute('''
        INSERT INTO purchase_order_audit_log (poId, eventType, payloadJson)
        VALUES (:poId, :eventType, :payload)
      ''', {
        'poId': poId,
        'eventType': eventType,
        'payload': jsonEncode(payload),
      });
}
