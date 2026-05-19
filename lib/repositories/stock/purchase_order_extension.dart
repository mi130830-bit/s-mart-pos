part of '../stock_repository.dart';

extension PurchaseOrderExtension on StockRepository {
  Future<int> createPurchaseOrder({
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
    await _dbService.execute('START TRANSACTION;');

    try {
      final res = await _dbService.execute(
        '''
        INSERT INTO purchase_order (supplierId, documentNo, totalAmount, status, note, vatType, isPaid, createdAt)
        VALUES (:supId, :docNo, :total, :status, :note, :vat, :paid, NOW())
        ''',
        {
          'supId': supplierId,
          'docNo': documentNo,
          'total': totalAmount,
          'status': status,
          'note': note,
          'vat': vatType,
          'paid': isPaid ? 1 : 0,
        },
      );
      final poId = res.lastInsertID.toInt();

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

      if (status == 'RECEIVED') {
        for (var item in items) {
          final pId = int.tryParse(item['productId'].toString()) ?? 0;
          final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
          final doc = documentNo ?? '-';
          if (pId == 0) continue;
          await _adjustRecursive(pId, qty, 'PURCHASE_IN',
              'Ref: $doc | Cost: $cost | PO: #$poId', null);
          await _dbService.execute(
            'UPDATE product SET costPrice = :cost WHERE id = :id',
            {'cost': cost, 'id': pId},
          );
        }
      }

      await _dbService.execute('COMMIT;');
      return poId;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
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
    await _dbService.execute('START TRANSACTION;');

    try {
      final oldPoRes = await _dbService.query(
        'SELECT status FROM purchase_order WHERE id = :id FOR UPDATE',
        {'id': poId},
      );

      if (oldPoRes.isNotEmpty) {
        final oldStatus = oldPoRes.first['status'];
        if (oldStatus == 'RECEIVED' || oldStatus == 'PARTIAL') {
          final oldItems = await _dbService.query(
            'SELECT productId, quantity, receivedQuantity FROM purchase_order_item WHERE poId = :id',
            {'id': poId},
          );
          for (var item in oldItems) {
            final pId = int.tryParse(item['productId'].toString()) ?? 0;
            double revertQty = 0.0;
            if (oldStatus == 'RECEIVED') {
              revertQty = double.tryParse(item['quantity'].toString()) ?? 0.0;
            } else if (oldStatus == 'PARTIAL') {
              revertQty =
                  double.tryParse(item['receivedQuantity'].toString()) ?? 0.0;
            }
            if (pId > 0 && revertQty > 0) {
              await _adjustRecursive(
                  pId, -revertQty, 'ADJUST_CORRECT', 'Edit PO #$poId (Reversal)', null);
            }
          }
        }
      }

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

      if (status == 'RECEIVED') {
        for (var item in items) {
          final pId = int.tryParse(item['productId'].toString()) ?? 0;
          final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
          final doc = documentNo ?? '-';
          if (pId == 0) continue;
          await _adjustRecursive(pId, qty, 'PURCHASE_IN',
              'Ref: $doc | Cost: $cost | PO: #$poId', null);
          await _dbService.execute(
            'UPDATE product SET costPrice = :cost WHERE id = :id',
            {'cost': cost, 'id': pId},
          );
        }
        for (var item in items) {
          final pId = int.tryParse(item['productId'].toString()) ?? 0;
          final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          if (pId != 0) _checkAndNotify(pId, qty, 'PURCHASE_IN', 'PO #$poId');
        }
      }

      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error updating PO: $e');
      rethrow;
    }
  }

  Future<void> receivePurchaseOrder(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    final items = await _dbService
        .query('SELECT * FROM purchase_order_item WHERE poId = :id', {'id': poId});
    final header = await _dbService
        .query('SELECT * FROM purchase_order WHERE id = :id', {'id': poId});

    if (items.isEmpty || header.isEmpty) throw Exception('PO not found');

    final docNo = header.first['documentNo'] ?? '-';
    final List<Map<String, dynamic>> notifyQueue = [];

    await _dbService.execute('START TRANSACTION;');

    try {
      for (var item in items) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        if (pId == 0) continue;
        await _adjustRecursive(pId, qty, 'PURCHASE_IN',
            'Ref: $docNo | Cost: $cost | PO: #$poId', null,
            maxDepth: 10);
        await _dbService.execute(
          'UPDATE product SET costPrice = :cost WHERE id = :id',
          {'cost': cost, 'id': pId},
        );
        notifyQueue
            .add({'id': pId, 'qty': qty, 'type': 'PURCHASE_IN', 'note': 'PO #$poId'});
      }

      await _dbService.execute(
        "UPDATE purchase_order SET status = 'RECEIVED', updatedAt = NOW() WHERE id = :id",
        {'id': poId},
      );
      await _dbService.execute('COMMIT;');

      for (var n in notifyQueue) {
        _checkAndNotify(n['id'], n['qty'], n['type'], n['note']);
      }
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      rethrow;
    }
  }

  Future<void> deletePurchaseOrder(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    final headerRes = await _dbService.query(
        'SELECT status FROM purchase_order WHERE id = :id', {'id': poId});
    if (headerRes.isEmpty) return;

    final status = headerRes.first['status'];
    if (status == 'CANCELLED') return;

    await _dbService.execute('START TRANSACTION;');

    try {
      if (status == 'RECEIVED' || status == 'PARTIAL') {
        final items = await _dbService.query(
            'SELECT productId, quantity, receivedQuantity FROM purchase_order_item WHERE poId = :id',
            {'id': poId});
        for (var item in items) {
          final pId = int.tryParse(item['productId'].toString()) ?? 0;
          double revertQty = 0.0;
          if (status == 'RECEIVED') {
            revertQty = double.tryParse(item['quantity'].toString()) ?? 0.0;
          } else if (status == 'PARTIAL') {
            revertQty =
                double.tryParse(item['receivedQuantity'].toString()) ?? 0.0;
          }
          if (pId > 0 && revertQty > 0) {
            await _adjustRecursive(
                pId, -revertQty, 'ADJUST_CORRECT', 'Void PO #$poId', null);
          }
        }
      }

      await _dbService.execute(
        "UPDATE purchase_order SET status = 'CANCELLED', updatedAt = NOW() WHERE id = :id",
        {'id': poId},
      );
      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error deleting PO: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrders({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int? supplierId,
    bool? isPaid,
    int limit = 50,
    int offset = 0,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    final List<String> conditions = [];
    final params = <String, dynamic>{'limit': limit, 'offset': offset};

    if (status != null) {
      conditions.add('po.status = :status');
      params['status'] = status;
    }
    if (startDate != null) {
      conditions.add('po.createdAt >= :startDate');
      params['startDate'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      conditions.add('po.createdAt <= :endDate');
      params['endDate'] = endDate.toIso8601String();
    }
    if (supplierId != null) {
      conditions.add('po.supplierId = :supplierId');
      params['supplierId'] = supplierId;
    }
    if (isPaid != null) {
      conditions.add('po.isPaid = :isPaid');
      params['isPaid'] = isPaid ? 1 : 0;
    }

    String whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(" AND ")}' : '';

    final sql = '''
      SELECT po.id, po.supplierId, po.documentNo, po.totalAmount, po.status,
             po.note, po.vatType, po.isPaid, po.createdAt, po.updatedAt,
             s.name as supplierName, 
             (SELECT COUNT(*) FROM purchase_order_item WHERE poId = po.id) as itemCount
      FROM purchase_order po
      LEFT JOIN supplier s ON po.supplierId = s.id
      $whereClause
      ORDER BY po.createdAt DESC
      LIMIT :limit OFFSET :offset
    ''';

    return await _dbService.query(sql, params);
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrderItems(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    const sql = 'SELECT * FROM purchase_order_item WHERE poId = :id';
    return await _dbService.query(sql, {'id': poId});
  }

  Future<Map<String, dynamic>?> getPurchaseOrderById(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    final sql = '''
      SELECT po.*, s.name as supplierName, 
             (SELECT COUNT(*) FROM purchase_order_item WHERE poId = po.id) as itemCount
      FROM purchase_order po
      LEFT JOIN supplier s ON po.supplierId = s.id
      WHERE po.id = :id
    ''';
    final res = await _dbService.query(sql, {'id': id});
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> receivePartialPurchaseOrder({
    required int originalPoId,
    required List<Map<String, dynamic>> receivedItems,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    if (receivedItems.isEmpty) throw Exception('No items to receive');

    await _dbService.execute('START TRANSACTION;');

    try {
      final docNoRes = await _dbService.query(
          'SELECT documentNo FROM purchase_order WHERE id = :id',
          {'id': originalPoId});
      final docNo = docNoRes.isNotEmpty ? docNoRes.first['documentNo'] : '-';

      for (var item in receivedItems) {
        final int pId = int.tryParse(item['productId'].toString()) ?? 0;
        final double qtyReceivedNow =
            double.tryParse(item['quantity'].toString()) ?? 0;
        final double cost = double.tryParse(item['costPrice'].toString()) ?? 0;
        if (pId == 0 || qtyReceivedNow <= 0) continue;

        await _dbService.execute(
          '''
          UPDATE purchase_order_item 
          SET receivedQuantity = receivedQuantity + :qty,
              costPrice = :cost, 
              total = quantity * :cost 
          WHERE poId = :poId AND productId = :pId
          ''',
          {'qty': qtyReceivedNow, 'cost': cost, 'poId': originalPoId, 'pId': pId},
        );
        await _adjustRecursive(pId, qtyReceivedNow, 'PURCHASE_IN',
            'Ref: $docNo | Cost: $cost | PO: #$originalPoId (Partial)', null);
        await _dbService.execute(
          'UPDATE product SET costPrice = :cost WHERE id = :id',
          {'cost': cost, 'id': pId},
        );
      }

      final itemsRes = await _dbService.query(
        'SELECT quantity, receivedQuantity FROM purchase_order_item WHERE poId = :id',
        {'id': originalPoId},
      );

      bool allCompleted = true;
      bool anyReceived = false;
      for (var row in itemsRes) {
        double qty = double.tryParse(row['quantity'].toString()) ?? 0;
        double recv = double.tryParse(row['receivedQuantity'].toString()) ?? 0;
        if (recv > 0) anyReceived = true;
        if (recv < qty) allCompleted = false;
      }

      String newStatus = 'ORDERED';
      if (allCompleted && itemsRes.isNotEmpty) {
        newStatus = 'RECEIVED';
      } else if (anyReceived) {
        newStatus = 'PARTIAL';
      }

      await _dbService.execute(
        'UPDATE purchase_order SET status = :status, updatedAt = NOW() WHERE id = :id',
        {'status': newStatus, 'id': originalPoId},
      );

      await _dbService.execute('COMMIT;');
      return originalPoId;
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error partial receiving PO: $e');
      rethrow;
    }
  }

  Future<void> closePartialPurchaseOrder(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    final headerRes = await _dbService.query(
        'SELECT status FROM purchase_order WHERE id = :id', {'id': poId});
    if (headerRes.isEmpty || headerRes.first['status'] != 'PARTIAL') return;

    await _dbService.execute('START TRANSACTION;');

    try {
      await _dbService.execute(
        'DELETE FROM purchase_order_item WHERE poId = :id AND receivedQuantity <= 0',
        {'id': poId},
      );
      await _dbService.execute(
        '''
        UPDATE purchase_order_item 
        SET quantity = receivedQuantity,
            total = receivedQuantity * costPrice
        WHERE poId = :id AND receivedQuantity > 0
        ''',
        {'id': poId},
      );

      final totalRes = await _dbService.query(
        'SELECT SUM(total) as newTotal FROM purchase_order_item WHERE poId = :id',
        {'id': poId},
      );
      double newTotal = 0.0;
      if (totalRes.isNotEmpty && totalRes.first['newTotal'] != null) {
        newTotal = double.tryParse(totalRes.first['newTotal'].toString()) ?? 0.0;
      }

      final vatRes = await _dbService.query(
          'SELECT vatType FROM purchase_order WHERE id = :id', {'id': poId});
      int vatType = 0;
      if (vatRes.isNotEmpty) {
        vatType = int.tryParse(vatRes.first['vatType'].toString()) ?? 0;
      }
      if (vatType == 1) newTotal = newTotal * 1.07;

      await _dbService.execute(
        "UPDATE purchase_order SET status = 'RECEIVED', totalAmount = :total, updatedAt = NOW() WHERE id = :id",
        {'id': poId, 'total': newTotal},
      );
      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error closing partial PO: $e');
      rethrow;
    }
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
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      final oldItems = await _dbService.query(
        'SELECT productId, quantity, costPrice FROM purchase_order_item WHERE poId = :id FOR UPDATE',
        {'id': poId},
      );
      final docNo = documentNo ?? '-';

      for (var item in oldItems) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final oldQty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        if (pId > 0 && oldQty > 0) {
          await _adjustRecursive(
              pId, -oldQty, 'ADJUST_CORRECT', 'Edit PO #$poId (Revert Old)', null);
        }
      }

      await _dbService.execute(
        'DELETE FROM purchase_order_item WHERE poId = :id',
        {'id': poId},
      );

      for (var item in newItems) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        final total = qty * cost;
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
            'recvQty': qty,
            'cost': cost,
            'total': total,
          },
        );
      }

      for (var item in newItems) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        if (pId == 0 || qty <= 0) continue;
        await _adjustRecursive(pId, qty, 'PURCHASE_IN',
            'Ref: $docNo | Cost: $cost | PO: #$poId (Edited)', null);
        await _dbService.execute(
          'UPDATE product SET costPrice = :cost WHERE id = :id',
          {'cost': cost, 'id': pId},
        );
      }

      double recalcTotal = newItems.fold(0.0, (sum, item) {
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        final cost = double.tryParse(item['costPrice'].toString()) ?? 0.0;
        return sum + (qty * cost);
      });
      final finalTotal = totalAmount > 0 ? totalAmount : recalcTotal;

      await _dbService.execute(
        '''
        UPDATE purchase_order 
        SET totalAmount = :total, vatType = :vat, note = :note,
            isPaid = :paid, updatedAt = NOW()
        WHERE id = :id
        ''',
        {
          'total': finalTotal,
          'vat': vatType,
          'note': note,
          'paid': isPaid ? 1 : 0,
          'id': poId,
        },
      );

      await _dbService.execute('COMMIT;');

      for (var item in newItems) {
        final pId = int.tryParse(item['productId'].toString()) ?? 0;
        final qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        if (pId != 0 && qty > 0) {
          _checkAndNotify(pId, qty, 'PURCHASE_IN', 'แก้ไข PO #$poId');
        }
      }
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error updating received PO qty: $e');
      rethrow;
    }
  }

  Future<void> deleteAdjustmentGroup(List<int> ledgerIds) async {
    if (ledgerIds.isEmpty) return;
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute('START TRANSACTION;');

    try {
      for (var id in ledgerIds) {
        final res = await _dbService.query(
            'SELECT * FROM stockledger WHERE id = :id FOR UPDATE', {'id': id});
        if (res.isEmpty) continue;

        final row = res.first;
        final pId = int.tryParse(row['productId'].toString()) ?? 0;
        final qtyChange =
            double.tryParse(row['quantityChange'].toString()) ?? 0.0;

        if (pId != 0 && qtyChange != 0) {
          await _adjustRecursive(pId, -qtyChange, 'ADJUST_CORRECT', 'Undo #$id',
              null,
              maxDepth: 10);
        }
        await _dbService
            .execute('DELETE FROM stockledger WHERE id = :id', {'id': id});
      }
      await _dbService.execute('COMMIT;');
    } catch (e) {
      await _dbService.execute('ROLLBACK;');
      debugPrint('Error deleting adjustment group: $e');
      rethrow;
    }
  }

  Future<void> updatePaymentStatus(int poId, bool isPaid) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute(
      'UPDATE purchase_order SET isPaid = :paid, updatedAt = NOW() WHERE id = :id',
      {'paid': isPaid ? 1 : 0, 'id': poId},
    );
  }
}
