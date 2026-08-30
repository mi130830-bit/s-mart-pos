// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db_config.dart';
import '../services/loyalty_award_service.dart';

/// Server-authoritative checkout for S-Link.  It intentionally accepts only
/// product IDs and quantities; price, discounts, VAT and loyalty balances are
/// read and calculated on the POS server inside one MySQL transaction.
class MobileCheckoutController {
  final LoyaltyAwardService _loyaltyAwardService = LoyaltyAwardService();

  Router get router {
    final router = Router();
    router.post('/', _checkout);
    router.post('/quote', _quote);
    return router;
  }

  /// Read-only UX hint. Checkout always repeats all validation under locks.
  Future<Response> _quote(Request request) async {
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid request body');
      }
      final customerId = _positiveIntOrNull(decoded['customerId']);
      final requestedPoints = _nonNegativeInt(
        decoded['pointsUsed'] ?? 0,
        'pointsUsed',
      );
      final couponCode = decoded['couponCode']?.toString().trim().toUpperCase();
      if (requestedPoints > 0 && couponCode != null && couponCode.isNotEmpty) {
        throw const FormatException(
          'Points and a coupon cannot be used together',
        );
      }
      final conn = await DbConfig().connection;
      final settings = await _settings(conn);
      final calculated = await _calculateLines(
        conn,
        _parseItems(decoded['items']),
        settings['allowNegativeStock'] == 'true',
      );
      final subtotal = calculated['subtotal'] as double;
      final enabled = settings['pointEnabled'] == 'true';
      final rate = double.tryParse(settings['pointRedemptionRate'] ?? '') ?? 0;
      final available = customerId == null
          ? 0
          : await _availablePoints(conn, customerId);
      final cap = enabled && rate > 0 ? (subtotal * .75 * rate).floor() : 0;
      final maxRedeemable = available < cap ? available : cap;
      final pointsUsed = requestedPoints > maxRedeemable
          ? maxRedeemable
          : requestedPoints;
      final coupon = couponCode == null || couponCode.isEmpty
          ? null
          : await _lockCoupon(conn, couponCode, customerId);
      final couponDiscount = coupon == null
          ? 0.0
          : coupon['discount'] as double;
      if (couponDiscount > subtotal) {
        throw StateError('Coupon value exceeds the eligible sale amount');
      }
      final pointDiscount = pointsUsed == 0 || rate <= 0
          ? 0.0
          : pointsUsed / rate;
      final vatMode = settings['vatMode'] ?? 'included';
      final vatRate = double.tryParse(settings['vatRate'] ?? '') ?? 7.0;
      final totals = _vat(
        subtotal - couponDiscount - pointDiscount,
        vatMode,
        vatRate,
      );
      return Response.ok(
        jsonEncode({
          'success': true,
          'pointsEnabled': enabled,
          'pointRedemptionRate': rate,
          'availablePoints': available,
          'maxRedeemable': maxRedeemable,
          'pointsUsed': pointsUsed,
          'subtotal': subtotal,
          'discount': couponDiscount + pointDiscount,
          'vat': totals['vat'],
          'grandTotal': totals['grandTotal'],
          'vatMode': vatMode,
        }),
        headers: {'content-type': 'application/json'},
      );
    } on FormatException catch (e) {
      return _bad(e.message);
    } on StateError catch (e) {
      return _bad(e.message);
    } catch (_) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Mobile checkout quote failed'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _checkout(Request request) async {
    final user = request.context['user'];
    final role = user is Map ? user['role']?.toString().toUpperCase() : '';
    if (role != 'ADMIN' && role != 'CASHIER') {
      return _forbidden('Only ADMIN or CASHIER may complete a mobile sale');
    }

    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map<String, dynamic>)
        throw const FormatException('Invalid request body');
      final requestId = decoded['clientRequestId']?.toString().trim() ?? '';
      if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(requestId)) {
        throw const FormatException('clientRequestId must be a UUID');
      }
      final paymentMethod =
          decoded['paymentMethod']?.toString().toUpperCase() ?? '';
      if (paymentMethod != 'CASH' && paymentMethod != 'PROMPTPAY') {
        throw const FormatException(
          'Only CASH and PROMPTPAY are supported by authoritative mobile checkout',
        );
      }
      final customerId = _positiveIntOrNull(decoded['customerId']);
      final receivedAmount = double.tryParse(
        decoded['receivedAmount']?.toString() ?? '',
      );
      if (receivedAmount == null ||
          !receivedAmount.isFinite ||
          receivedAmount < 0) {
        throw const FormatException(
          'receivedAmount must be a non-negative number',
        );
      }
      final pointsUsed = _nonNegativeInt(
        decoded['pointsUsed'] ?? 0,
        'pointsUsed',
      );
      final couponCode = decoded['couponCode']?.toString().trim().toUpperCase();
      if (pointsUsed > 0 && couponCode != null && couponCode.isNotEmpty) {
        throw const FormatException(
          'Points and a coupon cannot be used together',
        );
      }
      if (pointsUsed > 0 && customerId == null) {
        throw const FormatException('A customer is required to redeem points');
      }
      final items = _parseItems(decoded['items']);
      if (decoded.containsKey('discount') ||
          decoded.containsKey('grandTotal') ||
          decoded.containsKey('total')) {
        throw const FormatException(
          'Client supplied totals/discounts are not accepted',
        );
      }

      final conn = await DbConfig().connection;
      await _ensureSchema(conn);
      final canonical = jsonEncode({
        'customerId': customerId,
        'paymentMethod': paymentMethod,
        'receivedAmount': receivedAmount,
        'pointsUsed': pointsUsed,
        'couponCode': couponCode ?? '',
        'items': items,
      });
      final hash = await _hash(conn, canonical);
      final prior = await conn.execute(
        '''
        SELECT id, total, discount, grandTotal
        FROM `order` WHERE mobileIdempotencyKey = :key LIMIT 1
      ''',
        {'key': requestId},
      );
      if (prior.rows.isNotEmpty) {
        return _existing(prior.rows.first.assoc(), requestId, hash, conn);
      }

      await conn.execute('START TRANSACTION');
      try {
        final settings = await _settings(conn);
        final calculated = await _calculateLines(
          conn,
          items,
          settings['allowNegativeStock'] == 'true',
        );
        final subtotal = calculated['subtotal'] as double;
        final coupon = couponCode == null || couponCode.isEmpty
            ? null
            : await _lockCoupon(conn, couponCode, customerId);
        final couponDiscount = coupon == null
            ? 0.0
            : coupon['discount'] as double;
        if (couponDiscount > subtotal)
          throw StateError('Coupon value exceeds the eligible sale amount');

        final pointRate =
            double.tryParse(settings['pointRedemptionRate'] ?? '') ?? 0;
        if (pointsUsed > 0) {
          if (settings['pointEnabled'] != 'true' || pointRate <= 0) {
            throw StateError('Point redemption is disabled');
          }
          final cap = (subtotal * .75 * pointRate).floor();
          if (pointsUsed > cap)
            throw StateError('Points exceed the 75% redemption cap');
          await _redeemPoints(conn, customerId!, pointsUsed);
        }

        final pointDiscount = pointsUsed == 0 ? 0.0 : pointsUsed / pointRate;
        final taxableBase = subtotal - couponDiscount - pointDiscount;
        final vatMode = settings['vatMode'] ?? 'included';
        final vatRate = double.tryParse(settings['vatRate'] ?? '') ?? 7.0;
        final totals = _vat(taxableBase, vatMode, vatRate);
        if (receivedAmount + .00001 < totals['grandTotal']!) {
          throw StateError(
            'Received amount is less than the server-calculated total',
          );
        }
        final change = _round2(receivedAmount - totals['grandTotal']!);
        final userId = _positiveIntOrNull(user is Map ? user['id'] : null);
        final created = await conn.execute(
          '''
          INSERT INTO `order` (customerId, total, discount, grandTotal, paymentMethod,
            received, changeAmount, userId, branchId, status, createdAt,
            mobileIdempotencyKey, mobilePayloadHash)
          VALUES (:customerId, :total, :discount, :grand, :method, :received,
            :change, :userId, 1, 'COMPLETED', NOW(), :key, :hash)
        ''',
          {
            'customerId': customerId,
            'total': subtotal,
            'discount': couponDiscount + pointDiscount,
            'grand': totals['grandTotal'],
            'method': paymentMethod,
            'received': receivedAmount,
            'change': change,
            'userId': userId,
            'key': requestId,
            'hash': hash,
          },
        );
        final orderId = created.lastInsertID.toInt();
        if (coupon != null)
          await _consumeCoupon(
            conn,
            couponCode!,
            customerId!,
            orderId,
            couponDiscount,
          );
        await _writeLinesAndStock(
          conn,
          orderId,
          calculated['lines'] as List<Map<String, dynamic>>,
        );
        await conn.execute(
          '''
          INSERT INTO order_payment (orderId, paymentMethod, amount, createdAt)
          VALUES (:orderId, :method, :amount, NOW())
        ''',
          {
            'orderId': orderId,
            'method': paymentMethod,
            'amount': totals['grandTotal'],
          },
        );
        await _loyaltyAwardService.awardClosedOrderWithinTransaction(
          conn,
          orderId: orderId,
          source: 'MOBILE_CHECKOUT',
        );
        await conn.execute('COMMIT');
        return Response.ok(
          jsonEncode({
            'success': true,
            'duplicate': false,
            'orderId': orderId,
            'subtotal': subtotal,
            'discount': couponDiscount + pointDiscount,
            'vat': totals['vat'],
            'grandTotal': totals['grandTotal'],
            'received': receivedAmount,
            'change': change,
            'vatMode': vatMode,
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (_) {
        await conn.execute('ROLLBACK');
        // A retry can race after the first pre-transaction lookup. The unique
        // idempotency key is the final arbiter; return the committed result
        // when the same request won on another connection.
        final duplicate = await conn.execute(
          '''
          SELECT id, total, discount, grandTotal, mobilePayloadHash
          FROM `order` WHERE mobileIdempotencyKey = :key LIMIT 1
        ''',
          {'key': requestId},
        );
        if (duplicate.rows.isNotEmpty) {
          final row = duplicate.rows.first.assoc();
          if (row['mobilePayloadHash'] == hash) {
            return _existing(row, requestId, hash, conn);
          }
          return Response(
            409,
            body: jsonEncode({
              'error': 'clientRequestId was already used with different data',
            }),
            headers: {'content-type': 'application/json'},
          );
        }
        rethrow;
      }
    } on FormatException catch (e) {
      return _bad(e.message);
    } on StateError catch (e) {
      return _bad(e.message);
    } catch (_) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Authoritative mobile checkout failed'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  List<Map<String, dynamic>> _parseItems(dynamic raw) {
    if (raw is! List || raw.isEmpty || raw.length > 100)
      throw const FormatException('items must contain 1-100 lines');
    final merged = <int, double>{};
    for (final entry in raw) {
      if (entry is! Map) throw const FormatException('Invalid item');
      final id = _positiveIntOrNull(entry['productId']);
      final qty = double.tryParse(entry['quantity']?.toString() ?? '');
      if (id == null ||
          qty == null ||
          !qty.isFinite ||
          qty <= 0 ||
          qty > 999999) {
        throw const FormatException(
          'Each item needs a valid productId and positive quantity',
        );
      }
      merged[id] = (merged[id] ?? 0) + qty;
    }
    return merged.entries
        .map((e) => {'productId': e.key, 'quantity': e.value})
        .toList();
  }

  Future<Map<String, dynamic>> _calculateLines(
    dynamic conn,
    List<Map<String, dynamic>> items,
    bool allowNegative,
  ) async {
    final lines = <Map<String, dynamic>>[];
    var subtotal = 0.0;
    for (final item in items) {
      final res = await conn.execute(
        '''
        SELECT id, name, retailPrice, stockQuantity, trackStock
        FROM product WHERE id = :id FOR UPDATE
      ''',
        {'id': item['productId']},
      );
      if (res.rows.isEmpty)
        throw StateError('Product #${item['productId']} was not found');
      final p = res.rows.first.assoc();
      final price =
          double.tryParse(p['retailPrice']?.toString() ?? '') ?? double.nan;
      final stock = double.tryParse(p['stockQuantity']?.toString() ?? '') ?? 0;
      final track = p['trackStock']?.toString() != '0';
      final qty = item['quantity'] as double;
      if (!price.isFinite || price < 0)
        throw StateError(
          'Product #${item['productId']} has no valid retail price',
        );
      if (track && !allowNegative && stock < qty)
        throw StateError('Insufficient stock for ${p['name']}');
      final lineTotal = _round2(price * qty);
      subtotal += lineTotal;
      lines.add({
        'id': item['productId'],
        'name': p['name']?.toString() ?? '',
        'price': price,
        'qty': qty,
        'total': lineTotal,
        'track': track,
      });
    }
    return {'subtotal': _round2(subtotal), 'lines': lines};
  }

  Future<Map<String, dynamic>> _lockCoupon(
    dynamic conn,
    String code,
    int? customerId,
  ) async {
    if (customerId == null)
      throw StateError('A customer is required to use a coupon');
    final res = await conn.execute(
      '''
      SELECT discount_value FROM reward_coupon
      WHERE coupon_code = :code AND customer_id = :customerId
        AND status = 'ACTIVE' AND expires_at > NOW() FOR UPDATE
    ''',
      {'code': code, 'customerId': customerId},
    );
    if (res.rows.isEmpty)
      throw StateError(
        'Coupon is invalid, expired, already used, or belongs to another customer',
      );
    final discount =
        double.tryParse(
          res.rows.first.assoc()['discount_value']?.toString() ?? '',
        ) ??
        0;
    if (!discount.isFinite || discount <= 0)
      throw StateError('Coupon discount is invalid');
    return {'discount': discount};
  }

  Future<void> _consumeCoupon(
    dynamic conn,
    String code,
    int customerId,
    int orderId,
    double discount,
  ) async {
    final updated = await conn.execute(
      '''
      UPDATE reward_coupon SET status = 'USED', used_at = NOW(), order_id = :orderId
      WHERE coupon_code = :code AND customer_id = :customerId AND status = 'ACTIVE'
        AND expires_at > NOW() AND discount_value = :discount
    ''',
      {
        'orderId': orderId,
        'code': code,
        'customerId': customerId,
        'discount': discount,
      },
    );
    if (updated.affectedRows != BigInt.one)
      throw StateError('Coupon could not be consumed');
    await conn.execute(
      '''UPDATE reward_redemption rr JOIN reward_coupon rc ON rc.redemption_id = rr.id
      SET rr.status = 'FULFILLED' WHERE rc.coupon_code = :code''',
      {'code': code},
    );
  }

  Future<void> _redeemPoints(dynamic conn, int customerId, int amount) async {
    final customer = await conn.execute(
      'SELECT id, currentPoints FROM customer WHERE id = :id FOR UPDATE',
      {'id': customerId},
    );
    if (customer.rows.isEmpty) throw StateError('Customer not found');
    final current =
        int.tryParse(
          customer.rows.first.assoc()['currentPoints']?.toString() ?? '',
        ) ??
        0;
    if (current < amount) throw StateError('Insufficient available points');
    final rows = await conn.execute(
      '''SELECT id, points_earned - points_used AS available FROM point_ledger
      WHERE customer_id = :id AND points_earned > points_used AND (expires_at IS NULL OR expires_at > NOW())
      ORDER BY (expires_at IS NULL), expires_at, earned_at, id FOR UPDATE''',
      {'id': customerId},
    );
    var remaining = amount;
    for (final row in rows.rows) {
      final data = row.assoc();
      final available = int.tryParse(data['available']?.toString() ?? '') ?? 0;
      final used = available < remaining ? available : remaining;
      if (used > 0)
        await conn.execute(
          'UPDATE point_ledger SET points_used = points_used + :used WHERE id = :id',
          {'used': used, 'id': data['id']},
        );
      remaining -= used;
      if (remaining == 0) break;
    }
    if (remaining != 0) throw StateError('Insufficient available points');
    await _refreshPoints(conn, customerId);
  }

  Future<int> _availablePoints(dynamic conn, int customerId) async {
    final res = await conn.execute(
      '''
      SELECT COALESCE(SUM(points_earned - points_used), 0) AS total
      FROM point_ledger WHERE customer_id = :id
        AND (expires_at IS NULL OR expires_at > NOW())
    ''',
      {'id': customerId},
    );
    return int.tryParse(res.rows.first.assoc()['total']?.toString() ?? '') ?? 0;
  }

  Future<void> _writeLinesAndStock(
    dynamic conn,
    int orderId,
    List<Map<String, dynamic>> lines,
  ) async {
    for (final line in lines) {
      await conn.execute(
        '''INSERT INTO orderitem (orderId, productId, productName, quantity, price, discount, total, conversionFactor)
        VALUES (:orderId, :productId, :name, :qty, :price, 0, :total, 1)''',
        {
          'orderId': orderId,
          'productId': line['id'],
          'name': line['name'],
          'qty': line['qty'],
          'price': line['price'],
          'total': line['total'],
        },
      );
      if (line['track'] == true) {
        await conn.execute(
          'UPDATE product SET stockQuantity = stockQuantity - :qty WHERE id = :id',
          {'qty': line['qty'], 'id': line['id']},
        );
        await conn.execute(
          '''INSERT INTO stockledger (productId, transactionType, quantityChange, note, createdAt)
          VALUES (:id, 'SALE', :change, :note, NOW())''',
          {
            'id': line['id'],
            'change': -(line['qty'] as double),
            'note': 'S-Link sale #$orderId',
          },
        );
      }
    }
  }

  Future<Map<String, String>> _settings(dynamic conn) async {
    final keys = [
      'point_enabled',
      'point_redemption_rate',
      'vat_rate',
      'allow_negative_stock',
      'slink_checkout_vat_mode',
    ];
    final params = <String, String>{};
    final placeholders = <String>[];
    for (var i = 0; i < keys.length; i++) {
      final key = 'key$i';
      placeholders.add(':$key');
      params[key] = keys[i];
    }
    final rows = await conn.execute(
      'SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN (${placeholders.join(',')})',
      params,
    );
    final values = <String, String>{
      'pointEnabled': 'false',
      'pointRedemptionRate': '0',
      'vatRate': '7',
      'allowNegativeStock': 'true',
      'vatMode': 'included',
    };
    for (final row in rows.rows) {
      final data = row.assoc();
      switch (data['setting_key']) {
        case 'point_enabled':
          values['pointEnabled'] =
              data['setting_value']?.toString().toLowerCase() ?? 'false';
        case 'point_redemption_rate':
          values['pointRedemptionRate'] =
              data['setting_value']?.toString() ?? '0';
        case 'vat_rate':
          values['vatRate'] = data['setting_value']?.toString() ?? '7';
        case 'allow_negative_stock':
          values['allowNegativeStock'] =
              data['setting_value']?.toString().toLowerCase() ?? 'true';
        case 'slink_checkout_vat_mode':
          values['vatMode'] =
              data['setting_value']?.toString().toLowerCase() ?? 'none';
      }
    }
    if (!['none', 'excluded', 'included'].contains(values['vatMode']))
      throw StateError('Invalid server VAT mode');
    return values;
  }

  Map<String, double> _vat(double base, String mode, double rate) {
    if (base < 0 || !base.isFinite || rate < 0 || !rate.isFinite)
      throw StateError('Invalid calculated total');
    base = _round2(base);
    if (mode == 'excluded') {
      final vat = _round2(base * rate / 100);
      return {'vat': vat, 'grandTotal': _round2(base + vat)};
    }
    if (mode == 'included')
      return {'vat': _round2(base * rate / (100 + rate)), 'grandTotal': base};
    return {'vat': 0, 'grandTotal': base};
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;

  Future<void> _refreshPoints(dynamic conn, int customerId) async {
    final total = await conn.execute(
      '''SELECT COALESCE(SUM(points_earned - points_used), 0) AS total FROM point_ledger
      WHERE customer_id = :id AND (expires_at IS NULL OR expires_at > NOW())''',
      {'id': customerId},
    );
    await conn.execute(
      'UPDATE customer SET currentPoints = :points WHERE id = :id',
      {'points': total.rows.first.assoc()['total'], 'id': customerId},
    );
  }

  Future<String> _hash(dynamic conn, String canonical) async {
    final result = await conn.execute('SELECT SHA2(:payload, 256) AS hash', {
      'payload': canonical,
    });
    return result.rows.first.assoc()['hash'].toString();
  }

  Future<Response> _existing(
    Map<String, String?> row,
    String key,
    String hash,
    dynamic conn,
  ) async {
    final check = await conn.execute(
      'SELECT mobilePayloadHash FROM `order` WHERE mobileIdempotencyKey = :key',
      {'key': key},
    );
    if (check.rows.first.assoc()['mobilePayloadHash'] != hash)
      return Response(
        409,
        body: jsonEncode({
          'error': 'clientRequestId was already used with different data',
        }),
        headers: {'content-type': 'application/json'},
      );
    return Response.ok(
      jsonEncode({
        'success': true,
        'duplicate': true,
        'orderId': int.parse(row['id']!),
        'subtotal': double.parse(row['total']!),
        'discount': double.parse(row['discount']!),
        'grandTotal': double.parse(row['grandTotal']!),
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<void> _ensureSchema(dynamic conn) async {
    await _ensureColumn(
      conn,
      'order',
      'mobileIdempotencyKey',
      'VARCHAR(64) NULL',
    );
    await _ensureColumn(conn, 'order', 'mobilePayloadHash', 'CHAR(64) NULL');
    final index = await conn.execute(
      "SHOW INDEX FROM `order` WHERE Key_name = 'idx_order_mobile_idempotency'",
    );
    if (index.rows.isEmpty)
      await conn.execute(
        'ALTER TABLE `order` ADD UNIQUE KEY idx_order_mobile_idempotency (mobileIdempotencyKey)',
      );
  }

  Future<void> _ensureColumn(
    dynamic conn,
    String table,
    String column,
    String definition,
  ) async {
    final result = await conn.execute(
      'SHOW COLUMNS FROM `$table` LIKE :column',
      {'column': column},
    );
    if (result.rows.isEmpty)
      await conn.execute(
        'ALTER TABLE `$table` ADD COLUMN `$column` $definition',
      );
  }

  int _nonNegativeInt(dynamic value, String name) {
    final parsed = int.tryParse(value.toString());
    if (parsed == null || parsed < 0)
      throw FormatException('$name must be a non-negative integer');
    return parsed;
  }

  int? _positiveIntOrNull(dynamic value) {
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  Response _bad(String message) => Response.badRequest(
    body: jsonEncode({'error': message}),
    headers: {'content-type': 'application/json'},
  );
  Response _forbidden(String message) => Response.forbidden(
    jsonEncode({'error': message}),
    headers: {'content-type': 'application/json'},
  );
}
