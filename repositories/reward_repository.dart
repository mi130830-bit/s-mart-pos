import 'package:flutter/foundation.dart';
import '../models/point_reward.dart';
import '../services/mysql_service.dart';

class RedemptionRecord {
  final int id;
  final String rewardName;
  final String? imageUrl;
  final int pointsUsed;
  final DateTime redeemedAt;
  final String status;
  final String rewardType;
  final String customerName;
  final String? phone;
  final String? couponCode;
  final double? discountValue;
  final DateTime? usedAt;

  RedemptionRecord({
    required this.id,
    required this.rewardName,
    this.imageUrl,
    required this.pointsUsed,
    required this.redeemedAt,
    required this.status,
    required this.rewardType,
    required this.customerName,
    this.phone,
    this.couponCode,
    this.discountValue,
    this.usedAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isFulfilled => status == 'FULFILLED';
  bool get isCoupon => rewardType == 'COUPON';

  factory RedemptionRecord.fromJson(Map<String, dynamic> json) {
    final fname = json['firstName']?.toString() ?? '';
    final lname = json['lastName']?.toString() ?? '';
    final name = '$fname $lname'.trim().isNotEmpty ? '$fname $lname'.trim() : 'ลูกค้า';
    return RedemptionRecord(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      rewardName: json['reward_name']?.toString() ?? '-',
      imageUrl: json['image_url']?.toString(),
      pointsUsed: int.tryParse(json['points_used']?.toString() ?? '0') ?? 0,
      redeemedAt: DateTime.tryParse(json['redeemed_at']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'PENDING',
      rewardType: json['reward_type']?.toString() ?? 'GIFT',
      customerName: name,
      phone: json['phone']?.toString(),
      couponCode: json['coupon_code']?.toString(),
      discountValue: double.tryParse(json['discount_value']?.toString() ?? ''),
      usedAt: DateTime.tryParse(json['used_at']?.toString() ?? ''),
    );
  }
}

class CouponValidationResult {
  final bool isValid;
  final String? error;
  final String? couponCode;
  final double? discountValue;
  final String? rewardName;
  final String? customerName;
  final DateTime? expiresAt;

  CouponValidationResult.valid({
    required this.couponCode,
    required this.discountValue,
    required this.rewardName,
    required this.customerName,
    required this.expiresAt,
  })  : isValid = true,
        error = null;

  CouponValidationResult.invalid(this.error)
      : isValid = false,
        couponCode = null,
        discountValue = null,
        rewardName = null,
        customerName = null,
        expiresAt = null;
}

class RewardRepository {
  final MySQLService _dbService = MySQLService();

  Future<void> initTable() async {
    // Original tables
    const sqlReward = '''
      CREATE TABLE IF NOT EXISTS point_reward (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT NULL,
        point_price INT DEFAULT 0,
        stock_quantity INT DEFAULT 0,
        image_url VARCHAR(500) NULL,
        is_active TINYINT(1) DEFAULT 1
      );
    ''';
    await _dbService.execute(sqlReward);

    const sqlRedemption = '''
      CREATE TABLE IF NOT EXISTS reward_redemption (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customer_id INT NOT NULL,
        reward_id INT NOT NULL,
        points_used INT NOT NULL,
        redeemed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        status VARCHAR(20) DEFAULT 'PENDING'
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ''';
    await _dbService.execute(sqlRedemption);

    // Phase 2 Migrations — safe to run multiple times (IF NOT EXISTS / IGNORE errors)
    final migrations = [
      "ALTER TABLE point_reward ADD COLUMN reward_type VARCHAR(10) DEFAULT 'GIFT'",
      "ALTER TABLE point_reward ADD COLUMN discount_value DECIMAL(10,2) DEFAULT 0",
      "ALTER TABLE point_reward ADD COLUMN coupon_expiry_days INT DEFAULT 30",
      "ALTER TABLE reward_redemption ADD COLUMN reward_type VARCHAR(10) DEFAULT 'GIFT'",
      '''CREATE TABLE IF NOT EXISTS reward_coupon (
        id INT AUTO_INCREMENT PRIMARY KEY,
        coupon_code VARCHAR(20) UNIQUE NOT NULL,
        customer_id INT NOT NULL,
        reward_id INT NOT NULL,
        redemption_id INT NOT NULL,
        discount_value DECIMAL(10,2) NOT NULL,
        expires_at DATETIME NOT NULL,
        used_at DATETIME NULL,
        order_id INT NULL,
        status ENUM('ACTIVE','USED','EXPIRED') DEFAULT 'ACTIVE',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci''',
    ];

    for (final sql in migrations) {
      try {
        await _dbService.execute(sql);
      } catch (e) {
        // Ignore "duplicate column" errors from migrations
        if (!e.toString().contains('Duplicate column') && !e.toString().contains('1060')) {
          debugPrint('Migration warning: $e');
        }
      }
    }
  }

  Future<List<PointReward>> getAllRewards({bool activeOnly = false}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    String sql = 'SELECT * FROM point_reward';
    if (activeOnly) sql += ' WHERE is_active = 1';
    sql += ' ORDER BY id DESC';
    try {
      final results = await _dbService.query(sql);
      return results.map((r) => PointReward.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error loading rewards: $e');
      return [];
    }
  }

  Future<bool> saveReward(PointReward reward) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final data = reward.toJson();
      if (reward.id == 0) data.remove('id');
      if (reward.id == 0) {
        const sql = '''
          INSERT INTO point_reward 
            (name, description, point_price, stock_quantity, image_url, is_active,
             reward_type, discount_value, coupon_expiry_days)
          VALUES 
            (:name, :description, :point_price, :stock_quantity, :image_url, :is_active,
             :reward_type, :discount_value, :coupon_expiry_days)
        ''';
        final result = await _dbService.execute(sql, data);
        return result.affectedRows > BigInt.zero;
      } else {
        const sql = '''
          UPDATE point_reward 
          SET name = :name, description = :description, point_price = :point_price,
              stock_quantity = :stock_quantity, image_url = :image_url, is_active = :is_active,
              reward_type = :reward_type, discount_value = :discount_value,
              coupon_expiry_days = :coupon_expiry_days
          WHERE id = :id
        ''';
        final result = await _dbService.execute(sql, data);
        return result.affectedRows > BigInt.zero;
      }
    } catch (e) {
      debugPrint('Error saving reward: $e');
      return false;
    }
  }

  Future<bool> deleteReward(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final result = await _dbService.execute('DELETE FROM point_reward WHERE id = :id', {'id': id});
      return result.affectedRows > BigInt.zero;
    } catch (e) {
      debugPrint('Error deleting reward: $e');
      return false;
    }
  }

  // Phase 2: Admin redemption list
  Future<List<RedemptionRecord>> getRedemptionList() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      const sql = '''
        SELECT rr.id, rr.points_used, rr.redeemed_at,
               COALESCE(rr.status, 'PENDING') as status,
               COALESCE(rr.reward_type, 'GIFT') as reward_type,
               pr.name as reward_name, pr.image_url,
               c.firstName, c.lastName, c.phone,
               rc.coupon_code, rc.discount_value, rc.used_at
        FROM reward_redemption rr
        JOIN point_reward pr ON rr.reward_id = pr.id
        JOIN customer c ON rr.customer_id = c.id
        LEFT JOIN reward_coupon rc ON rc.redemption_id = rr.id
        ORDER BY rr.redeemed_at DESC
        LIMIT 200
      ''';
      final results = await _dbService.query(sql);
      return results.map((r) => RedemptionRecord.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error loading redemptions: $e');
      return [];
    }
  }

  // Phase 2: Fulfill a GIFT redemption
  Future<bool> fulfillRedemption(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final result = await _dbService.execute(
        "UPDATE reward_redemption SET status = 'FULFILLED' WHERE id = :id",
        {'id': id},
      );
      return result.affectedRows > BigInt.zero;
    } catch (e) {
      debugPrint('Error fulfilling redemption: $e');
      return false;
    }
  }

  // Phase 2: Validate a coupon code (called from POS payment)
  Future<CouponValidationResult> validateCoupon(String code) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // Auto-expire
      await _dbService.execute("UPDATE reward_coupon SET status = 'EXPIRED' WHERE expires_at < NOW() AND status = 'ACTIVE'");

      final results = await _dbService.query('''
        SELECT rc.coupon_code, rc.discount_value, rc.expires_at, rc.status,
               pr.name as reward_name,
               c.firstName, c.lastName, c.phone
        FROM reward_coupon rc
        JOIN point_reward pr ON rc.reward_id = pr.id
        JOIN customer c ON rc.customer_id = c.id
        WHERE rc.coupon_code = '${code.toUpperCase()}'
        LIMIT 1
      ''');

      if (results.isEmpty) return CouponValidationResult.invalid('ไม่พบคูปองนี้ในระบบ');
      final r = results.first;
      final status = r['status']?.toString() ?? '';
      if (status == 'USED') return CouponValidationResult.invalid('คูปองนี้ถูกใช้ไปแล้ว');
      if (status == 'EXPIRED') return CouponValidationResult.invalid('คูปองนี้หมดอายุแล้ว');

      final fname = r['firstName']?.toString() ?? '';
      final lname = r['lastName']?.toString() ?? '';

      return CouponValidationResult.valid(
        couponCode: r['coupon_code']?.toString(),
        discountValue: double.tryParse(r['discount_value']?.toString() ?? '0') ?? 0,
        rewardName: r['reward_name']?.toString(),
        customerName: '$fname $lname'.trim(),
        expiresAt: DateTime.tryParse(r['expires_at']?.toString() ?? ''),
      );
    } catch (e) {
      debugPrint('Error validating coupon: $e');
      return CouponValidationResult.invalid('เกิดข้อผิดพลาด: $e');
    }
  }

  // Phase 2: Mark coupon as used (called after order is saved)
  Future<bool> useCoupon(String code, int orderId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        "UPDATE reward_coupon SET status = 'USED', used_at = NOW(), order_id = :orderId WHERE coupon_code = '${code.toUpperCase()}'",
        {'orderId': orderId},
      );
      await _dbService.execute(
        "UPDATE reward_redemption rr JOIN reward_coupon rc ON rc.redemption_id = rr.id SET rr.status = 'FULFILLED' WHERE rc.coupon_code = '${code.toUpperCase()}'",
      );
      return true;
    } catch (e) {
      debugPrint('Error using coupon: $e');
      return false;
    }
  }
}
