import 'package:backend/services/online_order_service.dart';
import 'package:mysql_client_plus/exception.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> orderBody() => {
    'clientRequestId': '550e8400-e29b-41d4-a716-446655440000',
    'customerName': 'Customer',
    'customerPhone': '081-234-5678',
    'deliveryType': 'delivery',
    'deliveryAddress': 'Phetchabun',
    'gpsLocation': '16.160189, 100.802307',
    'notes': 'Call first',
    'items': [
      {'productId': 2, 'quantity': 1, 'name': 'spoofed', 'price': 0},
      {'productId': 1, 'quantity': 2},
      {'productId': 2, 'quantity': 3},
    ],
  };

  test('requires a UUID clientRequestId', () {
    expect(
      OnlineOrderRules.validateClientRequestId(
        '550E8400-E29B-41D4-A716-446655440000',
      ),
      '550e8400-e29b-41d4-a716-446655440000',
    );
    expect(
      () => OnlineOrderRules.validateClientRequestId('request-1'),
      throwsA(isA<OnlineOrderException>()),
    );
  });

  test('canonical idempotency input ignores client prices and item order', () {
    final first = OnlineOrderRules.parseInput(orderBody());
    final reordered = orderBody()
      ..['distanceKm'] = 999999
      ..['deliveryFee'] = -500
      ..['hasHeavyGoods'] = false
      ..['items'] = [
        {'productId': 2, 'quantity': 4, 'name': 'other', 'price': 999999},
        {'productId': 1, 'quantity': 2, 'name': 'other', 'price': 999999},
      ];
    final second = OnlineOrderRules.parseInput(reordered);

    expect(first.items.map((item) => item.productId), [1, 2]);
    expect(first.items.map((item) => item.quantity), [2, 4]);
    expect(
      first.payloadHash(lineSubject: 'U123'),
      second.payloadHash(lineSubject: 'U123'),
    );
    expect(
      first.payloadHash(lineSubject: 'U123'),
      isNot(first.payloadHash(lineSubject: 'U999')),
    );
  });

  test('duplicate-key reconciliation only replays an identical payload', () {
    expect(
      OnlineOrderRules.isDuplicateKeyError(
        const MySQLServerException('duplicate', 1062),
      ),
      isTrue,
    );
    expect(
      OnlineOrderRules.isDuplicateKeyError(
        const MySQLServerException('other', 1048),
      ),
      isFalse,
    );
    expect(OnlineOrderRules.isIdempotentReplay('same', 'same'), isTrue);
    expect(OnlineOrderRules.isIdempotentReplay('first', 'second'), isFalse);
    expect(OnlineOrderRules.isIdempotentReplay(null, 'second'), isFalse);
  });

  test('quantities must be positive finite and bounded', () {
    for (final quantity in [0, -1, double.nan, double.infinity, 100001]) {
      final body = orderBody()
        ..['items'] = [
          {'productId': 1, 'quantity': quantity},
        ];
      expect(
        () => OnlineOrderRules.parseInput(body),
        throwsA(isA<OnlineOrderException>()),
      );
    }
  });

  test('delivery estimate is server-derived from GPS distance rules', () {
    final nearby = OnlineOrderRules.deliveryEstimate(
      deliveryType: 'delivery',
      gpsLocation: '16.160189,100.802307',
      grossProfit: 0,
    );
    final pickup = OnlineOrderRules.deliveryEstimate(
      deliveryType: 'pickup',
      gpsLocation: '0,0',
      grossProfit: 0,
    );

    expect(nearby.distanceKm, 0);
    expect(nearby.fee, 50);
    expect(pickup.fee, 0);
  });

  test('online order status transitions are allowlisted', () {
    expect(OnlineOrderRules.canTransition('PENDING', 'CONFIRMED'), isTrue);
    expect(OnlineOrderRules.canTransition('CONFIRMED', 'DISPATCHED'), isTrue);
    expect(OnlineOrderRules.canTransition('DISPATCHED', 'COMPLETED'), isTrue);
    expect(OnlineOrderRules.canTransition('COMPLETED', 'PENDING'), isFalse);
    expect(OnlineOrderRules.canTransition('PENDING', 'ARBITRARY'), isFalse);
  });

  test('coupon reservation requires active ownership and future expiry', () {
    final now = DateTime.utc(2026, 8, 25, 12);
    expect(
      OnlineOrderRules.couponReservable(
        status: 'ACTIVE',
        couponCustomerId: 7,
        customerId: 7,
        expiresAt: now.add(const Duration(seconds: 1)),
        now: now,
      ),
      isTrue,
    );
    expect(
      OnlineOrderRules.couponReservable(
        status: 'RESERVED',
        couponCustomerId: 7,
        customerId: 7,
        expiresAt: now.add(const Duration(days: 1)),
        now: now,
      ),
      isFalse,
    );
    expect(
      OnlineOrderRules.couponReservable(
        status: 'ACTIVE',
        couponCustomerId: 8,
        customerId: 7,
        expiresAt: now.add(const Duration(days: 1)),
        now: now,
      ),
      isFalse,
    );
    expect(
      OnlineOrderRules.couponReservable(
        status: 'ACTIVE',
        couponCustomerId: 7,
        customerId: 7,
        expiresAt: now,
        now: now,
      ),
      isFalse,
    );
  });
}
