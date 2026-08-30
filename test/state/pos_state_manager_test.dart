import 'package:flutter_test/flutter_test.dart';
import 'package:pos_desktop/models/online_order_model.dart';
import 'package:pos_desktop/repositories/online_order_repository.dart';
import 'package:pos_desktop/services/sales/coupon_eligibility_rules.dart';

void main() {
  group('online order coupon handoff', () {
    test('ACTIVE is manual-use eligible but RESERVED requires matching source',
        () {
      final now = DateTime(2026, 8, 25, 12);
      expect(
        CouponEligibilityRules.canUse(
          status: 'ACTIVE',
          requestedSourceOnlineOrderId: null,
          reservedOnlineOrderId: null,
          reservedUntil: null,
          now: now,
        ),
        isTrue,
      );
      expect(
        CouponEligibilityRules.canUse(
          status: 'RESERVED',
          requestedSourceOnlineOrderId: 42,
          reservedOnlineOrderId: 42,
          reservedUntil: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
      expect(
        CouponEligibilityRules.canUse(
          status: 'RESERVED',
          requestedSourceOnlineOrderId: 41,
          reservedOnlineOrderId: 42,
          reservedUntil: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
      expect(
        CouponEligibilityRules.canUse(
          status: 'RESERVED',
          requestedSourceOnlineOrderId: 42,
          reservedOnlineOrderId: 42,
          reservedUntil: now,
          now: now,
        ),
        isFalse,
      );
    });

    test('coupon checkout must be fully paid without credit remainder', () {
      expect(
        CouponEligibilityRules.checkoutIsFullyPaid(
          received: 100,
          grandTotal: 100,
          hasCreditPayment: false,
        ),
        isTrue,
      );
      expect(
        CouponEligibilityRules.checkoutIsFullyPaid(
          received: 90,
          grandTotal: 100,
          hasCreditPayment: false,
        ),
        isFalse,
      );
      expect(
        CouponEligibilityRules.checkoutIsFullyPaid(
          received: 100,
          grandTotal: 100,
          hasCreditPayment: true,
        ),
        isFalse,
      );
    });

    test('discount comparison allows only cent-level rounding noise', () {
      expect(CouponEligibilityRules.discountMatches(100, 100.009), isTrue);
      expect(CouponEligibilityRules.discountMatches(100, 100.02), isFalse);
    });

    test('parses coupon reservation and POS handoff fields compatibly', () {
      final order = OnlineOrder.fromJson({
        'id': 7,
        'orderNumber': 'WEB-7',
        'couponCode': 'SMR-TEST',
        'couponDiscount': '125.50',
        'couponReservedUntil': '2026-08-26 12:00:00',
        'couponReservationStatus': 'RESERVED',
        'posOrderId': '99',
        'itemsJson':
            '[{"productId":1,"name":"Item","quantity":2,"price":10,"subtotal":20}]',
      });

      expect(order.couponCode, 'SMR-TEST');
      expect(order.couponDiscount, 125.5);
      expect(order.couponReservationStatus, 'RESERVED');
      expect(order.posOrderId, 99);
      expect(order.items.single.productId, 1);
    });

    test('legacy online order without coupon columns still parses', () {
      final legacy = OnlineOrder.fromJson({'id': 1, 'itemsJson': '[]'});
      expect(legacy.couponCode, isNull);
      expect(legacy.couponDiscount, 0);
      expect(legacy.posOrderId, isNull);
    });

    test('backend-compatible transitions include fulfillment stages', () {
      expect(OnlineOrderTransitionRules.canTransition('PENDING', 'CONFIRMED'),
          isTrue);
      expect(OnlineOrderTransitionRules.canTransition('CONFIRMED', 'PREPARING'),
          isTrue);
      expect(OnlineOrderTransitionRules.canTransition('PREPARING', 'READY'),
          isTrue);
      expect(OnlineOrderTransitionRules.canTransition('READY', 'DISPATCHED'),
          isTrue);
      expect(OnlineOrderTransitionRules.canTransition('DISPATCHED', 'SHIPPING'),
          isTrue);
      expect(OnlineOrderTransitionRules.canTransition('SHIPPING', 'COMPLETED'),
          isTrue);
      expect(OnlineOrderTransitionRules.canTransition('COMPLETED', 'PENDING'),
          isFalse);
    });
  });
}
