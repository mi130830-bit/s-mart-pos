import 'dart:math' as math;

class LoyaltyAwardRules {
  const LoyaltyAwardRules._();

  static int nextCycleNumber({
    required int? currentCycleNumber,
    required bool currentAwardReversed,
  }) {
    if (currentCycleNumber == null || currentCycleNumber < 1) return 1;
    return currentAwardReversed ? currentCycleNumber + 1 : currentCycleNumber;
  }

  static bool isExactUnusedAwardLot({
    required int pointsEarned,
    required int pointsUsed,
    required int awardedPoints,
  }) =>
      awardedPoints > 0 && pointsEarned == awardedPoints && pointsUsed == 0;

  static bool priorPaidSpendQualifies({
    required bool enabled,
    required double priorPaidSpend,
    required double threshold,
  }) {
    if (!enabled ||
        !priorPaidSpend.isFinite ||
        !threshold.isFinite ||
        threshold <= 0) {
      return false;
    }
    return math.max(0, priorPaidSpend) >= threshold;
  }

  static double highestMultiplier(Iterable<double> candidates) {
    var highest = 1.0;
    for (final candidate in candidates) {
      if (candidate.isFinite && candidate > highest) highest = candidate;
    }
    return highest;
  }

  static int awardedPoints({
    required double paidAmount,
    required double bahtPerPoint,
    required double multiplier,
    int bonusPoints = 0,
  }) {
    if (!paidAmount.isFinite ||
        paidAmount <= 0 ||
        !bahtPerPoint.isFinite ||
        bahtPerPoint <= 0) {
      return math.max(0, bonusPoints);
    }
    final base = (paidAmount / bahtPerPoint).floor();
    return (base * math.max(1, multiplier)).floor() + math.max(0, bonusPoints);
  }
}
