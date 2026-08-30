import 'dart:math';

import 'package:backend/services/reward_redemption_service.dart';
import 'package:test/test.dart';

void main() {
  test('reward redemption requires a strict UUID idempotency key', () {
    const requestId = '123e4567-e89b-42d3-a456-426614174000';
    expect(
      RewardRedemptionRules.validateClientRequestId(requestId.toUpperCase()),
      requestId,
    );
    expect(
      () => RewardRedemptionRules.validateClientRequestId('retry-me'),
      throwsA(isA<RewardRedemptionException>()),
    );
  });

  test('reward replay must belong to the same member and reward', () {
    const row = <String, String?>{'customer_id': '8', 'reward_id': '21'};
    expect(
      RewardRedemptionRules.replayMatches(row, customerId: 8, rewardId: 21),
      isTrue,
    );
    expect(
      RewardRedemptionRules.replayMatches(row, customerId: 9, rewardId: 21),
      isFalse,
    );
  });

  test('coupon codes use a long bounded alphabet and vary per issuance', () {
    final random = Random(19);
    final codes = List.generate(
      100,
      (_) => RewardRedemptionRules.createCouponCode(random: random),
    );
    final format = RegExp(r'^SMR-[A-Z2-9]{6}-[A-Z2-9]{6}$');
    expect(codes, everyElement(matches(format)));
    expect(codes.toSet(), hasLength(codes.length));
  });

  test('point lots are consumed in supplied expiry order', () {
    expect(RewardRedemptionRules.allocateLotUsage([40, 30, 100], 55), [
      40,
      15,
      0,
    ]);
    expect(
      () => RewardRedemptionRules.allocateLotUsage([10, 20], 31),
      throwsA(
        isA<RewardRedemptionException>().having(
          (error) => error.code,
          'code',
          'INSUFFICIENT_POINTS',
        ),
      ),
    );
  });
}
