part of '../stock_repository.dart';

extension PurchaseOrderReceivingExtension on StockRepository {
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

      final totalRes = await _dbService.query(
        'SELECT SUM(total) as newTotal FROM purchase_order_item WHERE poId = :id',
        {'id': originalPoId},
      );
      double newTotal = 0.0;
      if (totalRes.isNotEmpty && totalRes.first['newTotal'] != null) {
        newTotal = double.tryParse(totalRes.first['newTotal'].toString()) ?? 0.0;
      }

      final vatRes = await _dbService.query(
          'SELECT vatType FROM purchase_order WHERE id = :id', {'id': originalPoId});
      int vatType = 0;
      if (vatRes.isNotEmpty) {
        vatType = int.tryParse(vatRes.first['vatType'].toString()) ?? 0;
      }
      if (vatType == 1) newTotal = newTotal * 1.07;

      await _dbService.execute(
        'UPDATE purchase_order SET status = :status, totalAmount = :total, updatedAt = NOW() WHERE id = :id',
        {'status': newStatus, 'total': newTotal, 'id': originalPoId},
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
      // Revert previous stock changes if PO was received or partially received
      await _revertStockForPurchaseOrder(poId, note: 'Edit PO #$poId (Revert Old)');

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

      final docNo = documentNo ?? '-';
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
}
