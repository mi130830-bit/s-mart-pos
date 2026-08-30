import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:mysql_client_plus/exception.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../db_config.dart';
import 'line_identity_service.dart';
import 'member_tier_service.dart';

class OnlineOrderException implements Exception {
  const OnlineOrderException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;
}

class OnlineOrderItemInput {
  const OnlineOrderItemInput({required this.productId, required this.quantity});

  final int productId;
  final double quantity;

  Map<String, dynamic> toCanonicalJson() => {
    'productId': productId,
    'quantity': quantity,
  };
}

class OnlineOrderInput {
  const OnlineOrderInput({
    required this.clientRequestId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryType,
    required this.deliveryAddress,
    required this.gpsLocation,
    required this.notes,
    required this.couponCode,
    required this.items,
  });

  final String clientRequestId;
  final String customerName;
  final String customerPhone;
  final String deliveryType;
  final String deliveryAddress;
  final String gpsLocation;
  final String notes;
  final String? couponCode;
  final List<OnlineOrderItemInput> items;

  String payloadHash({String? lineSubject}) {
    final canonical = jsonEncode({
      'lineSubject': lineSubject ?? '',
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryType': deliveryType,
      'deliveryAddress': deliveryAddress,
      'gpsLocation': gpsLocation,
      'notes': notes,
      'couponCode': couponCode ?? '',
      'items': items.map((item) => item.toCanonicalJson()).toList(),
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}

class DeliveryEstimate {
  const DeliveryEstimate({required this.distanceKm, required this.fee});

  final double distanceKm;
  final double fee;
}

class OnlineOrderResult {
  const OnlineOrderResult({
    required this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.deliveryFee,
    required this.grandTotal,
    required this.distanceKm,
    required this.couponDiscount,
    required this.couponCode,
    required this.couponReservedUntil,
    required this.items,
    required this.deliveryType,
    required this.deliveryAddress,
    required this.gpsLocation,
    required this.notes,
    required this.isReplay,
  });

  final int id;
  final String orderNumber;
  final double totalAmount;
  final double deliveryFee;
  final double grandTotal;
  final double distanceKm;
  final double couponDiscount;
  final String? couponCode;
  final String? couponReservedUntil;
  final List<Map<String, dynamic>> items;
  final String deliveryType;
  final String deliveryAddress;
  final String gpsLocation;
  final String notes;
  final bool isReplay;
}

class OnlineOrderRules {
  static const shopLatitude = 16.160189;
  static const shopLongitude = 100.802307;
  static const allowedStatuses = {
    'PENDING',
    'CONFIRMED',
    'PREPARING',
    'READY',
    'DISPATCHED',
    'SHIPPING',
    'PAID',
    'COMPLETED',
    'CANCELLED',
    'REJECTED',
  };

  static OnlineOrderInput parseInput(Map<String, dynamic> body) {
    final requestId = validateClientRequestId(
      _requiredText(body['clientRequestId'], 36, 'clientRequestId'),
    );
    final name = _requiredText(body['customerName'], 255, 'customerName');
    final phone = _requiredText(body['customerPhone'], 50, 'customerPhone');
    if (!RegExp(r'^[0-9+().\-\s]{5,50}$').hasMatch(phone)) {
      throw const OnlineOrderException(
        400,
        'INVALID_CONTACT',
        'Invalid customer contact',
      );
    }
    final deliveryType = _requiredText(
      body['deliveryType'],
      20,
      'deliveryType',
    ).toLowerCase();
    if (deliveryType != 'pickup' && deliveryType != 'delivery') {
      throw const OnlineOrderException(
        400,
        'INVALID_DELIVERY',
        'Invalid delivery type',
      );
    }
    final rawAddress = _optionalText(body['deliveryAddress'], 2000);
    if (deliveryType == 'delivery' && rawAddress.isEmpty) {
      throw const OnlineOrderException(
        400,
        'INVALID_DELIVERY',
        'Delivery address is required',
      );
    }
    final gps = _optionalText(body['gpsLocation'], 255);
    final notes = _optionalText(body['notes'], 2000);
    final rawCoupon = _optionalText(body['couponCode'], 20).toUpperCase();
    if (rawCoupon.isNotEmpty &&
        !RegExp(r'^[A-Z0-9-]{4,20}$').hasMatch(rawCoupon)) {
      throw const OnlineOrderException(
        400,
        'INVALID_COUPON',
        'Invalid coupon code',
      );
    }
    final items = canonicalItems(body['items']);
    return OnlineOrderInput(
      clientRequestId: requestId,
      customerName: name,
      customerPhone: phone,
      deliveryType: deliveryType,
      deliveryAddress: deliveryType == 'pickup' ? 'รับเองที่ร้าน' : rawAddress,
      gpsLocation: deliveryType == 'pickup' ? '' : gps,
      notes: notes,
      couponCode: rawCoupon.isEmpty ? null : rawCoupon,
      items: items,
    );
  }

  static String validateClientRequestId(String input) {
    final value = input.trim().toLowerCase();
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value)) {
      throw const OnlineOrderException(
        400,
        'INVALID_CLIENT_REQUEST_ID',
        'A valid clientRequestId UUID is required',
      );
    }
    return value;
  }

  static bool isDuplicateKeyError(Object error) =>
      error is MySQLServerException && error.errorCode == 1062;

  static bool isIdempotentReplay(String? storedHash, String requestedHash) =>
      storedHash != null && storedHash == requestedHash;

  static List<OnlineOrderItemInput> canonicalItems(dynamic raw) {
    if (raw is! List || raw.isEmpty || raw.length > 100) {
      throw const OnlineOrderException(
        400,
        'INVALID_ITEMS',
        'Invalid order items',
      );
    }
    final quantities = <int, double>{};
    for (final value in raw) {
      if (value is! Map) {
        throw const OnlineOrderException(
          400,
          'INVALID_ITEMS',
          'Invalid order items',
        );
      }
      final productId = int.tryParse(value['productId']?.toString() ?? '');
      final quantity = double.tryParse(value['quantity']?.toString() ?? '');
      if (productId == null ||
          productId <= 0 ||
          quantity == null ||
          !quantity.isFinite ||
          quantity <= 0 ||
          quantity > 100000) {
        throw const OnlineOrderException(
          400,
          'INVALID_ITEMS',
          'Invalid order items',
        );
      }
      final combined = (quantities[productId] ?? 0) + quantity;
      if (!combined.isFinite || combined > 100000) {
        throw const OnlineOrderException(
          400,
          'INVALID_ITEMS',
          'Invalid order items',
        );
      }
      quantities[productId] = combined;
    }
    final ids = quantities.keys.toList()..sort();
    return ids
        .map(
          (id) =>
              OnlineOrderItemInput(productId: id, quantity: quantities[id]!),
        )
        .toList();
  }

  static DeliveryEstimate deliveryEstimate({
    required String deliveryType,
    required String gpsLocation,
    required double grossProfit,
  }) {
    if (deliveryType == 'pickup') {
      return const DeliveryEstimate(distanceKm: 0, fee: 0);
    }
    final coordinates = _coordinates(gpsLocation);
    if (coordinates == null) {
      return const DeliveryEstimate(distanceKm: 0, fee: 0);
    }
    final distance = _round3(
      _haversineKm(
            shopLatitude,
            shopLongitude,
            coordinates.$1,
            coordinates.$2,
          ) *
          1.35,
    );
    double fee;
    if (distance <= 5.0) {
      fee = 50;
    } else if (distance <= 10.0) {
      fee = 100;
    } else if (distance <= 15.0) {
      fee = 150;
    } else if (distance <= 20.0) {
      fee = 200;
    } else if (distance <= 30.0) {
      fee = 300;
    } else {
      fee = (300 + ((distance - 30) * 12).round()).toDouble();
    }
    return DeliveryEstimate(distanceKm: distance, fee: fee);
  }

  static bool canTransition(String current, String target) {
    if (!allowedStatuses.contains(current) ||
        !allowedStatuses.contains(target)) {
      return false;
    }
    if (current == target) return true;
    const transitions = <String, Set<String>>{
      'PENDING': {'CONFIRMED', 'COMPLETED', 'CANCELLED', 'REJECTED'},
      'CONFIRMED': {
        'PREPARING',
        'DISPATCHED',
        'COMPLETED',
        'CANCELLED',
        'REJECTED',
      },
      'PREPARING': {'READY', 'DISPATCHED', 'COMPLETED', 'CANCELLED'},
      'READY': {'DISPATCHED', 'COMPLETED', 'CANCELLED'},
      'DISPATCHED': {'SHIPPING', 'COMPLETED', 'CANCELLED'},
      'SHIPPING': {'COMPLETED', 'CANCELLED'},
      'PAID': {'COMPLETED', 'CANCELLED'},
    };
    return transitions[current]?.contains(target) ?? false;
  }

  static bool couponReservable({
    required String status,
    required int couponCustomerId,
    required int customerId,
    required DateTime expiresAt,
    required DateTime now,
  }) =>
      status == 'ACTIVE' &&
      couponCustomerId == customerId &&
      expiresAt.isAfter(now);

  static String _requiredText(dynamic value, int maxLength, String field) {
    if (value is! String) {
      throw OnlineOrderException(400, 'INVALID_$field', 'Invalid order data');
    }
    final text = value.trim();
    if (text.isEmpty || text.length > maxLength) {
      throw OnlineOrderException(400, 'INVALID_$field', 'Invalid order data');
    }
    return text;
  }

  static String _optionalText(dynamic value, int maxLength) {
    if (value == null) return '';
    if (value is! String) {
      throw const OnlineOrderException(
        400,
        'INVALID_ORDER_DATA',
        'Invalid order data',
      );
    }
    final text = value.trim();
    if (text.length > maxLength) {
      throw const OnlineOrderException(
        400,
        'INVALID_ORDER_DATA',
        'Invalid order data',
      );
    }
    return text;
  }

  static (double, double)? _coordinates(String input) {
    final match = RegExp(
      r'(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(input);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    return (lat, lng);
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const radius = 6371.0;
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _round3(double value) => (value * 1000).round() / 1000;
}

class OnlineOrderService {
  final MemberTierService _memberTierService = MemberTierService();

  Future<OnlineOrderResult> create({
    required OnlineOrderInput input,
    required LineIdentity? identity,
  }) async {
    final hash = input.payloadHash(lineSubject: identity?.subject);
    final conn = await DbConfig().connection;
    await conn.execute('START TRANSACTION');
    try {
      final prior = await _findByClientRequestId(
        conn,
        input.clientRequestId,
        forUpdate: true,
      );
      if (prior != null) {
        if (!OnlineOrderRules.isIdempotentReplay(prior['payloadHash'], hash)) {
          throw const OnlineOrderException(
            409,
            'IDEMPOTENCY_CONFLICT',
            'clientRequestId was already used for different order data',
          );
        }
        final existingResult = _resultFromRow(prior, isReplay: true);
        await conn.execute('COMMIT');
        return existingResult;
      }

      var customerId = identity == null
          ? null
          : await _memberTierService.resolveCustomerId(conn, identity.subject);
      if (customerId != null) {
        final activeCustomer = await conn.execute(
          '''SELECT id FROM customer WHERE id = :id
             AND (isDeleted = 0 OR isDeleted IS NULL) LIMIT 1 FOR UPDATE''',
          {'id': customerId},
        );
        if (activeCustomer.rows.isEmpty) customerId = null;
      }
      if (input.couponCode != null &&
          (identity == null || customerId == null)) {
        throw const OnlineOrderException(
          403,
          'MEMBER_REQUIRED',
          'Verified membership is required for a coupon',
        );
      }
      final calculated = await _loadProducts(conn, input.items);
      final subtotal = _round2(
        calculated.fold<double>(
          0,
          (sum, item) => sum + _double(item['subtotal']),
        ),
      );
      final grossProfit = calculated.fold<double>(
        0,
        (sum, item) => sum + _double(item['grossProfit']),
      );
      final delivery = OnlineOrderRules.deliveryEstimate(
        deliveryType: input.deliveryType,
        gpsLocation: input.gpsLocation,
        grossProfit: grossProfit,
      );

      Map<String, String?>? coupon;
      var couponDiscount = 0.0;
      DateTime? reservedUntil;
      if (input.couponCode != null) {
        coupon = await _lockCoupon(conn, input.couponCode!, customerId!);
        final value = _double(coupon['discount_value']);
        couponDiscount = _round2(math.min(value, subtotal));
        final expiresAt = DateTime.parse(coupon['expires_at']!);
        final twentyFourHours = DateTime.now().add(const Duration(hours: 24));
        reservedUntil = expiresAt.isBefore(twentyFourHours)
            ? expiresAt
            : twentyFourHours;
      }
      final grandTotal = _round2(
        math.max(0, subtotal - couponDiscount) + delivery.fee,
      );
      final orderNumber = _orderNumber(input.clientRequestId);
      final itemsJson = jsonEncode(
        calculated
            .map(
              (item) => Map<String, dynamic>.from(item)..remove('grossProfit'),
            )
            .toList(),
      );
      final inserted = await conn.execute(
        '''INSERT INTO online_orders
           (orderNumber, customerId, customerName, customerPhone, lineUserId,
            lineDisplayName, deliveryType, deliveryAddress, gpsLocation,
            distanceKm, deliveryFee, totalAmount, grandTotal, itemsJson, notes,
            status, clientRequestId, payloadHash, couponCode, couponDiscount,
            couponReservedUntil, createdAt)
           VALUES
           (:orderNumber, :customerId, :customerName, :customerPhone, :lineUserId,
            :lineDisplayName, :deliveryType, :deliveryAddress, :gpsLocation,
            :distanceKm, :deliveryFee, :subtotal, :grandTotal, :itemsJson, :notes,
            'PENDING', :requestId, :payloadHash, :couponCode, :couponDiscount,
            :reservedUntil, NOW())''',
        {
          'orderNumber': orderNumber,
          'customerId': customerId,
          'customerName': input.customerName,
          'customerPhone': input.customerPhone,
          'lineUserId': identity?.subject,
          'lineDisplayName': identity?.displayName ?? '',
          'deliveryType': input.deliveryType,
          'deliveryAddress': input.deliveryAddress,
          'gpsLocation': input.gpsLocation,
          'distanceKm': delivery.distanceKm,
          'deliveryFee': delivery.fee,
          'subtotal': subtotal,
          'grandTotal': grandTotal,
          'itemsJson': itemsJson,
          'notes': input.notes,
          'requestId': input.clientRequestId,
          'payloadHash': hash,
          'couponCode': input.couponCode,
          'couponDiscount': couponDiscount,
          'reservedUntil': reservedUntil == null
              ? null
              : _databaseDate(reservedUntil),
        },
      );
      final orderId = inserted.lastInsertID.toInt();
      if (coupon != null) {
        final reserved = await conn.execute(
          '''UPDATE reward_coupon
             SET status = 'RESERVED', reserved_online_order_id = :orderId,
                 reserved_until = :reservedUntil
             WHERE id = :couponId AND customer_id = :customerId
               AND status = 'ACTIVE' AND expires_at > NOW()''',
          {
            'orderId': orderId,
            'reservedUntil': _databaseDate(reservedUntil!),
            'couponId': coupon['id'],
            'customerId': customerId,
          },
        );
        if (reserved.affectedRows != BigInt.one) {
          throw const OnlineOrderException(
            409,
            'COUPON_UNAVAILABLE',
            'Coupon is unavailable',
          );
        }
      }
      final createdResult = OnlineOrderResult(
        id: orderId,
        orderNumber: orderNumber,
        totalAmount: subtotal,
        deliveryFee: delivery.fee,
        grandTotal: grandTotal,
        distanceKm: delivery.distanceKm,
        couponDiscount: couponDiscount,
        couponCode: input.couponCode,
        couponReservedUntil: reservedUntil == null
            ? null
            : _databaseDate(reservedUntil),
        items: calculated
            .map(
              (item) => Map<String, dynamic>.from(item)..remove('grossProfit'),
            )
            .toList(),
        deliveryType: input.deliveryType,
        deliveryAddress: input.deliveryAddress,
        gpsLocation: input.gpsLocation,
        notes: input.notes,
        isReplay: false,
      );
      await conn.execute('COMMIT');
      return createdResult;
    } catch (error) {
      await conn.execute('ROLLBACK');
      if (OnlineOrderRules.isDuplicateKeyError(error)) {
        // A concurrent request may commit the same UUID before this insert.
        final winner = await _findByClientRequestId(
          conn,
          input.clientRequestId,
          forUpdate: false,
        );
        if (winner == null) rethrow;
        if (!OnlineOrderRules.isIdempotentReplay(winner['payloadHash'], hash)) {
          throw const OnlineOrderException(
            409,
            'IDEMPOTENCY_CONFLICT',
            'clientRequestId was already used for different order data',
          );
        }
        return _resultFromRow(winner, isReplay: true);
      }
      rethrow;
    }
  }

  Future<Map<String, String?>?> _findByClientRequestId(
    MySQLConnection conn,
    String requestId, {
    required bool forUpdate,
  }) async {
    final result = await conn.execute(
      '''SELECT id, orderNumber, totalAmount, deliveryFee, grandTotal,
                distanceKm, couponCode, couponDiscount, couponReservedUntil,
                itemsJson, deliveryType, deliveryAddress, gpsLocation, notes,
                payloadHash
         FROM online_orders WHERE clientRequestId = :requestId
         LIMIT 1${forUpdate ? ' FOR UPDATE' : ''}''',
      {'requestId': requestId},
    );
    return result.rows.isEmpty ? null : result.rows.first.assoc();
  }

  Future<Map<String, dynamic>> updateStatus({
    required int orderId,
    required String targetStatus,
    required String actor,
  }) async {
    final target = targetStatus.trim().toUpperCase();
    if (!OnlineOrderRules.allowedStatuses.contains(target)) {
      throw const OnlineOrderException(
        400,
        'INVALID_STATUS',
        'Invalid order status',
      );
    }
    final conn = await DbConfig().connection;
    await conn.execute('START TRANSACTION');
    try {
      final order = await conn.execute(
        'SELECT status FROM online_orders WHERE id = :id LIMIT 1 FOR UPDATE',
        {'id': orderId},
      );
      if (order.rows.isEmpty) {
        throw const OnlineOrderException(
          404,
          'ORDER_NOT_FOUND',
          'Order not found',
        );
      }
      final current = order.rows.first.assoc()['status']?.toUpperCase() ?? '';
      if (!OnlineOrderRules.canTransition(current, target)) {
        throw const OnlineOrderException(
          409,
          'INVALID_STATUS_TRANSITION',
          'Order status transition is not allowed',
        );
      }
      await conn.execute(
        '''UPDATE online_orders SET status = :status, confirmedBy = :actor,
             updatedAt = NOW() WHERE id = :id''',
        {'status': target, 'actor': actor, 'id': orderId},
      );
      if (target == 'CANCELLED' || target == 'REJECTED') {
        await conn.execute(
          '''UPDATE reward_coupon
             SET status = CASE WHEN expires_at > NOW() THEN 'ACTIVE' ELSE 'EXPIRED' END,
                 reserved_online_order_id = NULL, reserved_until = NULL
             WHERE reserved_online_order_id = :id AND status = 'RESERVED' ''',
          {'id': orderId},
        );
      }
      await conn.execute('COMMIT');
      return {'status': target, 'previousStatus': current};
    } catch (_) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadProducts(
    MySQLConnection conn,
    List<OnlineOrderItemInput> requested,
  ) async {
    final placeholders = <String>[];
    final params = <String, dynamic>{};
    for (var i = 0; i < requested.length; i++) {
      final key = 'product$i';
      placeholders.add(':$key');
      params[key] = requested[i].productId;
    }
    final result = await conn.execute(
      '''SELECT id, name, retailPrice, costPrice, stockQuantity FROM product
         WHERE id IN (${placeholders.join(',')}) AND isActive = 1 FOR UPDATE''',
      params,
    );
    final products = {
      for (final row in result.rows) int.parse(row.assoc()['id']!): row.assoc(),
    };
    if (products.length != requested.length) {
      throw const OnlineOrderException(
        409,
        'PRODUCT_UNAVAILABLE',
        'One or more products are unavailable',
      );
    }
    return requested.map((request) {
      final product = products[request.productId]!;
      final price = _double(product['retailPrice']);
      final cost = _double(product['costPrice']);
      final stock = _double(product['stockQuantity']);
      if (!price.isFinite || price < 0 || !cost.isFinite || cost < 0) {
        throw const OnlineOrderException(
          409,
          'PRODUCT_UNAVAILABLE',
          'One or more products are unavailable',
        );
      }
      if (!stock.isFinite || stock < request.quantity) {
        throw const OnlineOrderException(
          409,
          'OUT_OF_STOCK',
          'One or more products are out of stock',
        );
      }
      return <String, dynamic>{
        'productId': request.productId,
        'name': product['name'] ?? 'สินค้า',
        'quantity': request.quantity,
        'price': _round2(price),
        'subtotal': _round2(price * request.quantity),
        'grossProfit': math.max(0.0, (price - cost) * request.quantity),
      };
    }).toList();
  }

  Future<Map<String, String?>> _lockCoupon(
    MySQLConnection conn,
    String code,
    int customerId,
  ) async {
    await conn.execute(
      '''UPDATE reward_coupon
         SET status = CASE WHEN expires_at > NOW() THEN 'ACTIVE' ELSE 'EXPIRED' END,
             reserved_online_order_id = NULL, reserved_until = NULL
         WHERE coupon_code = :code AND status = 'RESERVED'
           AND (reserved_until IS NULL OR reserved_until <= NOW())''',
      {'code': code},
    );
    final result = await conn.execute(
      '''SELECT id, customer_id, discount_value, expires_at, status
         FROM reward_coupon WHERE coupon_code = :code LIMIT 1 FOR UPDATE''',
      {'code': code},
    );
    if (result.rows.isEmpty) {
      throw const OnlineOrderException(
        409,
        'COUPON_UNAVAILABLE',
        'Coupon is unavailable',
      );
    }
    final coupon = result.rows.first.assoc();
    final owner = int.tryParse(coupon['customer_id'] ?? '');
    final expiry = DateTime.tryParse(coupon['expires_at'] ?? '');
    final discount = _double(coupon['discount_value']);
    if (owner == null ||
        expiry == null ||
        !discount.isFinite ||
        discount <= 0 ||
        !OnlineOrderRules.couponReservable(
          status: coupon['status'] ?? '',
          couponCustomerId: owner,
          customerId: customerId,
          expiresAt: expiry,
          now: DateTime.now(),
        )) {
      throw const OnlineOrderException(
        409,
        'COUPON_UNAVAILABLE',
        'Coupon is unavailable',
      );
    }
    return coupon;
  }

  OnlineOrderResult _resultFromRow(
    Map<String, String?> row, {
    required bool isReplay,
  }) {
    var items = <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(row['itemsJson'] ?? '[]');
      if (decoded is List) {
        items = decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    return OnlineOrderResult(
      id: int.parse(row['id']!),
      orderNumber: row['orderNumber'] ?? '',
      totalAmount: _double(row['totalAmount']),
      deliveryFee: _double(row['deliveryFee']),
      grandTotal: _double(row['grandTotal']),
      distanceKm: _double(row['distanceKm']),
      couponDiscount: _double(row['couponDiscount']),
      couponCode: row['couponCode'],
      couponReservedUntil: row['couponReservedUntil'],
      items: items,
      deliveryType: row['deliveryType'] ?? 'pickup',
      deliveryAddress: row['deliveryAddress'] ?? '',
      gpsLocation: row['gpsLocation'] ?? '',
      notes: row['notes'] ?? '',
      isReplay: isReplay,
    );
  }

  static String _orderNumber(String requestId) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'ON-${now.year}${two(now.month)}${two(now.day)}-${requestId.substring(0, 8).toUpperCase()}';
  }

  static String _databaseDate(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  static double _double(dynamic value) =>
      double.tryParse(value?.toString() ?? '') ?? 0;

  static double _round2(num value) => (value * 100).round() / 100;
}
