import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

import '../models/customer.dart';
import '../models/member_tier.dart';
import './activity_repository.dart';

part 'customer/customer_repository_queries.dart';
part 'customer/customer_repository_mutations.dart';
part 'customer/customer_repository_points.dart';
part 'customer/customer_repository_trash.dart';

class CustomerRepository {
  final MySQLService _dbService;
  final ActivityRepository _activityRepo;

  CustomerRepository(
      {MySQLService? dbService, ActivityRepository? activityRepo})
      : _dbService = dbService ?? MySQLService(),
        _activityRepo = activityRepo ?? ActivityRepository();

  // ✅ Initialize Ledger Table
  Future<void> initTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS customer_ledger (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customerId INT NOT NULL,
        transactionType VARCHAR(50) NOT NULL,
        amount DOUBLE NOT NULL,
        orderId INT NULL,
        note TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''';
    await _dbService.execute(sql);
    await initMemberTierTable(); // Ensure tier table exists
    await ensureColumnsExist(); // Ensure other columns in 'customer' table exists
    await initPointLedgerTable(); // Ensure point ledger exists
  }

  Future<void> initPointLedgerTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS point_ledger (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customer_id INT NOT NULL,
        points_earned INT NOT NULL,
        points_used INT DEFAULT 0,
        order_id INT NULL,
        earned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        expires_at DATETIME NULL
      );
    ''';
    try {
      await _dbService.execute(sql);

      // Auto-migrate old points to ledger if they don't exist
      // Check if points exist but ledger is empty
      const checkSql = 'SELECT COUNT(*) as cnt FROM point_ledger';
      final res = await _dbService.query(checkSql);
      final cnt = int.tryParse(res.first['cnt']?.toString() ?? '0') ?? 0;

      if (cnt == 0) {
        // Migrate existing currentPoints > 0 to point_ledger (give them 1 year from now)
        final migrateSql = '''
          INSERT INTO point_ledger (customer_id, points_earned, expires_at)
          SELECT id, currentPoints, DATE_ADD(NOW(), INTERVAL 1 YEAR)
          FROM customer WHERE currentPoints > 0
        ''';
        await _dbService.execute(migrateSql);
        debugPrint('Migrated legacy points to point_ledger.');
      }
    } catch (e) {
      debugPrint('Error ensuring point ledger: $e');
    }
  }

  // Legacy alias
  Future<void> initLedgerTable() => initTable();

  // ✅ Initialize Member Tier Table
  Future<void> initMemberTierTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS member_tier (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        discountPercentage DOUBLE DEFAULT 0.0,
        pointsMultiplier DOUBLE DEFAULT 1.0,
        minTotalSpending DOUBLE DEFAULT 0.0,
        priceLevel VARCHAR(50) DEFAULT 'member'
      );
    ''';
    await _dbService.execute(sql);

    // Seed default tiers if empty
    final countRes =
        await _dbService.query('SELECT COUNT(*) as c FROM member_tier');
    final count = int.tryParse(countRes.first['c'].toString()) ?? 0;
    if (count == 0) {
      await _dbService.execute('''
        INSERT INTO member_tier (name, discountPercentage, pointsMultiplier, minTotalSpending, priceLevel) VALUES 
        ('General', 0.0, 1.0, 0.0, 'retail'),
        ('Silver', 0.0, 1.0, 1000.0, 'member'),
        ('Gold', 5.0, 1.5, 10000.0, 'member'),
        ('Platinum', 10.0, 2.0, 50000.0, 'wholesale');
      ''');
    }
  }

  Future<void> ensureColumnsExist() async {
    // Helper to check and add column if missing
    try {
      final hasRemarks =
          await _dbService.query("SHOW COLUMNS FROM customer LIKE 'remarks'");
      if (hasRemarks.isEmpty) {
        await _dbService.execute(
            "ALTER TABLE customer ADD COLUMN remarks TEXT DEFAULT NULL");
      }

      final hasSpending = await _dbService
          .query("SHOW COLUMNS FROM customer LIKE 'totalSpending'");
      if (hasSpending.isEmpty) {
        await _dbService.execute(
            "ALTER TABLE customer ADD COLUMN totalSpending DOUBLE DEFAULT 0.0");
      }

      final hasTier =
          await _dbService.query("SHOW COLUMNS FROM customer LIKE 'tierId'");
      if (hasTier.isEmpty) {
        await _dbService
            .execute("ALTER TABLE customer ADD COLUMN tierId INT DEFAULT NULL");
      }

      final hasDistance =
          await _dbService.query("SHOW COLUMNS FROM customer LIKE 'distanceKm'");
      if (hasDistance.isEmpty) {
        await _dbService.execute(
            "ALTER TABLE customer ADD COLUMN distanceKm DECIMAL(8,2) DEFAULT 0.0");
      }

      // Check Line OA columns
      final hasLineId = await _dbService
          .query("SHOW COLUMNS FROM customer LIKE 'line_user_id'");
      if (hasLineId.isEmpty) {
        await _dbService.execute(
            "ALTER TABLE customer ADD COLUMN line_user_id VARCHAR(100) DEFAULT NULL");
        await _dbService
            .execute("CREATE INDEX idx_line_user_id ON customer(line_user_id)");
      }

      final hasLineName = await _dbService
          .query("SHOW COLUMNS FROM customer LIKE 'line_display_name'");
      if (hasLineName.isEmpty) {
        await _dbService.execute(
            "ALTER TABLE customer ADD COLUMN line_display_name VARCHAR(255) DEFAULT NULL");
      }

      final hasLinePic = await _dbService
          .query("SHOW COLUMNS FROM customer LIKE 'line_picture_url'");
      if (hasLinePic.isEmpty) {
        await _dbService.execute(
            "ALTER TABLE customer ADD COLUMN line_picture_url TEXT DEFAULT NULL");
      }
    } catch (e) {
      debugPrint('Error ensuring columns exist: $e');
    }
  }
}
