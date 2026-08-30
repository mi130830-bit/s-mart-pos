import 'dart:math';

import 'package:mysql_client_plus/exception.dart';

import '../db_config.dart';

class RewardRedemptionException implements Exception {
  const RewardRedemptionException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;
}

class RewardRedemptionRules {
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static const _couponChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String validateClientRequestId(String input) {
    final value = input.trim().toLowerCase();
    if (!_uuid.hasMatch(value)) {
      throw const RewardRedemptionException(
        400,
        'INVALID_CLIENT_REQUEST_ID',
        'A valid clientRequestId UUID is required',
      );
    }
    return value;
  }

  static String createCouponCode({Random? random}) {
    final source = random ?? Random.secure();
    String part() => List.generate(
      6,
      (_) => _couponChars[source.nextInt(_couponChars.length)],
    ).join();
    return 'SMR-${part()}-${part()}';
  }

  static bool isDuplicateKeyError(Object error) =>
      error is MySQLServerException && error.errorCode == 1062;

  static bool replayMatches(
    Map<String, String?> row, {
    required int customerId,
    required int rewardId,
  }) =>
      row['customer_id'] == customerId.toString() &&
      row['reward_id'] == rewardId.toString();

  static List<int> allocateLotUsage(
    List<int> availableByExpiry,
    int requested,
  ) {
    if (requested < 0) {
      throw const RewardRedemptionException(
        409,
        'INSUFFICIENT_POINTS',
        'Insufficient points',
      );
    }
    var remaining = requested;
    final usage = <int>[];
    for (final rawAvailable in availableByExpiry) {
      final available = rawAvailable < 0 ? 0 : rawAvailable;
      final used = available < remaining ? available : remaining;
      usage.add(used);
      remaining -= used;
    }
    if (remaining != 0) {
      throw const RewardRedemptionException(
        409,
        'INSUFFICIENT_POINTS',
        'Insufficient points',
      );
    }
    return usage;
  }
}

class RewardRedemptionService {
  Future<Map<String, dynamic>> redeem({
    required String lineSubject,
    required int rewardId,
    required String clientRequestId,
  }) async {
    if (rewardId <= 0) {
      throw const RewardRedemptionException(
        400,
        'INVALID_REWARD',
        'Invalid reward',
      );
    }
    final requestId = RewardRedemptionRules.validateClientRequestId(
      clientRequestId,
    );
    final conn = await DbConfig().connection;
    int? customerId;
    await conn.execute('START TRANSACTION');
    try {
      final owner = await conn.execute(
        '''SELECT o.customer_id
           FROM customer_identity_owner o
           JOIN customer c ON c.id = o.customer_id
           WHERE o.provider = 'LINE' AND o.subject = :subject
             AND (c.isDeleted = 0 OR c.isDeleted IS NULL)
           LIMIT 1 FOR UPDATE''',
        {'subject': lineSubject},
      );
      if (owner.rows.isEmpty) {
        throw const RewardRedemptionException(
          404,
          'MEMBER_NOT_FOUND',
          'Member not found',
        );
      }
      customerId = int.parse(
        owner.rows.first.assoc()['customer_id'].toString(),
      );

      final replay = await _findReplay(conn, requestId, forUpdate: true);
      if (replay != null) {
        if (!RewardRedemptionRules.replayMatches(
          replay,
          customerId: customerId,
          rewardId: rewardId,
        )) {
          throw const RewardRedemptionException(
            409,
            'IDEMPOTENCY_CONFLICT',
            'clientRequestId was already used',
          );
        }
        final response = await _replayResponse(conn, replay);
        await conn.execute('COMMIT');
        return response;
      }

      final customer = await conn.execute(
        '''SELECT id FROM customer WHERE id = :id
           AND (isDeleted = 0 OR isDeleted IS NULL)
           LIMIT 1 FOR UPDATE''',
        {'id': customerId},
      );
      if (customer.rows.isEmpty) {
        throw const RewardRedemptionException(
          404,
          'MEMBER_NOT_FOUND',
          'Member not found',
        );
      }
      final pointLots = await conn.execute(
        '''SELECT id, points_earned - points_used AS available
           FROM point_ledger
           WHERE customer_id = :customerId
             AND points_earned > points_used
             AND (expires_at IS NULL OR expires_at > NOW())
           ORDER BY (expires_at IS NULL), expires_at, earned_at, id
           FOR UPDATE''',
        {'customerId': customerId},
      );
      final lotRows = pointLots.rows.map((lot) => lot.assoc()).toList();
      final lotAvailability = lotRows
          .map((lot) => int.tryParse(lot['available']?.toString() ?? '0') ?? 0)
          .toList();
      // Legacy reward redemptions may still exist as permanent debit rows.
      // Include them in the effective balance while all new debits consume
      // the locked positive lots above.
      final activeBalance = await conn.execute(
        '''SELECT COALESCE(SUM(points_earned - points_used), 0) AS points
           FROM point_ledger
           WHERE customer_id = :customerId
             AND (expires_at IS NULL OR expires_at > NOW())''',
        {'customerId': customerId},
      );
      final currentPoints =
          int.tryParse(
            activeBalance.rows.first.assoc()['points']?.toString() ?? '0',
          ) ??
          0;

      final rewardResult = await conn.execute(
        '''SELECT id, point_price, stock_quantity, name,
                  COALESCE(reward_type, 'GIFT') AS reward_type,
                  COALESCE(discount_value, 0) AS discount_value,
                  COALESCE(coupon_expiry_days, 30) AS coupon_expiry_days,
                  COALESCE(claim_limit_per_user, 0) AS claim_limit_per_user
           FROM point_reward
           WHERE id = :rewardId AND is_active = 1
           LIMIT 1 FOR UPDATE''',
        {'rewardId': rewardId},
      );
      if (rewardResult.rows.isEmpty) {
        throw const RewardRedemptionException(
          404,
          'REWARD_NOT_FOUND',
          'Reward not found',
        );
      }
      final reward = rewardResult.rows.first.assoc();
      final pointPrice = int.parse(reward['point_price']!);
      final stock = int.parse(reward['stock_quantity']!);
      if (pointPrice < 0 || currentPoints < pointPrice) {
        throw const RewardRedemptionException(
          409,
          'INSUFFICIENT_POINTS',
          'Insufficient points',
        );
      }
      if (stock <= 0) {
        throw const RewardRedemptionException(
          409,
          'OUT_OF_STOCK',
          'Reward is out of stock',
        );
      }

      final limitPerUser =
          int.tryParse(reward['claim_limit_per_user']?.toString() ?? '0') ?? 0;
      if (limitPerUser > 0) {
        final claimed = await conn.execute(
          '''SELECT COUNT(*) AS cnt FROM reward_redemption
             WHERE customer_id = :customerId AND reward_id = :rewardId''',
          {'customerId': customerId, 'rewardId': rewardId},
        );
        final claimedCount =
            int.tryParse(
              claimed.rows.first.assoc()['cnt']?.toString() ?? '0',
            ) ??
            0;
        if (claimedCount >= limitPerUser) {
          throw const RewardRedemptionException(
            409,
            'ALREADY_CLAIMED_MAX',
            'You have already reached the limit for this reward',
          );
        }
      }
      final lotUsage = RewardRedemptionRules.allocateLotUsage(
        lotAvailability,
        pointPrice,
      );
      for (var index = 0; index < lotRows.length; index++) {
        final used = lotUsage[index];
        if (used <= 0) continue;
        final updated = await conn.execute(
          '''UPDATE point_ledger
             SET points_used = points_used + :used
             WHERE id = :id AND customer_id = :customerId
               AND points_earned - points_used >= :used''',
          {'used': used, 'id': lotRows[index]['id'], 'customerId': customerId},
        );
        if (updated.affectedRows != BigInt.one) {
          throw const RewardRedemptionException(
            409,
            'POINT_BALANCE_CHANGED',
            'Point balance changed; please retry',
          );
        }
      }
      final remainingPoints = await _refreshCustomerPoints(conn, customerId);
      final stockUpdate = await conn.execute(
        '''UPDATE point_reward SET stock_quantity = stock_quantity - 1
           WHERE id = :id AND stock_quantity > 0''',
        {'id': rewardId},
      );
      if (stockUpdate.affectedRows != BigInt.one) {
        throw const RewardRedemptionException(
          409,
          'OUT_OF_STOCK',
          'Reward is out of stock',
        );
      }

      final rewardType = reward['reward_type'] ?? 'GIFT';
      final redemption = await conn.execute(
        '''INSERT INTO reward_redemption
           (customer_id, reward_id, points_used, status, reward_type,
            client_request_id)
           VALUES (:customerId, :rewardId, :points, 'PENDING', :rewardType,
                   :requestId)''',
        {
          'customerId': customerId,
          'rewardId': rewardId,
          'points': pointPrice,
          'rewardType': rewardType,
          'requestId': requestId,
        },
      );
      final redemptionId = redemption.lastInsertID.toInt();
      String? couponCode;
      final discountValue =
          double.tryParse(reward['discount_value'] ?? '0') ?? 0;
      if (rewardType == 'COUPON' && discountValue > 0) {
        final expiryDays =
            int.tryParse(reward['coupon_expiry_days'] ?? '30') ?? 30;
        couponCode = await _insertCouponWithRetry(
          conn,
          customerId: customerId,
          rewardId: rewardId,
          redemptionId: redemptionId,
          discountValue: discountValue,
          expiryDays: expiryDays.clamp(1, 3650),
        );
      }

      await conn.execute('COMMIT');
      return {
        'success': true,
        'redemptionId': redemptionId,
        'remainingPoints': remainingPoints,
        'rewardType': rewardType,
        'couponCode': couponCode,
        'discountValue': discountValue,
        'idempotentReplay': false,
      };
    } catch (error) {
      await conn.execute('ROLLBACK');
      if (RewardRedemptionRules.isDuplicateKeyError(error) &&
          customerId != null) {
        final winner = await _findReplay(conn, requestId, forUpdate: false);
        if (winner != null) {
          if (!RewardRedemptionRules.replayMatches(
            winner,
            customerId: customerId,
            rewardId: rewardId,
          )) {
            throw const RewardRedemptionException(
              409,
              'IDEMPOTENCY_CONFLICT',
              'clientRequestId was already used',
            );
          }
          return _replayResponse(conn, winner);
        }
      }
      rethrow;
    }
  }

  Future<Map<String, String?>?> _findReplay(
    dynamic conn,
    String requestId, {
    required bool forUpdate,
  }) async {
    final result = await conn.execute(
      '''SELECT rr.id, rr.customer_id, rr.reward_id, rr.reward_type,
                rc.coupon_code, rc.discount_value
         FROM reward_redemption rr
         LEFT JOIN reward_coupon rc ON rc.redemption_id = rr.id
         WHERE rr.client_request_id = :requestId
         LIMIT 1${forUpdate ? ' FOR UPDATE' : ''}''',
      {'requestId': requestId},
    );
    return result.rows.isEmpty ? null : result.rows.first.assoc();
  }

  Future<Map<String, dynamic>> _replayResponse(
    dynamic conn,
    Map<String, String?> replay,
  ) async {
    final points = await conn.execute(
      '''SELECT COALESCE(SUM(points_earned - points_used), 0) AS points
         FROM point_ledger
         WHERE customer_id = :customerId
           AND (expires_at IS NULL OR expires_at > NOW())''',
      {'customerId': replay['customer_id']},
    );
    return {
      'success': true,
      'redemptionId': int.parse(replay['id']!),
      'remainingPoints':
          int.tryParse(
            points.rows.first.assoc()['points']?.toString() ?? '0',
          ) ??
          0,
      'rewardType': replay['reward_type'] ?? 'GIFT',
      'couponCode': replay['coupon_code'],
      'discountValue':
          double.tryParse(replay['discount_value']?.toString() ?? '0') ?? 0,
      'idempotentReplay': true,
    };
  }

  Future<int> _refreshCustomerPoints(dynamic conn, int customerId) async {
    final result = await conn.execute(
      '''SELECT COALESCE(SUM(points_earned - points_used), 0) AS points
         FROM point_ledger
         WHERE customer_id = :customerId
           AND (expires_at IS NULL OR expires_at > NOW())''',
      {'customerId': customerId},
    );
    final points =
        int.tryParse(result.rows.first.assoc()['points']?.toString() ?? '0') ??
        0;
    await conn.execute(
      'UPDATE customer SET currentPoints = :points WHERE id = :customerId',
      {'points': points, 'customerId': customerId},
    );
    return points;
  }

  Future<String> _insertCouponWithRetry(
    dynamic conn, {
    required int customerId,
    required int rewardId,
    required int redemptionId,
    required double discountValue,
    required int expiryDays,
    String prefix = 'SMR',
  }) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = _buildCouponCode(prefix);
      try {
        await conn.execute(
          '''INSERT INTO reward_coupon
             (coupon_code, customer_id, reward_id, redemption_id,
              discount_value, expires_at, status)
             VALUES (:code, :customerId, :rewardId, :redemptionId,
                     :discount, DATE_ADD(NOW(), INTERVAL $expiryDays DAY),
                     'ACTIVE')''',
          {
            'code': code,
            'customerId': customerId,
            'rewardId': rewardId,
            'redemptionId': redemptionId,
            'discount': discountValue,
          },
        );
        return code;
      } catch (error) {
        if (!RewardRedemptionRules.isDuplicateKeyError(error)) rethrow;
      }
    }
    throw const RewardRedemptionException(
      503,
      'COUPON_CODE_UNAVAILABLE',
      'Unable to issue coupon',
    );
  }

  String _buildCouponCode(String prefix) =>
      '$prefix-${RewardRedemptionRules.createCouponCode().substring(4)}';

  // ---------------------------------------------------------------------------
  // FREE CLAIM — ลูกค้ากดรับคูปองฟรีโดยไม่ต้องใช้แต้ม
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> claimFreeCoupon({
    required String lineSubject,
    required int rewardId,
    required String clientRequestId,
  }) async {
    if (rewardId <= 0) {
      throw const RewardRedemptionException(400, 'INVALID_REWARD', 'Invalid reward');
    }
    final requestId = RewardRedemptionRules.validateClientRequestId(clientRequestId);
    final conn = await DbConfig().connection;
    int? customerId;
    await conn.execute('START TRANSACTION');
    try {
      // 1. ยืนยัน identity
      final owner = await conn.execute(
        '''SELECT o.customer_id
           FROM customer_identity_owner o
           JOIN customer c ON c.id = o.customer_id
           WHERE o.provider = 'LINE' AND o.subject = :subject
             AND (c.isDeleted = 0 OR c.isDeleted IS NULL)
           LIMIT 1 FOR UPDATE''',
        {'subject': lineSubject},
      );
      if (owner.rows.isEmpty) {
        throw const RewardRedemptionException(404, 'MEMBER_NOT_FOUND', 'Member not found');
      }
      customerId = int.parse(owner.rows.first.assoc()['customer_id'].toString());

      // 2. Idempotency check
      final replay = await _findReplay(conn, requestId, forUpdate: true);
      if (replay != null) {
        if (!RewardRedemptionRules.replayMatches(replay, customerId: customerId, rewardId: rewardId)) {
          throw const RewardRedemptionException(409, 'IDEMPOTENCY_CONFLICT', 'clientRequestId was already used');
        }
        final response = await _replayResponse(conn, replay);
        await conn.execute('COMMIT');
        return {...response, 'idempotentReplay': true};
      }

      // 3. ดึงข้อมูล reward + lock
      final rewardResult = await conn.execute(
        '''SELECT id, name, stock_quantity, claim_type,
                  COALESCE(claim_limit_per_user, 1) AS claim_limit_per_user,
                  COALESCE(discount_value, 0) AS discount_value,
                  COALESCE(coupon_expiry_days, 30) AS coupon_expiry_days,
                  COALESCE(reward_type, 'COUPON') AS reward_type
           FROM point_reward
           WHERE id = :rewardId AND is_active = 1
           LIMIT 1 FOR UPDATE''',
        {'rewardId': rewardId},
      );
      if (rewardResult.rows.isEmpty) {
        throw const RewardRedemptionException(404, 'REWARD_NOT_FOUND', 'Reward not found');
      }
      final reward = rewardResult.rows.first.assoc();

      // 4. ตรวจว่าเป็น FREE_CLAIM จริง
      if ((reward['claim_type'] ?? 'POINTS_REDEEM') != 'FREE_CLAIM') {
        throw const RewardRedemptionException(400, 'NOT_FREE_CLAIM', 'This reward requires points to redeem');
      }

      // 5. ตรวจสต็อก
      final stock = int.parse(reward['stock_quantity']!);
      if (stock <= 0) {
        throw const RewardRedemptionException(409, 'OUT_OF_STOCK', 'Reward is out of stock');
      }

      // 6. ตรวจโควตาต่อคน
      final limitPerUser = int.tryParse(reward['claim_limit_per_user']?.toString() ?? '1') ?? 1;
      if (limitPerUser > 0) {
        final claimed = await conn.execute(
          '''SELECT COUNT(*) AS cnt FROM reward_coupon
             WHERE customer_id = :customerId AND reward_id = :rewardId''',
          {'customerId': customerId, 'rewardId': rewardId},
        );
        final claimedCount = int.tryParse(
          claimed.rows.first.assoc()['cnt']?.toString() ?? '0',
        ) ?? 0;
        if (claimedCount >= limitPerUser) {
          throw const RewardRedemptionException(
            409,
            'ALREADY_CLAIMED_MAX',
            'You have already claimed the maximum allowed coupons',
          );
        }
      }

      // 7. ลดสต็อก
      final stockUpdate = await conn.execute(
        'UPDATE point_reward SET stock_quantity = stock_quantity - 1 WHERE id = :id AND stock_quantity > 0',
        {'id': rewardId},
      );
      if (stockUpdate.affectedRows != BigInt.one) {
        throw const RewardRedemptionException(409, 'OUT_OF_STOCK', 'Reward is out of stock');
      }

      // 8. บันทึก redemption (points_used = 0)
      final rewardType = reward['reward_type'] ?? 'COUPON';
      final redemption = await conn.execute(
        '''INSERT INTO reward_redemption
           (customer_id, reward_id, points_used, status, reward_type, client_request_id)
           VALUES (:customerId, :rewardId, 0, 'PENDING', :rewardType, :requestId)''',
        {'customerId': customerId, 'rewardId': rewardId, 'rewardType': rewardType, 'requestId': requestId},
      );
      final redemptionId = redemption.lastInsertID.toInt();

      // 9. สร้างรหัสคูปอง (prefix FREE)
      final discountValue = double.tryParse(reward['discount_value'] ?? '0') ?? 0;
      final expiryDays = (int.tryParse(reward['coupon_expiry_days'] ?? '30') ?? 30).clamp(1, 3650);
      final couponCode = await _insertCouponWithRetry(
        conn,
        customerId: customerId,
        rewardId: rewardId,
        redemptionId: redemptionId,
        discountValue: discountValue,
        expiryDays: expiryDays,
        prefix: 'FREE',
      );

      await conn.execute('COMMIT');
      return {
        'success': true,
        'redemptionId': redemptionId,
        'couponCode': couponCode,
        'discountValue': discountValue,
        'rewardName': reward['name'] ?? '',
        'idempotentReplay': false,
      };
    } catch (error) {
      await conn.execute('ROLLBACK');
      if (RewardRedemptionRules.isDuplicateKeyError(error) && customerId != null) {
        final winner = await _findReplay(conn, requestId, forUpdate: false);
        if (winner != null) {
          if (!RewardRedemptionRules.replayMatches(winner, customerId: customerId, rewardId: rewardId)) {
            throw const RewardRedemptionException(409, 'IDEMPOTENCY_CONFLICT', 'clientRequestId was already used');
          }
          return {...await _replayResponse(conn, winner), 'idempotentReplay': true};
        }
      }
      rethrow;
    }
  }
}
