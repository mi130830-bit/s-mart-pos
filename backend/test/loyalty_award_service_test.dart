import 'package:backend/services/loyalty_award_service.dart';
import 'package:test/test.dart';

void main() {
  test('birthday multiplier uses the highest birthday benefit only', () {
    final today = DateTime(2026, 8, 25);
    expect(
      LoyaltyAwardPolicy.birthdayMultiplier(DateTime(1990, 8, 25), today),
      2.5,
    );
    expect(
      LoyaltyAwardPolicy.birthdayMultiplier(DateTime(1990, 8, 1), today),
      1.25,
    );
    expect(
      LoyaltyAwardPolicy.birthdayMultiplier(DateTime(1990, 7, 25), today),
      1,
    );
  });

  test('award calculation floors base points before applying multiplier', () {
    expect(
      LoyaltyAwardPolicy.awardedPoints(
        paidAmount: 1099,
        bahtPerPoint: 100,
        multiplier: 2.5,
      ),
      25,
    );
    expect(
      LoyaltyAwardPolicy.awardedPoints(
        paidAmount: 1000,
        bahtPerPoint: 0,
        multiplier: 3,
      ),
      0,
    );
  });

  test('semiannual expiry keeps the established next-year boundaries', () {
    expect(
      LoyaltyAwardPolicy.semiannualExpiry(DateTime(2026, 6, 30)),
      '2027-06-30 23:59:59',
    );
    expect(
      LoyaltyAwardPolicy.semiannualExpiry(DateTime(2026, 7, 1)),
      '2027-12-31 23:59:59',
    );
  });

  test('re-award advances only after the current cycle was reversed', () {
    expect(
      LoyaltyAwardPolicy.nextCycleNumber(
        currentCycleNumber: null,
        currentAwardReversed: false,
      ),
      1,
    );
    expect(
      LoyaltyAwardPolicy.nextCycleNumber(
        currentCycleNumber: 1,
        currentAwardReversed: false,
      ),
      1,
    );
    expect(
      LoyaltyAwardPolicy.nextCycleNumber(
        currentCycleNumber: 1,
        currentAwardReversed: true,
      ),
      2,
    );
  });
}
