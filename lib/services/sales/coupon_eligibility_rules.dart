class CouponEligibilityRules {
  static bool canUse({
    required String status,
    required int? requestedSourceOnlineOrderId,
    required int? reservedOnlineOrderId,
    required DateTime? reservedUntil,
    required DateTime now,
  }) {
    final normalized = status.trim().toUpperCase();
    if (normalized == 'ACTIVE') return true;
    return normalized == 'RESERVED' &&
        requestedSourceOnlineOrderId != null &&
        reservedOnlineOrderId == requestedSourceOnlineOrderId &&
        reservedUntil != null &&
        reservedUntil.isAfter(now);
  }

  static bool discountMatches(double expected, double actual) =>
      (expected - actual).abs() <= 0.01;

  static bool checkoutIsFullyPaid({
    required double received,
    required double grandTotal,
    required bool hasCreditPayment,
  }) =>
      !hasCreditPayment && received >= grandTotal - 0.01;
}
