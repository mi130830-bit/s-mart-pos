import 'dart:convert';
import 'dart:math' as math;

import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../db_config.dart';

class MemberTierValidationException implements Exception {
  const MemberTierValidationException(this.code, this.message);

  final String code;
  final String message;
}

class TierSettingsConflictException implements Exception {
  const TierSettingsConflictException();
}

class BangkokMonthRange {
  const BangkokMonthRange({
    required this.startUtc,
    required this.endUtc,
    required this.startDatabase,
    required this.endDatabase,
  });

  final DateTime startUtc;
  final DateTime endUtc;
  final String startDatabase;
  final String endDatabase;
}

class TierEntitlement {
  const TierEntitlement({
    required this.isRegularCustomer,
    required this.pointsMultiplier,
    required this.progress,
    this.loyaltyLevel = 'CUSTOMER',
    this.nextThreshold,
  });

  final bool isRegularCustomer;
  final double pointsMultiplier;
  final double progress;
  final String loyaltyLevel;
  final double? nextThreshold;
}

class TierSettingsUpdate {
  const TierSettingsUpdate({
    required this.enabled,
    required this.monthlyThreshold,
    required this.pointsMultiplier,
    required this.contractorThreshold1,
    required this.contractorMultiplier1,
    required this.contractorThreshold2,
    required this.contractorMultiplier2,
    required this.benefitTextTh,
    required this.benefitTextEn,
    required this.settingsVersion,
  });

  final bool enabled;
  final double monthlyThreshold;
  final double pointsMultiplier;
  final double contractorThreshold1;
  final double contractorMultiplier1;
  final double contractorThreshold2;
  final double contractorMultiplier2;
  final String benefitTextTh;
  final String benefitTextEn;
  final int settingsVersion;
}

class MemberTierRules {
  static const _bangkokOffset = Duration(hours: 7);
  static const memberOrderStatuses = {
    'ALL',
    'PENDING',
    'CONFIRMED',
    'PREPARING',
    'READY',
    'SHIPPING',
    'DISPATCHED',
    'PAID',
    'COMPLETED',
    'CANCELLED',
    'REJECTED',
  };

  static BangkokMonthRange bangkokMonthRange(DateTime instant) {
    final bangkokWallClock = instant.toUtc().add(_bangkokOffset);
    final startWallClock = DateTime.utc(
      bangkokWallClock.year,
      bangkokWallClock.month,
    );
    final endWallClock = DateTime.utc(
      bangkokWallClock.month == 12
          ? bangkokWallClock.year + 1
          : bangkokWallClock.year,
      bangkokWallClock.month == 12 ? 1 : bangkokWallClock.month + 1,
    );
    return BangkokMonthRange(
      startUtc: startWallClock.subtract(_bangkokOffset),
      endUtc: endWallClock.subtract(_bangkokOffset),
      startDatabase: _databaseDateTime(startWallClock),
      endDatabase: _databaseDateTime(endWallClock),
    );
  }

  static String effectiveDatabaseSpendStart({
    required String monthStart,
    String? programStartedAt,
  }) {
    final month = DateTime.tryParse(monthStart);
    final program = DateTime.tryParse(programStartedAt?.trim() ?? '');
    if (month == null || program == null || !program.isAfter(month)) {
      return monthStart;
    }
    return programStartedAt!.trim();
  }

  static TierEntitlement deriveEntitlement({
    required double monthlySpend,
    required double threshold,
    required bool enabled,
    required double permanentMultiplier,
    required double monthlyMultiplier,
    bool isContractor = false,
    double contractorThreshold1 = 20000,
    double contractorMultiplier1 = 2.5,
    double contractorThreshold2 = 50000,
    double contractorMultiplier2 = 3,
  }) {
    final safeSpend = math.max(0.0, monthlySpend);
    final safeThreshold = math.max(0.0, threshold);
    final safePermanentMultiplier = math.max(1.0, permanentMultiplier);
    final safeMonthlyMultiplier = math.max(1.0, monthlyMultiplier);
    if (isContractor && enabled) {
      final firstThreshold = math.max(0.0, contractorThreshold1);
      final secondThreshold = math.max(firstThreshold, contractorThreshold2);
      var monthlyBonus = math.max(1.0, safeMonthlyMultiplier);
      var level = 'CONTRACTOR';
      double? nextThreshold = firstThreshold;
      if (safeSpend > secondThreshold) {
        monthlyBonus = math.max(1.0, contractorMultiplier2);
        level = 'CONTRACTOR_PLUS';
        nextThreshold = null;
      } else if (safeSpend > firstThreshold) {
        monthlyBonus = math.max(1.0, contractorMultiplier1);
        level = 'CONTRACTOR_PRO';
        nextThreshold = secondThreshold;
      }
      final target = nextThreshold ?? secondThreshold;
      final progress = target <= 0
          ? 1.0
          : (safeSpend / target).clamp(0.0, 1.0).toDouble();
      return TierEntitlement(
        isRegularCustomer: true,
        pointsMultiplier: math.max(safePermanentMultiplier, monthlyBonus),
        progress: progress,
        loyaltyLevel: level,
        nextThreshold: nextThreshold,
      );
    }
    final isRegular = enabled && safeSpend >= safeThreshold;
    final progress = safeThreshold == 0
        ? (enabled ? 1.0 : 0.0)
        : (safeSpend / safeThreshold).clamp(0.0, 1.0).toDouble();
    return TierEntitlement(
      isRegularCustomer: isRegular,
      pointsMultiplier: isRegular
          ? math.max(safePermanentMultiplier, safeMonthlyMultiplier)
          : safePermanentMultiplier,
      progress: progress,
      loyaltyLevel: isRegular ? 'CUSTOMER_REGULAR' : 'CUSTOMER',
      nextThreshold: isRegular ? null : safeThreshold,
    );
  }

  static TierSettingsUpdate validateSettingsUpdate(Map<String, dynamic> body) {
    final enabled = body['enabled'];
    final threshold = _finiteDouble(body['monthlyThreshold']);
    final multiplier = _finiteDouble(body['pointsMultiplier']);
    final contractorThreshold1 = _finiteDouble(
      body['contractorThreshold1'] ?? 20000,
    );
    final contractorMultiplier1 = _finiteDouble(
      body['contractorMultiplier1'] ?? 2.5,
    );
    final contractorThreshold2 = _finiteDouble(
      body['contractorThreshold2'] ?? 50000,
    );
    final contractorMultiplier2 = _finiteDouble(
      body['contractorMultiplier2'] ?? 3,
    );
    final textTh = body['benefitTextTh'];
    final textEn = body['benefitTextEn'];
    final version = _wholeInt(body['settingsVersion']);

    if (enabled is! bool ||
        threshold == null ||
        threshold < 0 ||
        threshold > 1000000000 ||
        multiplier == null ||
        multiplier < 1 ||
        multiplier > 10 ||
        contractorThreshold1 == null ||
        contractorThreshold1 < 0 ||
        contractorThreshold2 == null ||
        contractorThreshold2 <= contractorThreshold1 ||
        contractorMultiplier1 == null ||
        contractorMultiplier1 < 1 ||
        contractorMultiplier1 > 10 ||
        contractorMultiplier2 == null ||
        contractorMultiplier2 < contractorMultiplier1 ||
        contractorMultiplier2 > 10 ||
        textTh is! String ||
        textTh.trim().isEmpty ||
        textTh.trim().length > 255 ||
        textEn is! String ||
        textEn.trim().isEmpty ||
        textEn.trim().length > 255 ||
        version == null ||
        version < 1) {
      throw const MemberTierValidationException(
        'INVALID_TIER_SETTINGS',
        'Invalid tier settings',
      );
    }

    return TierSettingsUpdate(
      enabled: enabled,
      monthlyThreshold: threshold,
      pointsMultiplier: multiplier,
      contractorThreshold1: contractorThreshold1,
      contractorMultiplier1: contractorMultiplier1,
      contractorThreshold2: contractorThreshold2,
      contractorMultiplier2: contractorMultiplier2,
      benefitTextTh: textTh.trim(),
      benefitTextEn: textEn.trim(),
      settingsVersion: version,
    );
  }

  static int memberOrderLimit(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 20;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1) {
      throw const MemberTierValidationException(
        'INVALID_ORDER_FILTER',
        'Invalid order filter',
      );
    }
    return parsed.clamp(1, 100).toInt();
  }

  static String memberOrderStatus(String? raw) {
    final status = raw?.trim().toUpperCase() ?? 'ALL';
    if (!memberOrderStatuses.contains(status)) {
      throw const MemberTierValidationException(
        'INVALID_ORDER_FILTER',
        'Invalid order filter',
      );
    }
    return status;
  }

  static double? _finiteDouble(dynamic value) {
    if (value is! num) return null;
    final parsed = value.toDouble();
    return parsed.isFinite ? parsed : null;
  }

  static int? _wholeInt(dynamic value) {
    if (value is! num || !value.toDouble().isFinite) return null;
    final parsed = value.toInt();
    return value.toDouble() == parsed.toDouble() ? parsed : null;
  }

  static String _databaseDateTime(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class MemberTierService {
  Future<int?> resolveCustomerId(
    MySQLConnection conn,
    String lineSubject,
  ) async {
    final canonical = await conn.execute(
      '''SELECT customer_id FROM customer_identity_owner
         WHERE provider = 'LINE' AND subject = :subject LIMIT 1''',
      {'subject': lineSubject},
    );
    if (canonical.rows.isNotEmpty) {
      return int.tryParse(
        canonical.rows.first.assoc()['customer_id']?.toString() ?? '',
      );
    }

    // Legacy fallback is safe only when one active customer owns the subject.
    final legacy = await conn.execute(
      '''SELECT id FROM customer
         WHERE TRIM(line_user_id) = :subject
           AND (isDeleted = 0 OR isDeleted IS NULL)
         ORDER BY id ASC LIMIT 2''',
      {'subject': lineSubject},
    );
    if (legacy.rows.length != 1) return null;
    return int.tryParse(legacy.rows.first.assoc()['id']?.toString() ?? '');
  }

  Future<Map<String, dynamic>?> memberProfile(
    String lineSubject, {
    DateTime? now,
  }) async {
    final conn = await DbConfig().connection;
    final customerId = await resolveCustomerId(conn, lineSubject);
    if (customerId == null) return null;
    return memberProfileByCustomerId(customerId, now: now, connection: conn);
  }

  Future<Map<String, dynamic>?> memberProfileByCustomerId(
    int customerId, {
    DateTime? now,
    MySQLConnection? connection,
  }) async {
    final conn = connection ?? await DbConfig().connection;

    final customer = await conn.execute(
      '''SELECT c.id, c.memberCode, c.firstName, c.lastName, c.phone,
                c.address, c.shippingAddress, c.line_display_name,
                c.line_picture_url, c.tierId,
                COALESCE(t.name, 'ทั่วไป') AS member_tier,
                COALESCE(t.pointsMultiplier, 1.0) AS permanent_multiplier,
                COALESCE(t.loyaltySegment, 'CUSTOMER') AS loyalty_segment
         FROM customer c
         LEFT JOIN member_tier t ON c.tierId = t.id
         WHERE c.id = :customerId
           AND (c.isDeleted = 0 OR c.isDeleted IS NULL)
         LIMIT 1''',
      {'customerId': customerId},
    );
    if (customer.rows.isEmpty) return null;

    final points = await conn.execute(
      '''SELECT COALESCE(SUM(points_earned - points_used), 0) AS points
         FROM point_ledger
         WHERE customer_id = :customerId
           AND (expires_at IS NULL OR expires_at > NOW())''',
      {'customerId': customerId},
    );
    final nextExpiry = await conn.execute(
      '''SELECT expires_at,
                SUM(points_earned - points_used) AS expiring_points
         FROM point_ledger
         WHERE customer_id = :customerId
           AND expires_at IS NOT NULL AND expires_at > NOW()
           AND points_earned > points_used
         GROUP BY expires_at
         HAVING expiring_points > 0
         ORDER BY expires_at ASC LIMIT 1''',
      {'customerId': customerId},
    );
    // Ops: paid timestamps are Bangkok business wall-clock (เวลาร้าน); deploy
    // the database/session timezone as +07:00 and do not reinterpret as UTC.
    final month = MemberTierRules.bangkokMonthRange(now ?? DateTime.now());
    final settings = await getSettings(connection: conn);
    final spendStart = MemberTierRules.effectiveDatabaseSpendStart(
      monthStart: month.startDatabase,
      programStartedAt: settings['programStartedAt'] as String?,
    );
    final spend = await conn.execute(
      '''SELECT COALESCE(SUM(grandTotal), 0) AS monthly_spend
         FROM `order`
         WHERE customerId = :customerId
           AND status IN ('PAID', 'COMPLETED')
           AND COALESCE(loyaltyPaidAt, createdAt) >= :spendStart
           AND COALESCE(loyaltyPaidAt, createdAt) < :monthEnd''',
      {
        'customerId': customerId,
        'spendStart': spendStart,
        'monthEnd': month.endDatabase,
      },
    );
    final row = customer.rows.first.assoc();
    final expiryRow = nextExpiry.rows.isEmpty
        ? null
        : nextExpiry.rows.first.assoc();
    final monthlySpend = _double(spend.rows.first.assoc()['monthly_spend']);
    final permanentMultiplier = _double(row['permanent_multiplier'], 1);
    final entitlement = MemberTierRules.deriveEntitlement(
      monthlySpend: monthlySpend,
      threshold: settings['monthlyThreshold'] as double,
      enabled: settings['enabled'] as bool,
      permanentMultiplier: permanentMultiplier,
      monthlyMultiplier: settings['pointsMultiplier'] as double,
      isContractor: row['loyalty_segment'] == 'CONTRACTOR',
      contractorThreshold1: settings['contractorThreshold1'] as double,
      contractorMultiplier1: settings['contractorMultiplier1'] as double,
      contractorThreshold2: settings['contractorThreshold2'] as double,
      contractorMultiplier2: settings['contractorMultiplier2'] as double,
    );
    final firstName = row['firstName'] ?? '';
    final lastName = row['lastName'] ?? '';
    var displayName = '$firstName $lastName'.trim();
    if (displayName.isEmpty) {
      displayName = row['line_display_name'] ?? 'ลูกค้าสมาชิก';
    }

    return {
      'id': row['id'],
      'memberCode': row['memberCode'] ?? '',
      'name': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'phone': row['phone'] ?? '',
      'address': row['address'] ?? '',
      'shippingAddress': row['shippingAddress'] ?? '',
      'gpsLocation': row['shippingAddress'] ?? '',
      'lineDisplayName': row['line_display_name'] ?? '',
      'linePictureUrl': row['line_picture_url'] ?? '',
      'points':
          int.tryParse(
            points.rows.first.assoc()['points']?.toString() ?? '0',
          ) ??
          0,
      'nextExpiringAt': expiryRow?['expires_at'],
      'nextExpiringPoints':
          double.tryParse(
            expiryRow?['expiring_points']?.toString() ?? '0',
          )?.toInt() ??
          0,
      'tierId': int.tryParse(row['tierId']?.toString() ?? ''),
      'memberTier': row['member_tier'] ?? 'ทั่วไป',
      'permanentTierMultiplier': permanentMultiplier,
      'monthlySpend': monthlySpend,
      'threshold': settings['monthlyThreshold'],
      'progress': entitlement.progress,
      'isRegularCustomer': entitlement.isRegularCustomer,
      'pointsMultiplier': entitlement.pointsMultiplier,
      'loyaltySegment': row['loyalty_segment'] ?? 'CUSTOMER',
      'loyaltyLevel': entitlement.loyaltyLevel,
      'nextThreshold': entitlement.nextThreshold,
      'benefitTextTh': settings['benefitTextTh'],
      'benefitTextEn': settings['benefitTextEn'],
      'timezone': settings['timezone'],
      'programStartedAt': settings['programStartedAt'],
    };
  }

  Future<List<Map<String, dynamic>>> memberOrders({
    required String lineSubject,
    required int limit,
    required String status,
  }) async {
    final conn = await DbConfig().connection;
    final customerId = await resolveCustomerId(conn, lineSubject);
    if (customerId == null) return const [];

    var sql = '''SELECT o.id, o.orderNumber, o.deliveryType, o.deliveryFee,
                        o.totalAmount, o.grandTotal, o.itemsJson, o.status,
                        o.couponCode, o.couponDiscount, o.couponReservedUntil,
                        CASE
                          WHEN o.couponCode IS NULL OR o.couponCode = '' THEN NULL
                          WHEN o.status IN ('CANCELLED', 'REJECTED') THEN 'RELEASED'
                          WHEN o.couponReservedUntil IS NULL THEN COALESCE(rc.status, 'UNKNOWN')
                          WHEN o.couponReservedUntil <= NOW() AND rc.status = 'RESERVED' THEN 'EXPIRED'
                          ELSE COALESCE(rc.status, 'RESERVED')
                        END AS coupon_reservation_status,
                        o.createdAt, o.updatedAt
                 FROM online_orders o
                 LEFT JOIN reward_coupon rc
                   ON rc.coupon_code = o.couponCode
                  AND rc.customer_id = o.customerId
                 WHERE o.customerId = :customerId''';
    final params = <String, dynamic>{'customerId': customerId, 'limit': limit};
    if (status != 'ALL') {
      sql += ' AND o.status = :status';
      params['status'] = status;
    }
    sql += ' ORDER BY o.id DESC LIMIT :limit';
    final result = await conn.execute(sql, params);

    return result.rows.map((resultRow) {
      final row = resultRow.assoc();
      dynamic items = const [];
      try {
        final parsed = jsonDecode(row['itemsJson'] ?? '[]');
        if (parsed is List) {
          items = parsed.whereType<Map>().map((item) {
            return {
              'productId': item['productId'],
              'name': item['name']?.toString() ?? '',
              'quantity': _double(item['quantity']),
              'price': _double(item['price']),
              'subtotal': _double(item['subtotal']),
            };
          }).toList();
        }
      } catch (_) {
        items = const [];
      }
      return <String, dynamic>{
        'id': row['id'],
        'orderNumber': row['orderNumber'] ?? '',
        'deliveryType': row['deliveryType'] ?? 'pickup',
        'deliveryFee': _double(row['deliveryFee']),
        'totalAmount': _double(row['totalAmount']),
        'grandTotal': _double(row['grandTotal']),
        'items': items,
        'status': row['status'] ?? 'PENDING',
        'couponReservation': (row['couponCode'] ?? '').isEmpty
            ? null
            : {
                'status': row['coupon_reservation_status'] ?? 'UNKNOWN',
                'discount': _double(row['couponDiscount']),
                'reservedUntil': row['couponReservedUntil'],
              },
        'createdAt': row['createdAt'] ?? '',
        'updatedAt': row['updatedAt'] ?? '',
      };
    }).toList();
  }

  Future<Map<String, dynamic>> getSettings({
    MySQLConnection? connection,
  }) async {
    final conn = connection ?? await DbConfig().connection;
    final result = await conn.execute(
      '''SELECT enabled, monthly_threshold, points_multiplier,
                contractor_threshold_1, contractor_multiplier_1,
                contractor_threshold_2, contractor_multiplier_2,
                benefit_text_th, benefit_text_en, timezone_name,
                settings_version, program_started_at, updated_at
         FROM loyalty_tier_settings WHERE id = 1 LIMIT 1''',
    );
    if (result.rows.isEmpty) {
      throw StateError('Tier settings are unavailable');
    }
    return _settingsMap(result.rows.first.assoc());
  }

  Future<Map<String, dynamic>> updateSettings({
    required TierSettingsUpdate update,
    required String actorId,
  }) async {
    final conn = await DbConfig().connection;
    final result = await conn.execute(
      '''UPDATE loyalty_tier_settings
         SET enabled = :enabled,
             monthly_threshold = :threshold,
             points_multiplier = :multiplier,
             contractor_threshold_1 = :contractorThreshold1,
             contractor_multiplier_1 = :contractorMultiplier1,
             contractor_threshold_2 = :contractorThreshold2,
             contractor_multiplier_2 = :contractorMultiplier2,
             benefit_text_th = :textTh,
             benefit_text_en = :textEn,
             settings_version = settings_version + 1,
             updated_by = :actor
         WHERE id = 1 AND settings_version = :version''',
      {
        'enabled': update.enabled ? 1 : 0,
        'threshold': update.monthlyThreshold,
        'multiplier': update.pointsMultiplier,
        'contractorThreshold1': update.contractorThreshold1,
        'contractorMultiplier1': update.contractorMultiplier1,
        'contractorThreshold2': update.contractorThreshold2,
        'contractorMultiplier2': update.contractorMultiplier2,
        'textTh': update.benefitTextTh,
        'textEn': update.benefitTextEn,
        'actor': actorId,
        'version': update.settingsVersion,
      },
    );
    if (result.affectedRows != BigInt.one) {
      throw const TierSettingsConflictException();
    }
    return getSettings(connection: conn);
  }

  static Map<String, dynamic> _settingsMap(Map<String, String?> row) => {
    'enabled': row['enabled'] == '1',
    'monthlyThreshold': _double(row['monthly_threshold']),
    'pointsMultiplier': _double(row['points_multiplier'], 1),
    'contractorThreshold1': _double(row['contractor_threshold_1'], 20000),
    'contractorMultiplier1': _double(row['contractor_multiplier_1'], 2.5),
    'contractorThreshold2': _double(row['contractor_threshold_2'], 50000),
    'contractorMultiplier2': _double(row['contractor_multiplier_2'], 3),
    'benefitTextTh': row['benefit_text_th'] ?? '',
    'benefitTextEn': row['benefit_text_en'] ?? '',
    'timezone': row['timezone_name'] ?? 'Asia/Bangkok',
    'programStartedAt': row['program_started_at'],
    'settingsVersion':
        int.tryParse(row['settings_version']?.toString() ?? '') ?? 1,
    'updatedAt': row['updated_at'] ?? '',
  };

  static double _double(dynamic value, [double fallback = 0]) =>
      double.tryParse(value?.toString() ?? '') ?? fallback;
}
