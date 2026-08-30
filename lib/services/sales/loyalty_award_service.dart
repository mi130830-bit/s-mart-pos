import '../mysql_service.dart';
import '../settings_service.dart';
import 'loyalty_award_rules.dart';

class LoyaltyReversalException implements Exception {
  const LoyaltyReversalException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'LoyaltyReversalException($code): $message';
}

/// Awards a fully paid credit order inside the caller's existing transaction.
/// The unique order award row is the final idempotency guard.
class LoyaltyAwardService {
  LoyaltyAwardService({MySQLService? db, SettingsService? settings})
      : _db = db ?? MySQLService(),
        _settings = settings ?? SettingsService();

  final MySQLService _db;
  final SettingsService _settings;

  Future<int> awardClosedOrderWithinTransaction({
    required int orderId,
    required String source,
  }) async {
    final rows = await _db.query('''
      SELECT o.id, o.customerId, o.grandTotal, o.status, o.loyaltyPaidAt,
             c.dateOfBirth,
             COALESCE(t.pointsMultiplier, 1) AS permanentMultiplier,
             COALESCE(t.loyaltySegment, 'CUSTOMER') AS loyaltySegment
      FROM `order` o
      JOIN customer c ON c.id = o.customerId
      LEFT JOIN member_tier t ON t.id = c.tierId
      WHERE o.id = :orderId LIMIT 1 FOR UPDATE
    ''', {'orderId': orderId});
    if (rows.isEmpty || rows.first['status']?.toString() != 'COMPLETED') {
      return 0;
    }
    final row = rows.first;
    final customerId = int.parse(row['customerId'].toString());
    await _db.query(
      'SELECT id FROM customer WHERE id = :id LIMIT 1 FOR UPDATE',
      {'id': customerId},
    );
    final existing = await _db.query('''
      SELECT id, awarded_points, cycle_number, reversed_at
      FROM loyalty_order_award
      WHERE order_id = :orderId LIMIT 1 FOR UPDATE
    ''', {'orderId': orderId});
    if (existing.isNotEmpty && existing.first['reversed_at'] == null) {
      return int.tryParse(
              existing.first['awarded_points']?.toString() ?? '0') ??
          0;
    }
    final cycleNumber = LoyaltyAwardRules.nextCycleNumber(
      currentCycleNumber: existing.isEmpty
          ? null
          : int.tryParse(existing.first['cycle_number']?.toString() ?? ''),
      currentAwardReversed:
          existing.isNotEmpty && existing.first['reversed_at'] != null,
    );

    final amount = double.tryParse(row['grandTotal']?.toString() ?? '0') ?? 0;
    if (amount <= 0 || !_settings.pointEnabled) return 0;
    var rate = _settings.pointPriceRate;
    if (rate <= 0) rate = 100;

    final settingsRows = await _db.query('''
      SELECT enabled, monthly_threshold, points_multiplier,
             contractor_threshold_1, contractor_multiplier_1,
             contractor_threshold_2, contractor_multiplier_2,
             settings_version, program_started_at
      FROM loyalty_tier_settings WHERE id = 1 LIMIT 1
    ''');
    if (settingsRows.isEmpty) return 0;
    final tierSettings = settingsRows.first;
    final enabled = tierSettings['enabled']?.toString() == '1';
    final priorRows = await _db.query('''
      SELECT COALESCE(SUM(grandTotal), 0) AS monthlySpend
      FROM `order`
      WHERE customerId = :customerId AND id <> :orderId
        AND status = 'COMPLETED'
        AND COALESCE(loyaltyPaidAt, createdAt) >=
            DATE_FORMAT(NOW(), '%Y-%m-01 00:00:00')
        AND COALESCE(loyaltyPaidAt, createdAt) >=
            COALESCE(:programStartedAt, '1000-01-01 00:00:00')
        AND COALESCE(loyaltyPaidAt, createdAt) <
            DATE_ADD(DATE_FORMAT(NOW(), '%Y-%m-01 00:00:00'), INTERVAL 1 MONTH)
    ''', {
      'customerId': customerId,
      'orderId': orderId,
      'programStartedAt': tierSettings['program_started_at'],
    });
    final priorSpend =
        double.tryParse(priorRows.first['monthlySpend']?.toString() ?? '0') ??
            0;
    final permanent =
        double.tryParse(row['permanentMultiplier']?.toString() ?? '1') ?? 1;
    var monthlyThreshold =
        double.tryParse(tierSettings['monthly_threshold']?.toString() ?? '0') ??
            0;
    var monthlyMultiplier = 1.0;
    final isContractor = row['loyaltySegment']?.toString() == 'CONTRACTOR';
    if (enabled && isContractor) {
      final threshold1 = double.tryParse(
              tierSettings['contractor_threshold_1']?.toString() ?? '20000') ??
          20000;
      final threshold2 = double.tryParse(
              tierSettings['contractor_threshold_2']?.toString() ?? '50000') ??
          50000;
      monthlyThreshold = priorSpend > threshold2 ? threshold2 : threshold1;
      monthlyMultiplier = priorSpend > threshold2
          ? (double.tryParse(
                  tierSettings['contractor_multiplier_2']?.toString() ?? '3') ??
              3)
          : priorSpend > threshold1
              ? (double.tryParse(
                      tierSettings['contractor_multiplier_1']?.toString() ??
                          '2.5') ??
                  2.5)
              : 2;
    } else if (enabled &&
        LoyaltyAwardRules.priorPaidSpendQualifies(
          enabled: true,
          priorPaidSpend: priorSpend,
          threshold: monthlyThreshold,
        )) {
      monthlyMultiplier = double.tryParse(
              tierSettings['points_multiplier']?.toString() ?? '2') ??
          2;
    }

    var birthdayMultiplier = 1.0;
    final birthday = DateTime.tryParse(row['dateOfBirth']?.toString() ?? '');
    final now = DateTime.now();
    if (birthday != null && birthday.month == now.month) {
      birthdayMultiplier = birthday.day == now.day ? 2.5 : 1.25;
    }
    final multiplier = LoyaltyAwardRules.highestMultiplier([
      permanent,
      monthlyMultiplier,
      birthdayMultiplier,
    ]);
    final points = LoyaltyAwardRules.awardedPoints(
      paidAmount: amount,
      bahtPerPoint: rate,
      multiplier: multiplier,
    );
    if (points <= 0) return 0;

    await _db.execute(
      'UPDATE `order` SET loyaltyPaidAt = COALESCE(loyaltyPaidAt, NOW()) WHERE id = :orderId',
      {'orderId': orderId},
    );
    final paymentEvent = await _db.execute('''
      INSERT INTO loyalty_payment_event
        (idempotency_key, customer_id, order_id, amount, paid_at, source)
      VALUES (:key, :customerId, :orderId, :amount, NOW(), :source)
    ''', {
      'key': 'CLOSE:$orderId:CYCLE:$cycleNumber',
      'customerId': customerId,
      'orderId': orderId,
      'amount': amount,
      'source': source,
    });
    final expiry = now.month <= 6
        ? '${now.year + 1}-06-30 23:59:59'
        : '${now.year + 1}-12-31 23:59:59';
    final ledger = await _db.execute('''
      INSERT INTO point_ledger (customer_id, points_earned, order_id, expires_at)
      VALUES (:customerId, :points, :orderId, :expiry)
    ''', {
      'customerId': customerId,
      'points': points,
      'orderId': orderId,
      'expiry': expiry,
    });
    final awardValues = {
      'orderId': orderId,
      'customerId': customerId,
      'amount': amount,
      'basePoints': (amount / rate).floor(),
      'multiplier': multiplier,
      'points': points,
      'threshold': monthlyThreshold,
      'settingsVersion':
          int.tryParse(tierSettings['settings_version']?.toString() ?? '0') ??
              0,
      'source': source,
      'cycleNumber': cycleNumber,
      'eventId': paymentEvent.lastInsertID.toInt(),
      'ledgerId': ledger.lastInsertID.toInt(),
    };
    if (existing.isEmpty) {
      await _db.execute('''
        INSERT INTO loyalty_order_award
          (order_id, customer_id, paid_at, qualifying_month, base_amount,
           base_points, multiplier, bonus_points, awarded_points,
           monthly_threshold, settings_version, point_ledger_id, source,
           cycle_number, current_payment_event_id)
        VALUES (:orderId, :customerId, NOW(), DATE_FORMAT(NOW(), '%Y-%m-01'),
                :amount, :basePoints, :multiplier, 0, :points, :threshold,
                :settingsVersion, :ledgerId, :source, :cycleNumber, :eventId)
      ''', awardValues);
    } else {
      final updated = await _db.execute('''
        UPDATE loyalty_order_award
        SET customer_id = :customerId, paid_at = NOW(),
            qualifying_month = DATE_FORMAT(NOW(), '%Y-%m-01'),
            base_amount = :amount, base_points = :basePoints,
            multiplier = :multiplier, bonus_points = 0,
            awarded_points = :points, monthly_threshold = :threshold,
            settings_version = :settingsVersion, point_ledger_id = :ledgerId,
            source = :source, cycle_number = :cycleNumber,
            current_payment_event_id = :eventId, reversed_at = NULL,
            reversal_reason = NULL
        WHERE order_id = :orderId AND reversed_at IS NOT NULL
      ''', awardValues);
      if (updated.affectedRows != BigInt.one) {
        throw StateError('Loyalty award changed during re-award');
      }
    }
    await _db.execute('''
      UPDATE customer SET
        totalSpending = COALESCE(totalSpending, 0) + :amount,
        currentPoints = (
          SELECT COALESCE(SUM(points_earned - points_used), 0)
          FROM point_ledger WHERE customer_id = :customerId
            AND (expires_at IS NULL OR expires_at > NOW())
        )
      WHERE id = :customerId
    ''', {'amount': amount, 'customerId': customerId});
    return points;
  }

  Future<int> reverseAwardWithinTransaction({
    required int orderId,
    required String reason,
    required String source,
  }) async {
    final cleanReason = reason.trim();
    final cleanSource = source.trim();
    if (orderId <= 0 || cleanReason.isEmpty || cleanReason.length > 255) {
      throw const LoyaltyReversalException(
        'INVALID_REVERSAL',
        'A valid order and reason are required',
      );
    }
    if (cleanSource.isEmpty || cleanSource.length > 30) {
      throw const LoyaltyReversalException(
        'INVALID_SOURCE',
        'A valid reversal source is required',
      );
    }

    final orders = await _db.query('''
      SELECT id, customerId FROM `order`
      WHERE id = :orderId LIMIT 1 FOR UPDATE
    ''', {'orderId': orderId});
    if (orders.isEmpty) {
      throw const LoyaltyReversalException(
        'ORDER_NOT_FOUND',
        'Order not found',
      );
    }
    final customerId = int.tryParse(
          orders.first['customerId']?.toString() ?? '',
        ) ??
        0;
    if (customerId <= 0) return 0;
    final customers = await _db.query('''
      SELECT id, COALESCE(totalSpending, 0) AS totalSpending
      FROM customer WHERE id = :customerId LIMIT 1 FOR UPDATE
    ''', {'customerId': customerId});
    if (customers.isEmpty) {
      throw const LoyaltyReversalException(
        'CUSTOMER_NOT_FOUND',
        'Customer not found',
      );
    }
    final awards = await _db.query('''
      SELECT id, order_id, customer_id, paid_at, qualifying_month,
             base_amount, base_points, multiplier, bonus_points,
             awarded_points, monthly_threshold, settings_version,
             point_ledger_id, source, reversed_at, cycle_number,
             current_payment_event_id
      FROM loyalty_order_award
      WHERE order_id = :orderId LIMIT 1 FOR UPDATE
    ''', {'orderId': orderId});
    if (awards.isEmpty) {
      return 0;
    }
    final award = awards.first;
    final awardedPoints = int.tryParse(
          award['awarded_points']?.toString() ?? '',
        ) ??
        0;
    if (award['reversed_at'] != null) return awardedPoints;
    final awardCustomerId = int.tryParse(
          award['customer_id']?.toString() ?? '',
        ) ??
        0;
    final ledgerId = int.tryParse(
          award['point_ledger_id']?.toString() ?? '',
        ) ??
        0;
    if (awardCustomerId != customerId || ledgerId <= 0) {
      throw const LoyaltyReversalException(
        'AWARD_LINK_MISMATCH',
        'Loyalty award linkage is invalid',
      );
    }
    final lots = await _db.query('''
      SELECT id, customer_id, order_id, points_earned, points_used
      FROM point_ledger WHERE id = :ledgerId LIMIT 1 FOR UPDATE
    ''', {'ledgerId': ledgerId});
    if (lots.isEmpty) {
      throw const LoyaltyReversalException(
        'AWARD_LINK_MISMATCH',
        'Loyalty point lot is missing',
      );
    }
    final lot = lots.first;
    final pointsEarned = int.tryParse(
          lot['points_earned']?.toString() ?? '',
        ) ??
        -1;
    final pointsUsed = int.tryParse(lot['points_used']?.toString() ?? '') ?? -1;
    if (pointsUsed > 0) {
      throw LoyaltyReversalException(
        'AWARD_POINTS_ALREADY_USED',
        'ย้อนแต้มของบิล #$orderId ไม่ได้: บิลนี้ได้รับ $awardedPoints แต้ม '
            'และถูกใช้ไปแล้ว $pointsUsed แต้ม กรุณายกเลิกหรือคืนรายการใช้แต้มก่อน',
      );
    }
    if (int.tryParse(lot['customer_id']?.toString() ?? '') != customerId ||
        int.tryParse(lot['order_id']?.toString() ?? '') != orderId ||
        !LoyaltyAwardRules.isExactUnusedAwardLot(
          pointsEarned: pointsEarned,
          pointsUsed: pointsUsed,
          awardedPoints: awardedPoints,
        )) {
      throw const LoyaltyReversalException(
        'AWARD_LINK_MISMATCH',
        'Loyalty point lot does not match the award',
      );
    }
    final baseAmount = double.tryParse(
          award['base_amount']?.toString() ?? '',
        ) ??
        -1;
    final totalSpending = double.tryParse(
          customers.first['totalSpending']?.toString() ?? '',
        ) ??
        -1;
    if (baseAmount < 0 || totalSpending + 0.01 < baseAmount) {
      throw const LoyaltyReversalException(
        'SPENDING_BALANCE_MISMATCH',
        'Customer spending balance cannot be reversed safely',
      );
    }
    final cycleNumber = int.tryParse(
          award['cycle_number']?.toString() ?? '',
        ) ??
        1;
    final reversalEvent = await _db.execute('''
      INSERT INTO loyalty_payment_event
        (idempotency_key, customer_id, order_id, amount, paid_at, source)
      VALUES (:key, :customerId, :orderId, :amount, NOW(), :source)
    ''', {
      'key': 'REVERSE:$orderId:CYCLE:$cycleNumber',
      'customerId': customerId,
      'orderId': orderId,
      'amount': -baseAmount,
      'source': cleanSource,
    });
    final reversalEventId = reversalEvent.lastInsertID.toInt();
    final neutralized = await _db.execute('''
      UPDATE point_ledger SET points_used = points_earned
      WHERE id = :ledgerId AND customer_id = :customerId
        AND order_id = :orderId AND points_earned = :points
        AND points_used = 0
    ''', {
      'ledgerId': ledgerId,
      'customerId': customerId,
      'orderId': orderId,
      'points': awardedPoints,
    });
    if (neutralized.affectedRows != BigInt.one) {
      throw const LoyaltyReversalException(
        'AWARD_POINTS_CHANGED',
        'Awarded point lot changed; retry the reversal',
      );
    }
    await _db.execute('''
      INSERT INTO loyalty_award_cycle_history
        (order_id, award_id, cycle_number, customer_id, payment_event_id,
         reversal_event_id, point_ledger_id, paid_at, reversed_at,
         qualifying_month, base_amount, base_points, multiplier, bonus_points,
         awarded_points, monthly_threshold, settings_version, award_source,
         reversal_source, reversal_reason)
      VALUES (:orderId, :awardId, :cycleNumber, :customerId, :paymentEventId,
              :reversalEventId, :ledgerId, :paidAt, NOW(), :qualifyingMonth,
              :baseAmount, :basePoints, :multiplier, :bonusPoints,
              :awardedPoints, :monthlyThreshold, :settingsVersion,
              :awardSource, :reversalSource, :reason)
    ''', {
      'orderId': orderId,
      'awardId': award['id'],
      'cycleNumber': cycleNumber,
      'customerId': customerId,
      'paymentEventId': award['current_payment_event_id'],
      'reversalEventId': reversalEventId,
      'ledgerId': ledgerId,
      'paidAt': award['paid_at'],
      'qualifyingMonth': award['qualifying_month'],
      'baseAmount': baseAmount,
      'basePoints': award['base_points'],
      'multiplier': award['multiplier'],
      'bonusPoints': award['bonus_points'],
      'awardedPoints': awardedPoints,
      'monthlyThreshold': award['monthly_threshold'],
      'settingsVersion': award['settings_version'],
      'awardSource': award['source'],
      'reversalSource': cleanSource,
      'reason': cleanReason,
    });
    final awardReversed = await _db.execute('''
      UPDATE loyalty_order_award
      SET reversed_at = NOW(), reversal_reason = :reason
      WHERE id = :awardId AND reversed_at IS NULL
    ''', {'awardId': award['id'], 'reason': cleanReason});
    if (awardReversed.affectedRows != BigInt.one) {
      throw const LoyaltyReversalException(
        'AWARD_CHANGED',
        'Loyalty award changed; retry the reversal',
      );
    }
    await _db.execute(
      'UPDATE `order` SET loyaltyPaidAt = NULL WHERE id = :orderId',
      {'orderId': orderId},
    );
    final paymentEventId = int.tryParse(
      award['current_payment_event_id']?.toString() ?? '',
    );
    if (paymentEventId != null) {
      await _db.execute('''
        UPDATE loyalty_payment_event SET reversed_event_id = :reversalEventId
        WHERE id = :paymentEventId AND reversed_event_id IS NULL
      ''', {
        'reversalEventId': reversalEventId,
        'paymentEventId': paymentEventId,
      });
    }
    await _db.execute('''
      UPDATE customer SET
        totalSpending = COALESCE(totalSpending, 0) - :amount,
        currentPoints = (
          SELECT COALESCE(SUM(points_earned - points_used), 0)
          FROM point_ledger WHERE customer_id = :customerId
            AND (expires_at IS NULL OR expires_at > NOW())
        )
      WHERE id = :customerId
    ''', {'amount': baseAmount, 'customerId': customerId});
    return awardedPoints;
  }
}
