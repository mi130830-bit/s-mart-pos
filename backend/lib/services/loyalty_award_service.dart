import 'dart:math' as math;

import 'member_tier_service.dart';

class LoyaltyAwardPolicy {
  const LoyaltyAwardPolicy._();

  static int nextCycleNumber({
    required int? currentCycleNumber,
    required bool currentAwardReversed,
  }) {
    if (currentCycleNumber == null || currentCycleNumber < 1) return 1;
    return currentAwardReversed ? currentCycleNumber + 1 : currentCycleNumber;
  }

  static double birthdayMultiplier(DateTime? birthday, DateTime nowBangkok) {
    if (birthday == null || birthday.month != nowBangkok.month) return 1;
    return birthday.day == nowBangkok.day ? 2.5 : 1.25;
  }

  static int awardedPoints({
    required double paidAmount,
    required double bahtPerPoint,
    required double multiplier,
  }) {
    if (!paidAmount.isFinite ||
        paidAmount <= 0 ||
        !bahtPerPoint.isFinite ||
        bahtPerPoint <= 0) {
      return 0;
    }
    return ((paidAmount / bahtPerPoint).floor() * math.max(1, multiplier))
        .floor();
  }

  static String semiannualExpiry(DateTime nowBangkok) {
    final year = nowBangkok.year + 1;
    return nowBangkok.month <= 6
        ? '$year-06-30 23:59:59'
        : '$year-12-31 23:59:59';
  }
}

/// Awards one fully-paid POS order inside the transaction owned by [conn].
/// The order row lock and unique award/event rows make retries idempotent.
class LoyaltyAwardService {
  Future<int> awardClosedOrderWithinTransaction(
    dynamic conn, {
    required int orderId,
    required String source,
  }) async {
    if (orderId <= 0 || source.isEmpty || source.length > 30) return 0;

    final locked = await conn.execute(
      '''SELECT o.id, o.customerId, o.grandTotal, o.received, o.status,
                c.dateOfBirth,
                COALESCE(t.pointsMultiplier, 1) AS permanentMultiplier,
                COALESCE(t.loyaltySegment, 'CUSTOMER') AS loyaltySegment
         FROM `order` o
         JOIN customer c ON c.id = o.customerId
         LEFT JOIN member_tier t ON t.id = c.tierId
         WHERE o.id = :orderId
           AND (c.isDeleted = 0 OR c.isDeleted IS NULL)
         LIMIT 1 FOR UPDATE''',
      {'orderId': orderId},
    );
    if (locked.rows.isEmpty) return 0;
    final row = locked.rows.first.assoc();
    if (!{'COMPLETED', 'PAID'}.contains(row['status']?.toUpperCase())) return 0;
    final amount = double.tryParse(row['grandTotal'] ?? '') ?? 0;
    final received = double.tryParse(row['received'] ?? '') ?? 0;
    if (!amount.isFinite || amount <= 0 || received + .01 < amount) return 0;
    final customerId = int.tryParse(row['customerId'] ?? '') ?? 0;
    if (customerId <= 0) return 0;

    final priorAward = await conn.execute(
      '''SELECT id, awarded_points, cycle_number, reversed_at
         FROM loyalty_order_award
         WHERE order_id = :orderId LIMIT 1 FOR UPDATE''',
      {'orderId': orderId},
    );
    final priorAwardRow = priorAward.rows.isEmpty
        ? null
        : priorAward.rows.first.assoc();
    if (priorAwardRow != null && priorAwardRow['reversed_at'] == null) {
      return int.tryParse(priorAwardRow['awarded_points'] ?? '0') ?? 0;
    }
    final cycleNumber = LoyaltyAwardPolicy.nextCycleNumber(
      currentCycleNumber: int.tryParse(
        priorAwardRow?['cycle_number']?.toString() ?? '',
      ),
      currentAwardReversed:
          priorAwardRow != null && priorAwardRow['reversed_at'] != null,
    );

    final eventKey = 'CLOSE:$orderId:CYCLE:$cycleNumber';
    final priorEvent = await conn.execute(
      '''SELECT id FROM loyalty_payment_event
         WHERE idempotency_key = :key LIMIT 1 FOR UPDATE''',
      {'key': eventKey},
    );
    if (priorEvent.rows.isNotEmpty) return 0;

    final systemSettings = await conn.execute(
      '''SELECT setting_key, setting_value FROM system_settings
         WHERE setting_key IN ('point_enabled', 'point_price_rate')''',
    );
    var pointsEnabled = false;
    var bahtPerPoint = 100.0;
    for (final settingRow in systemSettings.rows) {
      final setting = settingRow.assoc();
      if (setting['setting_key'] == 'point_enabled') {
        final value = setting['setting_value']?.toLowerCase();
        pointsEnabled = value == 'true' || value == '1';
      } else if (setting['setting_key'] == 'point_price_rate') {
        bahtPerPoint = double.tryParse(setting['setting_value'] ?? '') ?? 100;
      }
    }
    if (!pointsEnabled || !bahtPerPoint.isFinite || bahtPerPoint <= 0) return 0;

    final tierSettings = await conn.execute(
      '''SELECT enabled, monthly_threshold, points_multiplier,
                contractor_threshold_1, contractor_multiplier_1,
                contractor_threshold_2, contractor_multiplier_2,
                settings_version, program_started_at
         FROM loyalty_tier_settings
         WHERE id = 1 LIMIT 1''',
    );
    if (tierSettings.rows.isEmpty) return 0;
    final tierRow = tierSettings.rows.first.assoc();
    final monthlyEnabled = tierRow['enabled'] == '1';
    final monthlyThreshold =
        double.tryParse(tierRow['monthly_threshold'] ?? '') ?? 10000;
    final monthlyMultiplier =
        double.tryParse(tierRow['points_multiplier'] ?? '') ?? 2;
    final contractorThreshold1 =
        double.tryParse(tierRow['contractor_threshold_1'] ?? '') ?? 20000;
    final contractorMultiplier1 =
        double.tryParse(tierRow['contractor_multiplier_1'] ?? '') ?? 2.5;
    final contractorThreshold2 =
        double.tryParse(tierRow['contractor_threshold_2'] ?? '') ?? 50000;
    final contractorMultiplier2 =
        double.tryParse(tierRow['contractor_multiplier_2'] ?? '') ?? 3;
    final now = DateTime.now();
    final month = MemberTierRules.bangkokMonthRange(now);
    final priorSpendRows = await conn.execute(
      '''SELECT COALESCE(SUM(grandTotal), 0) AS monthlySpend
         FROM `order`
         WHERE customerId = :customerId AND id <> :orderId
           AND status IN ('COMPLETED', 'PAID')
           AND COALESCE(received, 0) + 0.01 >= grandTotal
           AND COALESCE(loyaltyPaidAt, createdAt) >= :monthStart
           AND COALESCE(loyaltyPaidAt, createdAt) >=
               COALESCE(:programStartedAt, '1000-01-01 00:00:00')
           AND COALESCE(loyaltyPaidAt, createdAt) < :monthEnd''',
      {
        'customerId': customerId,
        'orderId': orderId,
        'monthStart': month.startDatabase,
        'monthEnd': month.endDatabase,
        'programStartedAt': tierRow['program_started_at'],
      },
    );
    final priorSpend =
        double.tryParse(
          priorSpendRows.rows.first.assoc()['monthlySpend'] ?? '0',
        ) ??
        0;
    final permanentMultiplier =
        double.tryParse(row['permanentMultiplier'] ?? '1') ?? 1;
    final isContractor = row['loyaltySegment'] == 'CONTRACTOR';
    final entitlement = MemberTierRules.deriveEntitlement(
      monthlySpend: priorSpend,
      threshold: monthlyThreshold,
      enabled: monthlyEnabled,
      permanentMultiplier: permanentMultiplier,
      monthlyMultiplier: monthlyMultiplier,
      isContractor: isContractor,
      contractorThreshold1: contractorThreshold1,
      contractorMultiplier1: contractorMultiplier1,
      contractorThreshold2: contractorThreshold2,
      contractorMultiplier2: contractorMultiplier2,
    );
    final nowBangkok = now.toUtc().add(const Duration(hours: 7));
    final birthday = DateTime.tryParse(row['dateOfBirth'] ?? '');
    final birthdayMultiplier = LoyaltyAwardPolicy.birthdayMultiplier(
      birthday,
      nowBangkok,
    );
    final multiplier = math.max(
      entitlement.pointsMultiplier,
      birthdayMultiplier,
    );
    final points = LoyaltyAwardPolicy.awardedPoints(
      paidAmount: amount,
      bahtPerPoint: bahtPerPoint,
      multiplier: multiplier,
    );
    if (points <= 0) return 0;

    await conn.execute(
      '''UPDATE `order` SET loyaltyPaidAt = COALESCE(loyaltyPaidAt, NOW())
         WHERE id = :orderId''',
      {'orderId': orderId},
    );
    final paymentEvent = await conn.execute(
      '''INSERT INTO loyalty_payment_event
           (idempotency_key, customer_id, order_id, amount, paid_at, source)
         VALUES (:key, :customerId, :orderId, :amount, NOW(), :source)''',
      {
        'key': eventKey,
        'customerId': customerId,
        'orderId': orderId,
        'amount': amount,
        'source': source,
      },
    );
    final ledger = await conn.execute(
      '''INSERT INTO point_ledger
           (customer_id, points_earned, order_id, expires_at)
         VALUES (:customerId, :points, :orderId, :expiry)''',
      {
        'customerId': customerId,
        'points': points,
        'orderId': orderId,
        'expiry': LoyaltyAwardPolicy.semiannualExpiry(nowBangkok),
      },
    );
    final awardValues = {
      'orderId': orderId,
      'customerId': customerId,
      'month': month.startDatabase.substring(0, 10),
      'amount': amount,
      'basePoints': (amount / bahtPerPoint).floor(),
      'multiplier': multiplier,
      'points': points,
      'threshold': isContractor
          ? (priorSpend > contractorThreshold2
                ? contractorThreshold2
                : contractorThreshold1)
          : monthlyThreshold,
      'settingsVersion': int.tryParse(tierRow['settings_version'] ?? '0') ?? 0,
      'source': source,
      'cycleNumber': cycleNumber,
      'eventId': paymentEvent.lastInsertID.toInt(),
      'ledgerId': ledger.lastInsertID.toInt(),
    };
    if (priorAwardRow == null) {
      await conn.execute('''INSERT INTO loyalty_order_award
             (order_id, customer_id, paid_at, qualifying_month, base_amount,
              base_points, multiplier, bonus_points, awarded_points,
              monthly_threshold, settings_version, point_ledger_id, source,
              cycle_number, current_payment_event_id)
           VALUES (:orderId, :customerId, NOW(), :month, :amount, :basePoints,
                   :multiplier, 0, :points, :threshold, :settingsVersion,
                   :ledgerId, :source, :cycleNumber, :eventId)''', awardValues);
    } else {
      final updated = await conn.execute(
        '''UPDATE loyalty_order_award
           SET customer_id = :customerId, paid_at = NOW(),
               qualifying_month = :month, base_amount = :amount,
               base_points = :basePoints, multiplier = :multiplier,
               bonus_points = 0, awarded_points = :points,
               monthly_threshold = :threshold,
               settings_version = :settingsVersion,
               point_ledger_id = :ledgerId, source = :source,
               cycle_number = :cycleNumber,
               current_payment_event_id = :eventId,
               reversed_at = NULL, reversal_reason = NULL
           WHERE order_id = :orderId AND reversed_at IS NOT NULL''',
        awardValues,
      );
      if (updated.affectedRows != BigInt.one) {
        throw StateError('Loyalty award changed during re-award');
      }
    }
    await conn.execute(
      '''UPDATE customer SET
           totalSpending = COALESCE(totalSpending, 0) + :amount,
           currentPoints = (
             SELECT COALESCE(SUM(points_earned - points_used), 0)
             FROM point_ledger WHERE customer_id = :customerId
               AND (expires_at IS NULL OR expires_at > NOW())
           )
         WHERE id = :customerId''',
      {'amount': amount, 'customerId': customerId},
    );
    return points;
  }
}
