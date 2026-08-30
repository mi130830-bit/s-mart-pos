import 'dart:io';

import '../db_config.dart';

class DatabaseMigrationService {
  static const membershipVersion = '20260825_001_membership_identity';
  static const onlineOrderCouponVersion =
      '20260825_002_online_order_coupon_reservation';
  static const rewardIdempotencyVersion =
      '20260825_003_reward_redemption_idempotency';
  static const loyaltyAwardVersion = '20260825_004_loyalty_paid_order_award';
  static const contractorTierVersion = '20260825_005_contractor_monthly_tiers';
  static const contractorTierRevisionVersion =
      '20260825_006_contractor_next_bill_revision';
  static const loyaltyReversalCycleVersion =
      '20260825_007_loyalty_reversal_cycles';
  static const loyaltyProgramResetVersion =
      '20260825_008_loyalty_program_reset_audit';
  static const claimableCouponVersion = '20260829_010_claimable_coupon';
  static const customerPinCodeVersion = '20260829_011_customer_pin_code';


  Future<void> run() async {
    final conn = await DbConfig().connection;
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(100) PRIMARY KEY,
        applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await _apply(conn, membershipVersion, () => _membershipIdentity(conn));
    await _apply(
      conn,
      onlineOrderCouponVersion,
      () => _onlineOrderCouponReservation(conn),
    );
    await _apply(
      conn,
      rewardIdempotencyVersion,
      () => _rewardRedemptionIdempotency(conn),
    );
    await _apply(conn, loyaltyAwardVersion, () => _loyaltyPaidOrderAward(conn));
    await _apply(
      conn,
      contractorTierVersion,
      () => _contractorMonthlyTiers(conn),
    );
    await _apply(
      conn,
      contractorTierRevisionVersion,
      () => _contractorNextBillRevision(conn),
    );
    await _apply(
      conn,
      loyaltyReversalCycleVersion,
      () => _loyaltyReversalCycles(conn),
    );
    await _apply(
      conn,
      loyaltyProgramResetVersion,
      () => _loyaltyProgramResetAudit(conn),
    );
    await _apply(
      conn,
      claimableCouponVersion,
      () => _claimableCoupon(conn),
    );
    await _apply(
      conn,
      customerPinCodeVersion,
      () => _customerPinCode(conn),
    );
  }

  Future<void> _apply(
    dynamic conn,
    String version,
    Future<void> Function() migration,
  ) async {
    final applied = await conn.execute(
      'SELECT version FROM schema_migrations WHERE version = :version LIMIT 1',
      {'version': version},
    );
    if (applied.rows.isNotEmpty) return;
    await migration();
    await conn.execute(
      'INSERT INTO schema_migrations (version) VALUES (:version)',
      {'version': version},
    );
    stdout.writeln('✅ Applied database migration $version');
  }

  Future<void> _membershipIdentity(dynamic conn) async {
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS customer_identity_owner (
        provider VARCHAR(20) NOT NULL,
        subject VARCHAR(191) NOT NULL,
        customer_id INT NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (provider, subject),
        UNIQUE KEY uq_identity_owner_customer (provider, customer_id),
        KEY idx_identity_owner_customer (customer_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS customer_identity_link (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        provider VARCHAR(20) NOT NULL DEFAULT 'LINE',
        subject VARCHAR(191) NOT NULL,
        customer_id INT NOT NULL,
        status VARCHAR(20) NOT NULL,
        method VARCHAR(30) NOT NULL,
        linked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        revoked_at DATETIME NULL,
        actor_type VARCHAR(20) NOT NULL,
        actor_id VARCHAR(100) NULL,
        request_uuid VARCHAR(100) NULL,
        reason VARCHAR(255) NULL,
        UNIQUE KEY uq_identity_link_request (request_uuid),
        KEY idx_identity_link_subject (provider, subject, status),
        KEY idx_identity_link_customer (customer_id, status)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS customer_line_link_request (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        request_uuid VARCHAR(100) NOT NULL,
        normalized_phone VARCHAR(20) NULL,
        candidate_customer_id INT NULL,
        line_subject VARCHAR(191) NOT NULL,
        line_display_name VARCHAR(255) NULL,
        line_picture_url TEXT NULL,
        request_type VARCHAR(20) NOT NULL,
        token_hash CHAR(64) NULL,
        status VARCHAR(20) NOT NULL,
        expires_at DATETIME NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        decided_at DATETIME NULL,
        consumed_at DATETIME NULL,
        staff_actor_id VARCHAR(100) NULL,
        staff_actor_role VARCHAR(30) NULL,
        decision_reason VARCHAR(255) NULL,
        UNIQUE KEY uq_line_link_request_uuid (request_uuid),
        UNIQUE KEY uq_line_link_token_hash (token_hash),
        KEY idx_line_link_pending (status, created_at),
        KEY idx_line_link_phone (normalized_phone, status),
        KEY idx_line_link_customer (candidate_customer_id, status),
        KEY idx_line_link_subject (line_subject, status)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_tier_settings (
        id TINYINT PRIMARY KEY,
        enabled TINYINT(1) NOT NULL DEFAULT 1,
        monthly_threshold DECIMAL(14,2) NOT NULL DEFAULT 10000.00,
        points_multiplier DECIMAL(6,2) NOT NULL DEFAULT 2.00,
        benefit_text_th VARCHAR(255) NOT NULL,
        benefit_text_en VARCHAR(255) NOT NULL,
        timezone_name VARCHAR(64) NOT NULL DEFAULT 'Asia/Bangkok',
        settings_version INT NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        updated_by VARCHAR(100) NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await conn.execute('''
      INSERT IGNORE INTO loyalty_tier_settings
        (id, enabled, monthly_threshold, points_multiplier, benefit_text_th, benefit_text_en, timezone_name)
      VALUES
        (1, 1, 10000.00, 2.00,
         'ยอดซื้อรายเดือนครบ 10,000 บาท รับแต้มคูณ 2',
         'Earn 2x points after reaching 10,000 THB monthly spend',
         'Asia/Bangkok')
    ''');

    // Only subjects owned by exactly one active customer are safe to backfill.
    await conn.execute('''
      INSERT IGNORE INTO customer_identity_owner (provider, subject, customer_id)
      SELECT 'LINE', TRIM(line_user_id), MIN(id)
      FROM customer
      WHERE line_user_id IS NOT NULL AND TRIM(line_user_id) <> ''
        AND (isDeleted = 0 OR isDeleted IS NULL)
      GROUP BY TRIM(line_user_id)
      HAVING COUNT(*) = 1
    ''');
    await conn.execute('''
      INSERT IGNORE INTO customer_identity_link
        (provider, subject, customer_id, status, method, actor_type, request_uuid, reason)
      SELECT provider, subject, customer_id, 'ACTIVE', 'ADMIN_APPROVAL',
             'MIGRATION', CONCAT('backfill-line-', customer_id),
             'Safe unique legacy LINE backfill'
      FROM customer_identity_owner
      WHERE provider = 'LINE'
    ''');
    final duplicates = await conn.execute('''
      SELECT COUNT(*) FROM (
        SELECT TRIM(line_user_id) AS subject
        FROM customer
        WHERE line_user_id IS NOT NULL AND TRIM(line_user_id) <> ''
          AND (isDeleted = 0 OR isDeleted IS NULL)
        GROUP BY TRIM(line_user_id)
        HAVING COUNT(*) > 1
      ) duplicate_subjects
    ''');
    final count = duplicates.rows.first.colAt(0) ?? '0';
    stdout.writeln(
      '⚠️ Membership migration left $count duplicate LINE subject group(s) for admin resolution.',
    );
  }

  Future<void> _onlineOrderCouponReservation(dynamic conn) async {
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS online_orders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        orderNumber VARCHAR(50) NOT NULL,
        customerId INT NULL,
        customerName VARCHAR(255) NOT NULL,
        customerPhone VARCHAR(50) NOT NULL,
        lineUserId VARCHAR(100) NULL,
        lineDisplayName VARCHAR(255) NULL,
        deliveryType VARCHAR(20) NOT NULL DEFAULT 'pickup',
        deliveryAddress TEXT NULL,
        gpsLocation VARCHAR(255) NULL,
        distanceKm DECIMAL(10,3) NOT NULL DEFAULT 0,
        deliveryFee DECIMAL(12,2) NOT NULL DEFAULT 0,
        totalAmount DECIMAL(14,2) NOT NULL DEFAULT 0,
        grandTotal DECIMAL(14,2) NOT NULL DEFAULT 0,
        itemsJson LONGTEXT NOT NULL,
        notes TEXT NULL,
        status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
        confirmedBy VARCHAR(100) NULL,
        clientRequestId CHAR(36) NULL,
        payloadHash CHAR(64) NULL,
        couponCode VARCHAR(20) NULL,
        couponDiscount DECIMAL(12,2) NULL,
        couponReservedUntil DATETIME NULL,
        posOrderId INT NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        KEY idx_status (status),
        KEY idx_created (createdAt),
        UNIQUE KEY uq_online_order_client_request (clientRequestId)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await _ensureColumn(
      conn,
      'online_orders',
      'clientRequestId',
      'CHAR(36) NULL',
    );
    await _ensureColumn(conn, 'online_orders', 'payloadHash', 'CHAR(64) NULL');
    await _ensureColumn(
      conn,
      'online_orders',
      'couponCode',
      'VARCHAR(20) NULL',
    );
    await _ensureColumn(
      conn,
      'online_orders',
      'couponDiscount',
      'DECIMAL(12,2) NULL',
    );
    await _ensureColumn(
      conn,
      'online_orders',
      'couponReservedUntil',
      'DATETIME NULL',
    );
    await _ensureColumn(conn, 'online_orders', 'posOrderId', 'INT NULL');
    await _ensureIndex(
      conn,
      'online_orders',
      'uq_online_order_client_request',
      'UNIQUE KEY uq_online_order_client_request (clientRequestId)',
    );

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS reward_coupon (
        id INT AUTO_INCREMENT PRIMARY KEY,
        coupon_code VARCHAR(20) UNIQUE NOT NULL,
        customer_id INT NOT NULL,
        reward_id INT NOT NULL,
        redemption_id INT NOT NULL,
        discount_value DECIMAL(10,2) NOT NULL,
        expires_at DATETIME NOT NULL,
        used_at DATETIME NULL,
        order_id INT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
        reserved_online_order_id INT NULL,
        reserved_until DATETIME NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    if (await _columnExists(conn, 'reward_coupon', 'status')) {
      await conn.execute(
        "ALTER TABLE reward_coupon MODIFY COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'",
      );
    }
    await _ensureColumn(
      conn,
      'reward_coupon',
      'reserved_online_order_id',
      'INT NULL',
    );
    await _ensureColumn(
      conn,
      'reward_coupon',
      'reserved_until',
      'DATETIME NULL',
    );
    await _ensureIndex(
      conn,
      'reward_coupon',
      'idx_reward_coupon_reservation',
      'KEY idx_reward_coupon_reservation (status, reserved_until)',
    );
    await _ensureIndex(
      conn,
      'reward_coupon',
      'idx_reward_coupon_online_order',
      'KEY idx_reward_coupon_online_order (reserved_online_order_id)',
    );
  }

  Future<void> _rewardRedemptionIdempotency(dynamic conn) async {
    // Persistent phone guard rows serialize creates for one normalized phone
    // without making the legacy customer.phone column unique.
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS customer_phone_creation_guard (
        normalized_phone VARCHAR(20) PRIMARY KEY,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS reward_redemption (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customer_id INT NOT NULL,
        reward_id INT NOT NULL,
        points_used INT NOT NULL,
        redeemed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
        reward_type VARCHAR(20) NOT NULL DEFAULT 'GIFT',
        client_request_id CHAR(36) NULL
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await _ensureColumn(
      conn,
      'reward_redemption',
      'client_request_id',
      'CHAR(36) NULL',
    );
    await _ensureIndex(
      conn,
      'reward_redemption',
      'uq_reward_redemption_client_request',
      'UNIQUE KEY uq_reward_redemption_client_request (client_request_id)',
    );
  }

  Future<void> _loyaltyPaidOrderAward(dynamic conn) async {
    await _ensureColumn(conn, 'order', 'loyaltyPaidAt', 'DATETIME NULL');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_order_award (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        order_id INT NOT NULL,
        customer_id INT NOT NULL,
        paid_at DATETIME NOT NULL,
        qualifying_month DATE NOT NULL,
        base_amount DECIMAL(14,2) NOT NULL,
        base_points INT NOT NULL,
        multiplier DECIMAL(6,2) NOT NULL,
        bonus_points INT NOT NULL DEFAULT 0,
        awarded_points INT NOT NULL,
        monthly_threshold DECIMAL(14,2) NOT NULL,
        settings_version INT NOT NULL,
        point_ledger_id INT NULL,
        source VARCHAR(30) NOT NULL,
        reversed_at DATETIME NULL,
        reversal_reason VARCHAR(255) NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_loyalty_award_order (order_id),
        KEY idx_loyalty_award_customer_month
          (customer_id, qualifying_month, reversed_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_payment_event (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        idempotency_key VARCHAR(100) NOT NULL,
        customer_id INT NOT NULL,
        order_id INT NULL,
        amount DECIMAL(14,2) NOT NULL,
        paid_at DATETIME NOT NULL,
        source VARCHAR(30) NOT NULL,
        reversed_event_id BIGINT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_loyalty_payment_event_key (idempotency_key),
        KEY idx_loyalty_payment_customer_paid (customer_id, paid_at),
        KEY idx_loyalty_payment_order (order_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
  }

  Future<void> _contractorMonthlyTiers(dynamic conn) async {
    await _ensureColumn(
      conn,
      'member_tier',
      'loyaltySegment',
      "VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER'",
    );
    await conn.execute('''
      UPDATE member_tier SET loyaltySegment = 'CONTRACTOR'
      WHERE LOWER(COALESCE(priceLevel, '')) = 'wholesale'
        OR LOWER(COALESCE(name, '')) LIKE '%contractor%'
        OR COALESCE(name, '') LIKE '%ช่าง%'
    ''');
    await _ensureColumn(
      conn,
      'loyalty_tier_settings',
      'contractor_threshold_1',
      'DECIMAL(14,2) NOT NULL DEFAULT 20000.00',
    );
    await _ensureColumn(
      conn,
      'loyalty_tier_settings',
      'contractor_multiplier_1',
      'DECIMAL(6,2) NOT NULL DEFAULT 2.50',
    );
    await _ensureColumn(
      conn,
      'loyalty_tier_settings',
      'contractor_threshold_2',
      'DECIMAL(14,2) NOT NULL DEFAULT 50000.00',
    );
    await _ensureColumn(
      conn,
      'loyalty_tier_settings',
      'contractor_multiplier_2',
      'DECIMAL(6,2) NOT NULL DEFAULT 3.00',
    );
  }

  Future<void> _contractorNextBillRevision(dynamic conn) async {
    await conn.execute('''
      UPDATE loyalty_tier_settings
      SET contractor_multiplier_1 = 2.50,
          contractor_threshold_2 = 50000.00,
          contractor_multiplier_2 = 3.00,
          settings_version = settings_version + 1
      WHERE id = 1
        AND contractor_threshold_1 = 20000.00
        AND contractor_multiplier_1 = 3.00
        AND contractor_threshold_2 = 40000.00
        AND contractor_multiplier_2 = 3.50
    ''');
    await conn.execute('''
      ALTER TABLE loyalty_tier_settings
        MODIFY contractor_multiplier_1 DECIMAL(6,2) NOT NULL DEFAULT 2.50,
        MODIFY contractor_threshold_2 DECIMAL(14,2) NOT NULL DEFAULT 50000.00,
        MODIFY contractor_multiplier_2 DECIMAL(6,2) NOT NULL DEFAULT 3.00
    ''');
  }

  Future<void> _loyaltyReversalCycles(dynamic conn) async {
    await _ensureColumn(
      conn,
      'loyalty_order_award',
      'cycle_number',
      'INT NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      conn,
      'loyalty_order_award',
      'current_payment_event_id',
      'BIGINT NULL',
    );
    await _ensureIndex(
      conn,
      'loyalty_order_award',
      'idx_loyalty_award_current_event',
      'KEY idx_loyalty_award_current_event (current_payment_event_id)',
    );
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_award_cycle_history (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        order_id INT NOT NULL,
        award_id BIGINT NOT NULL,
        cycle_number INT NOT NULL,
        customer_id INT NOT NULL,
        payment_event_id BIGINT NULL,
        reversal_event_id BIGINT NULL,
        point_ledger_id INT NOT NULL,
        paid_at DATETIME NOT NULL,
        reversed_at DATETIME NOT NULL,
        qualifying_month DATE NOT NULL,
        base_amount DECIMAL(14,2) NOT NULL,
        base_points INT NOT NULL,
        multiplier DECIMAL(6,2) NOT NULL,
        bonus_points INT NOT NULL DEFAULT 0,
        awarded_points INT NOT NULL,
        monthly_threshold DECIMAL(14,2) NOT NULL,
        settings_version INT NOT NULL,
        award_source VARCHAR(30) NOT NULL,
        reversal_source VARCHAR(30) NOT NULL,
        reversal_reason VARCHAR(255) NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_loyalty_cycle_order (order_id, cycle_number),
        UNIQUE KEY uq_loyalty_cycle_reversal_event (reversal_event_id),
        KEY idx_loyalty_cycle_customer (customer_id, paid_at),
        KEY idx_loyalty_cycle_award (award_id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
    await conn.execute('''
      UPDATE loyalty_order_award a
      SET current_payment_event_id = (
        SELECT MIN(e.id) FROM loyalty_payment_event e
        WHERE e.order_id = a.order_id
          AND e.idempotency_key = CONCAT('CLOSE:', a.order_id)
      )
      WHERE current_payment_event_id IS NULL
    ''');
    // Preserve already-reversed legacy rows as immutable cycle snapshots.
    await conn.execute('''
      INSERT IGNORE INTO loyalty_award_cycle_history
        (order_id, award_id, cycle_number, customer_id, payment_event_id,
         reversal_event_id, point_ledger_id, paid_at, reversed_at,
         qualifying_month, base_amount, base_points, multiplier, bonus_points,
         awarded_points, monthly_threshold, settings_version, award_source,
         reversal_source, reversal_reason)
      SELECT order_id, id, cycle_number, customer_id,
             current_payment_event_id, NULL, point_ledger_id, paid_at,
             reversed_at, qualifying_month, base_amount, base_points,
             multiplier, bonus_points, awarded_points, monthly_threshold,
             settings_version, source, 'LEGACY',
             COALESCE(reversal_reason, 'Legacy reversal')
      FROM loyalty_order_award
      WHERE reversed_at IS NOT NULL AND point_ledger_id IS NOT NULL
    ''');
  }

  Future<void> _loyaltyProgramResetAudit(dynamic conn) async {
    await _ensureColumn(
      conn,
      'loyalty_tier_settings',
      'program_started_at',
      'DATETIME NULL',
    );
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_program_reset_audit (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        idempotency_key VARCHAR(100) NOT NULL,
        reset_at DATETIME NOT NULL,
        actor VARCHAR(100) NOT NULL,
        reason VARCHAR(255) NOT NULL,
        cleared_point_ledger_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
        cleared_point_total BIGINT NOT NULL DEFAULT 0,
        cleared_award_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
        cleared_payment_event_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
        cleared_cycle_history_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
        member_customer_count BIGINT UNSIGNED NOT NULL DEFAULT 0,
        linked_member_count BIGINT UNSIGNED NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_loyalty_reset_idempotency (idempotency_key),
        KEY idx_loyalty_reset_at (reset_at)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ''');
  }

  Future<void> _ensureColumn(
    dynamic conn,
    String table,
    String column,
    String definition,
  ) async {
    if (await _columnExists(conn, table, column)) return;
    await conn.execute('ALTER TABLE `$table` ADD COLUMN `$column` $definition');
  }

  Future<bool> _columnExists(dynamic conn, String table, String column) async {
    final result = await conn.execute(
      '''SELECT COUNT(*) AS count FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table
           AND COLUMN_NAME = :column''',
      {'table': table, 'column': column},
    );
    return result.rows.first.assoc()['count'] != '0';
  }

  Future<void> _ensureIndex(
    dynamic conn,
    String table,
    String index,
    String definition,
  ) async {
    final result = await conn.execute(
      '''SELECT COUNT(*) AS count FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table
           AND INDEX_NAME = :index''',
      {'table': table, 'index': index},
    );
    if (result.rows.first.assoc()['count'] != '0') return;
    await conn.execute('ALTER TABLE `$table` ADD $definition');
  }

  Future<void> _claimableCoupon(dynamic conn) async {
    // เพิ่ม claim_type — แยกคูปองแลกแต้ม กับ คูปองกดรับฟรี
    if (!await _columnExists(conn, 'point_reward', 'claim_type')) {
      await conn.execute(
        "ALTER TABLE point_reward ADD COLUMN claim_type VARCHAR(20) NOT NULL DEFAULT 'POINTS_REDEEM' COMMENT 'POINTS_REDEEM=แลกแต้ม, FREE_CLAIM=กดรับฟรี'",
      );
    }
    // เพิ่ม claim_limit_per_user — 0=ไม่จำกัด, 1+=จำกัดต่อคน
    if (!await _columnExists(conn, 'point_reward', 'claim_limit_per_user')) {
      await conn.execute(
        'ALTER TABLE point_reward ADD COLUMN claim_limit_per_user INT NOT NULL DEFAULT 1 COMMENT "0=ไม่จำกัด, 1+=จำกัดต่อคน"',
      );
    }
  }

  Future<void> _customerPinCode(dynamic conn) async {
    if (!await _columnExists(conn, 'customer', 'pin_code')) {
      await conn.execute(
        'ALTER TABLE customer ADD COLUMN pin_code VARCHAR(255) NULL COMMENT "รหัส PIN 4-6 หลักสำหรับล็อกอินด้วยเบอร์โทร"',
      );
    }
  }
}

