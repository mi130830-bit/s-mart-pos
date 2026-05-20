part of '../stock_repository.dart';

extension PurchaseOrderCommandExtension on StockRepository {
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
      // Revert previous stock changes if PO was received or partially received
      await _revertStockForPurchaseOrder(poId, note: 'Edit PO #$poId (Reversal)');

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

  Future<void> deletePurchaseOrder(int poId) async {
    if (!_dbService.isConnected()) await _dbService.connect();

    final headerRes = await _dbService.query(
        'SELECT status FROM purchase_order WHERE id = :id', {'id': poId});
    if (headerRes.isEmpty) return;

    final status = headerRes.first['status'];
    if (status == 'CANCELLED') return;

    await _dbService.execute('START TRANSACTION;');

    try {
      // Revert previous stock changes if PO was received or partially received
      await _revertStockForPurchaseOrder(poId, note: 'Void PO #$poId');

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

  Future<void> updatePaymentStatus(int poId, bool isPaid) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    await _dbService.execute(
      'UPDATE purchase_order SET isPaid = :paid, updatedAt = NOW() WHERE id = :id',
      {'paid': isPaid ? 1 : 0, 'id': poId},
    );
  }
}
