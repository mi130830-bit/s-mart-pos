import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db_config.dart';

/// Mobile may only create a reviewable PO draft.  Receiving remains a Desktop
/// operation so this endpoint deliberately never writes stock, prices or ledger.
class PurchaseOrderController {
  Router get router {
    final router = Router();
    router.post('/drafts', _createDraft);
    return router;
  }

  Future<Response> _createDraft(Request request) async {
    final user = request.context['user'];
    final role = user is Map ? user['role']?.toString().toUpperCase() : null;
    if (role != 'ADMIN' && role != 'CASHIER') {
      return Response.forbidden(
        jsonEncode({
          'error': 'Only ADMIN or CASHIER may create purchase-order drafts',
        }),
      );
    }

    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid request body');
      }
      final key = decoded['receiptId']?.toString().trim() ?? '';
      final supplierId =
          int.tryParse(decoded['supplierId']?.toString() ?? '') ?? 0;
      final rawItems = decoded['items'];
      if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(key) ||
          supplierId <= 0 ||
          rawItems is! List ||
          rawItems.isEmpty) {
        return _bad(
          'receiptId (UUID), supplier and at least one item are required',
        );
      }

      final items = <Map<String, dynamic>>[];
      for (final raw in rawItems) {
        if (raw is! Map) return _bad('Invalid item');
        final productId = int.tryParse(raw['productId']?.toString() ?? '') ?? 0;
        final name = raw['productName']?.toString().trim() ?? '';
        final qty = double.tryParse(raw['quantity']?.toString() ?? '');
        final cost = double.tryParse(raw['costPrice']?.toString() ?? '');
        final total = double.tryParse(raw['total']?.toString() ?? '');
        if (name.isEmpty ||
            name.length > 255 ||
            qty == null ||
            cost == null ||
            total == null ||
            qty <= 0 ||
            cost <= 0 ||
            total <= 0 ||
            qty > 999999 ||
            cost > 99999999 ||
            total > 99999999) {
          return _bad(
            'Each item needs a name and positive quantity, unit cost and total',
          );
        }
        // Quantity/cost are persisted with 4 decimal places; total with 2.
        if (!_decimal(raw['quantity'], 4) ||
            !_decimal(raw['costPrice'], 4) ||
            !_decimal(raw['total'], 2)) {
          return _bad('Invalid decimal precision');
        }
        if (((qty * cost) - total).abs() > 0.011) {
          return _bad('Line total does not match quantity × unit cost');
        }
        items.add({
          'productId': productId,
          'productName': name,
          'quantity': qty,
          'costPrice': cost,
          'total': total,
        });
      }

      final conn = await DbConfig().connection;
      // The mobile API may be deployed before the Desktop app has had a
      // chance to run its schema upgrader.  Ensure the draft-only fields are
      // available here as well, before performing any receipt transaction.
      await _ensureDraftSchema(conn);
      final hashResult = await conn.execute(
        'SELECT SHA2(:payload, 256) AS payloadHash',
        {
          'payload': jsonEncode({'supplierId': supplierId, 'items': items}),
        },
      );
      final payloadHash = hashResult.rows.first
          .assoc()['payloadHash']
          .toString();
      final prior = await conn.execute(
        'SELECT id, idempotencyPayloadHash FROM purchase_order WHERE idempotencyKey = :key LIMIT 1',
        {'key': key},
      );
      if (prior.rows.isNotEmpty) {
        if (prior.rows.first.assoc()['idempotencyPayloadHash'] != payloadHash) {
          return _idempotencyConflict();
        }
        return _ok(prior.rows.first.assoc()['id'], true);
      }

      await conn.execute('START TRANSACTION');
      try {
        final supplier = await conn.execute(
          'SELECT id FROM supplier WHERE id = :id LIMIT 1',
          {'id': supplierId},
        );
        if (supplier.rows.isEmpty) throw StateError('Supplier not found');
        for (final item in items.where(
          (item) => (item['productId'] as int) > 0,
        )) {
          final product = await conn.execute(
            'SELECT id FROM product WHERE id = :id LIMIT 1',
            {'id': item['productId']},
          );
          if (product.rows.isEmpty) {
            throw StateError('Product not found');
          }
        }
        final grandTotal = items.fold<double>(
          0,
          (sum, item) => sum + double.parse(item['total'].toString()),
        );
        final userId = int.tryParse(
          user is Map ? user['id']?.toString() ?? '' : '',
        );
        final created = await conn.execute(
          '''
          INSERT INTO purchase_order (supplierId, totalAmount, status, userId, note, vatType, isPaid, idempotencyKey, idempotencyPayloadHash, createdAt)
          VALUES (:supplierId, :total, 'DRAFT', :userId, :note, 2, 0, :key, :payloadHash, NOW())
        ''',
          {
            'supplierId': supplierId,
            'total': grandTotal,
            'userId': userId,
            'note': 'สร้างจาก S-Link (รอตรวจสอบ)',
            'key': key,
            'payloadHash': payloadHash,
          },
        );
        final poId = created.lastInsertID.toInt();
        for (final item in items) {
          await conn.execute(
            '''
            INSERT INTO purchase_order_item (poId, productId, productName, quantity, receivedQuantity, costPrice, total)
            VALUES (:poId, :productId, :name, :qty, 0, :cost, :total)
          ''',
            {
              'poId': poId,
              'productId': item['productId'],
              'name': item['productName'],
              'qty': item['quantity'],
              'cost': item['costPrice'],
              'total': item['total'],
            },
          );
        }
        await conn.execute('COMMIT');
        return _ok(poId, false);
      } catch (e) {
        await conn.execute('ROLLBACK');
        // A concurrent retry can win the unique key race; return its PO.
        final duplicate = await conn.execute(
          'SELECT id, idempotencyPayloadHash FROM purchase_order WHERE idempotencyKey = :key LIMIT 1',
          {'key': key},
        );
        if (duplicate.rows.isNotEmpty) {
          if (duplicate.rows.first.assoc()['idempotencyPayloadHash'] !=
              payloadHash) {
            return _idempotencyConflict();
          }
          return _ok(duplicate.rows.first.assoc()['id'], true);
        }
        rethrow;
      }
    } on FormatException catch (e) {
      return _bad(e.message);
    } on StateError catch (e) {
      return _bad(e.message);
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Could not create purchase-order draft'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Response _bad(String message) => Response.badRequest(
    body: jsonEncode({'error': message}),
    headers: {'content-type': 'application/json'},
  );
  Response _idempotencyConflict() => Response(
    409,
    body: jsonEncode({
      'error': 'receiptId was already used with different data',
    }),
    headers: {'content-type': 'application/json'},
  );
  Response _ok(dynamic id, bool duplicate) => Response.ok(
    jsonEncode({
      'success': true,
      'purchaseOrderId': int.parse(id.toString()),
      'duplicate': duplicate,
      'status': 'DRAFT',
    }),
    headers: {'content-type': 'application/json'},
  );
  bool _decimal(dynamic value, int places) => RegExp(
    r'^\d+(?:\.\d{1,' + places.toString() + r'})?$',
  ).hasMatch(value?.toString() ?? '');

  Future<void> _ensureDraftSchema(dynamic conn) async {
    await _ensureColumn(
      conn,
      'purchase_order',
      'idempotencyKey',
      'VARCHAR(64) NULL',
    );
    await _ensureColumn(
      conn,
      'purchase_order',
      'idempotencyPayloadHash',
      'CHAR(64) NULL',
    );
    await _ensureIndex(
      conn,
      'purchase_order',
      'idx_purchase_order_idempotency',
      'idempotencyKey',
    );
  }

  Future<void> _ensureColumn(
    dynamic conn,
    String table,
    String column,
    String definition,
  ) async {
    final result = await conn.execute('SHOW COLUMNS FROM $table LIKE :column', {
      'column': column,
    });
    if (result.rows.isEmpty) {
      await conn.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _ensureIndex(
    dynamic conn,
    String table,
    String index,
    String column,
  ) async {
    final result = await conn.execute(
      'SHOW INDEX FROM $table WHERE Key_name = :index',
      {'index': index},
    );
    if (result.rows.isEmpty) {
      await conn.execute('ALTER TABLE $table ADD UNIQUE KEY $index ($column)');
    }
  }
}
