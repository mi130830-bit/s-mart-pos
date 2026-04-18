import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

import '../models/customer.dart';
import '../models/member_tier.dart';
import './activity_repository.dart';

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

  Future<List<MemberTier>> getAllTiers() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    final results = await _dbService
        .query('SELECT * FROM member_tier ORDER BY minTotalSpending ASC');
    return results.map((r) => MemberTier.fromJson(r)).toList();
  }

  Future<List<Customer>> getAllCustomers() async {
    return getCustomersPaginated(1, 10000); // Redirect to paginated
  }

  Future<List<Customer>> getCustomersPaginated(int page, int pageSize,
      {String? searchTerm,
      bool onlyDebtors = false,
      bool onlyLineConnected = false}) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (e) {
        debugPrint('⚠️ Auto-connect failed in getCustomers: $e');
        return [];
      }
    }
    try {
      final offset = (page - 1) * pageSize;
      List<String> conditions = [];
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        conditions.add(
            '(firstName LIKE :term OR lastName LIKE :term OR phone LIKE :term OR memberCode LIKE :term)');
        params['term'] = '%$searchTerm%';
      }

      if (onlyDebtors) {
        conditions.add('currentDebt > 0.01');
      }

      if (onlyLineConnected) {
        conditions.add('(line_user_id IS NOT NULL AND line_user_id != "")');
      }

      String whereClause = conditions.isNotEmpty
          ? 'WHERE ${conditions.join(" AND ")} AND (isDeleted = 0 OR isDeleted IS NULL)'
          : 'WHERE (isDeleted = 0 OR isDeleted IS NULL)';

      params['limit'] = pageSize;
      params['offset'] = offset;

      final sql = '''
        SELECT c.*, t.name as tierName 
        FROM customer c
        LEFT JOIN member_tier t ON c.tierId = t.id
        $whereClause 
        ORDER BY c.currentDebt DESC, c.id DESC LIMIT :limit OFFSET :offset
      ''';

      final results = await _dbService.query(sql, params);

      if (results.length > 100) {
        return await compute(_parseCustomerList, results);
      } else {
        return _parseCustomerList(results);
      }
    } catch (e) {
      debugPrint('Error fetching customers paginated: $e');
      return [];
    }
  }

  Future<int> getCustomerCount(
      {String? searchTerm,
      bool onlyDebtors = false,
      bool onlyLineConnected = false}) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (e) {
        return 0;
      }
    }
    try {
      List<String> conditions = [];
      Map<String, dynamic> params = {};

      if (searchTerm != null && searchTerm.isNotEmpty) {
        conditions.add(
            '(firstName LIKE :term OR lastName LIKE :term OR phone LIKE :term OR memberCode LIKE :term)');
        params['term'] = '%$searchTerm%';
      }

      if (onlyDebtors) {
        conditions.add('currentDebt > 0.01');
      }

      if (onlyLineConnected) {
        conditions.add('(line_user_id IS NOT NULL AND line_user_id != "")');
      }

      String whereClause = conditions.isNotEmpty
          ? 'WHERE ${conditions.join(" AND ")} AND (isDeleted = 0 OR isDeleted IS NULL)'
          : 'WHERE (isDeleted = 0 OR isDeleted IS NULL)';

      final sql = 'SELECT COUNT(*) as c FROM customer $whereClause';
      final res = await _dbService.query(sql, params);
      if (res.isNotEmpty) {
        return int.tryParse(res.first['c'].toString()) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Error counting customers: $e');
      return 0;
    }
  }

  Future<Customer?> getCustomerById(int id) async {
    if (!_dbService.isConnected()) {
      try {
        await _dbService.connect();
      } catch (e) {
        debugPrint('⚠️ Auto-connect failed in getCustomerById: $e');
        return null;
      }
    }
    try {
      final results = await _dbService.query('''
        SELECT c.*, t.name as tierName 
        FROM customer c
        LEFT JOIN member_tier t ON c.tierId = t.id
        WHERE c.id = :id
      ''', {'id': id});
      if (results.isEmpty) return null;
      return Customer.fromJson(results.first);
    } catch (e) {
      debugPrint('Error fetching customer by id: $e');
      return null;
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

  Future<int> saveCustomer(Customer customer) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }

    // Helper: แปลง empty string เป็น null เพื่อหลีกเลี่ยง UNIQUE constraint conflict
    String? emptyToNull(String? value) {
      if (value == null || value.trim().isEmpty) return null;
      return value;
    }

    try {
      if (customer.id == 0) {
        // Insert
        const sql = '''
          INSERT INTO customer (
            memberCode, firstName, lastName, phone, currentPoints, 
            address, shippingAddress, dateOfBirth, membershipExpiryDate,
            nationalId, email, taxId, creditLimit, currentDebt, remarks, totalSpending, tierId,
            line_user_id, line_display_name, line_picture_url, distanceKm
          ) VALUES (
            :code, :fname, :lname, :phone, :points,
            :addr, :shipAddr, :dob, :exp,
            :nid, :email, :tax, :limit, :debt, :remarks, :spending, :tierId,
            :lineId, :lineName, :linePic, :distanceKm
          )
        ''';
        final params = {
          'code': customer.memberCode,
          'fname': customer.firstName,
          'lname': emptyToNull(customer.lastName),
          'phone': customer.phone,
          'points': customer.currentPoints,
          'addr': emptyToNull(customer.address),
          'shipAddr': emptyToNull(customer.shippingAddress),
          'dob': customer.dateOfBirth?.toIso8601String(),
          'exp': customer.membershipExpiryDate?.toIso8601String(),
          'nid': emptyToNull(customer.nationalId), // ✅ Fix duplicate key error
          'email': emptyToNull(customer.email),
          'tax': emptyToNull(customer.taxId),
          'limit': customer.creditLimit,
          'debt': customer.currentDebt,
          'remarks': emptyToNull(customer.remarks),
          'spending': customer.totalSpending,
          'tierId': customer.tierId,
          'distanceKm': customer.distanceKm,
          'lineId': emptyToNull(customer.lineUserId),
          'lineName': emptyToNull(customer.lineDisplayName),
          'linePic': emptyToNull(customer.linePictureUrl),
        };

        // Debug logging
        debugPrint('🔍 [CustomerRepo]: Executing INSERT...');
        debugPrint('  SQL: ${sql.replaceAll(RegExp(r'\s+'), ' ').trim()}');
        debugPrint('  Parameters:');
        params.forEach((key, value) {
          debugPrint('    $key: $value (${value.runtimeType})');
        });

        final result = await _dbService.execute(sql, params);
        debugPrint(
            '✅ [CustomerRepo]: INSERT successful, ID: ${result.lastInsertID}');
        return result.lastInsertID.toInt();
      } else {
        // Update
        const sql = '''
          UPDATE customer SET 
            memberCode = :code, firstName = :fname, lastName = :lname, phone = :phone,
            currentPoints = :points, address = :addr, shippingAddress = :shipAddr,
            dateOfBirth = :dob, membershipExpiryDate = :exp,
            nationalId = :nid, email = :email, taxId = :tax, creditLimit = :limit,
            remarks = :remarks, totalSpending = :spending,
            tierId = :tierId, distanceKm = :distanceKm,
            line_user_id = :lineId, line_display_name = :lineName, line_picture_url = :linePic
          WHERE id = :id
        ''';
        final params = {
          'id': customer.id,
          'code': customer.memberCode,
          'fname': customer.firstName,
          'lname': emptyToNull(customer.lastName),
          'phone': customer.phone,
          'points': customer.currentPoints,
          'addr': emptyToNull(customer.address),
          'shipAddr': emptyToNull(customer.shippingAddress),
          'dob': customer.dateOfBirth?.toIso8601String(),
          'exp': customer.membershipExpiryDate?.toIso8601String(),
          'nid': emptyToNull(customer.nationalId), // ✅ Fix duplicate key error
          'email': emptyToNull(customer.email),
          'tax': emptyToNull(customer.taxId),
          'limit': customer.creditLimit,
          // 'debt': customer.currentDebt, // ❌ Removed to prevent race condition
          'remarks': emptyToNull(customer.remarks),
          'spending': customer.totalSpending,
          'tierId': customer.tierId,
          'distanceKm': customer.distanceKm,
          'lineId': emptyToNull(customer.lineUserId),
          'lineName': emptyToNull(customer.lineDisplayName),
          'linePic': emptyToNull(customer.linePictureUrl),
        };

        debugPrint(
            '🔍 [CustomerRepo]: Executing UPDATE for ID: ${customer.id}');
        await _dbService.execute(sql, params);
        debugPrint('✅ [CustomerRepo]: UPDATE successful');
        return customer.id;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [CustomerRepo]: Error saving customer:');
      debugPrint('Error: $e');
      debugPrint('Stack trace:\n$stackTrace');
      return -1;
    }
  }

  Future<String?> canDeleteCustomer(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // Check Orders
      final orderRes = await _dbService.query(
          'SELECT COUNT(*) as c FROM `order` WHERE customerId = :id',
          {'id': id});
      final orderCount = int.tryParse(orderRes.first['c'].toString()) ?? 0;
      if (orderCount > 0) {
        return 'ลูกค้ามีประวัติการซื้อ $orderCount รายการ';
      }

      // Check Ledger
      final ledgerRes = await _dbService.query(
          'SELECT COUNT(*) as c FROM customer_ledger WHERE customerId = :id',
          {'id': id});
      final ledgerCount = int.tryParse(ledgerRes.first['c'].toString()) ?? 0;
      if (ledgerCount > 0) {
        return 'ลูกค้ามีประวัติธุรกรรม/หนี้ $ledgerCount รายการ';
      }

      return null; // Deletable
    } catch (e) {
      debugPrint('Error checking delete status: $e');
      return 'เกิดข้อผิดพลาดในการตรวจสอบข้อมูล';
    }
  }

  Future<bool> deleteCustomer(int id, {String reason = ''}) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      // Soft Delete
      await _dbService.execute(
        '''
        UPDATE customer SET 
          isDeleted = 1, 
          deleteReason = :reason, 
          deletedAt = NOW(),
          line_user_id = NULL,
          line_display_name = NULL, 
          line_picture_url = NULL
        WHERE id = :id
        ''',
        {'id': id, 'reason': reason},
      );

      await _activityRepo.log(
          action: 'DELETE_CUSTOMER',
          details: 'ลบลูกค้า ID: $id (Soft Delete) สาเหตุ: $reason');
      return true;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      return false;
    }
  }

  Future<bool> unlinkLine(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        '''
        UPDATE customer SET 
          line_user_id = NULL,
          line_display_name = NULL, 
          line_picture_url = NULL
        WHERE id = :id
        ''',
        {'id': id},
      );
      await _activityRepo.log(
          action: 'UNLINK_LINE',
          details: 'ยกเลิกการเชื่อมต่อ Line ลูกค้า ID: $id');
      return true;
    } catch (e) {
      debugPrint('Error unlinking Line: $e');
      return false;
    }
  }

  Future<bool> restoreCustomer(int id) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        'UPDATE customer SET isDeleted = 0, deletedAt = NULL, deleteReason = NULL WHERE id = :id',
        {'id': id},
      );

      await _activityRepo.log(
          action: 'RESTORE_CUSTOMER', details: 'กู้คืนลูกค้า ID: $id');
      return true;
    } catch (e) {
      debugPrint('Error restoring customer: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDeletedCustomers() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      return await _dbService.query('''
        SELECT * FROM customer 
        WHERE isDeleted = 1 
          AND deletedAt >= DATE_SUB(NOW(), INTERVAL 15 DAY)
        ORDER BY deletedAt DESC
      ''');
    } catch (e) {
      return [];
    }
  }

  Future<void> cleanOldDeletedCustomers() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // ✅ Update: Only delete customers that have NO transactions or orders
      // to avoid Foreign Key Constraint Fails [1451]
      final sql = '''
        DELETE FROM customer 
        WHERE isDeleted = 1 
          AND deletedAt < DATE_SUB(NOW(), INTERVAL 15 DAY)
          AND id NOT IN (SELECT DISTINCT customerId FROM debtor_transaction)
          AND id NOT IN (SELECT DISTINCT customerId FROM `order`)
      ''';
      final res = await _dbService.execute(sql);

      if (res.affectedRows.toInt() > 0) {
        await _activityRepo.log(
            action: 'AUTO_CLEAN',
            details:
                'ลบลูกค้าถาวร ${res.affectedRows} รายการ (เฉพาะที่ไม่ถูกใช้งาน)');
      }
    } catch (e) {
      debugPrint('Error cleaning customers: $e');
    }
  }

  Future<double> getCurrentDebt(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final res = await _dbService.query(
        'SELECT currentDebt FROM customer WHERE id = :id',
        {'id': customerId},
      );
      if (res.isNotEmpty) {
        return double.tryParse(res.first['currentDebt'].toString()) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching current debt: $e');
      return 0.0;
    }
  }

  Future<void> addPoints(int customerId, int amount, {int? orderId}) async {
    if (amount <= 0) return;
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      // คำนวณวันหมดอายุแบบครึ่งปี (Semi-annual)
      // ซื้อ ม.ค.-มิ.ย. -> หมดอายุ 30 มิ.ย. ปีหน้า
      // ซื้อ ก.ค.-ธ.ค. -> หมดอายุ 31 ธ.ค. ปีหน้า
      final now = DateTime.now();
      String expStr;
      if (now.month <= 6) {
        expStr = '${now.year + 1}-06-30 23:59:59';
      } else {
        expStr = '${now.year + 1}-12-31 23:59:59';
      }

      // Insert to ledger with calculated expiration
      await _dbService.execute('''
        INSERT INTO point_ledger (customer_id, points_earned, order_id, expires_at)
        VALUES (:cid, :pts, :oid, :exp)
      ''', {
        'cid': customerId,
        'pts': amount,
        'oid': orderId,
        'exp': expStr,
      });
      // Recalculate and update currentPoints in customer table
      await recalculateCustomerPoints(customerId);
    } catch (e) {
      debugPrint('Error adding points: $e');
    }
  }

  Future<void> redeemPoints(int customerId, int amountToUse) async {
    if (amountToUse <= 0) return;
    if (!_dbService.isConnected()) await _dbService.connect();

    try {
      // 1. Get available ledgers ordered by expires_at ASC (FIFO)
      final res = await _dbService.query('''
        SELECT id, (points_earned - points_used) as available
        FROM point_ledger
        WHERE customer_id = :cid
          AND (points_earned > points_used)
          AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY expires_at ASC
      ''', {'cid': customerId});

      int remainingToRedeem = amountToUse;

      for (var row in res) {
        if (remainingToRedeem <= 0) break;

        final ledgerId = int.tryParse(row['id']?.toString() ?? '0') ?? 0;
        final available =
            double.tryParse(row['available']?.toString() ?? '0')?.toInt() ?? 0;

        if (available <= 0) continue;

        int usedNow = 0;
        if (available >= remainingToRedeem) {
          usedNow = remainingToRedeem;
          remainingToRedeem = 0;
        } else {
          usedNow = available;
          remainingToRedeem -= available;
        }

        await _dbService.execute('''
          UPDATE point_ledger
          SET points_used = points_used + :used
          WHERE id = :lid
        ''', {'used': usedNow, 'lid': ledgerId});
      }

      // Even if not enough points in ledger (e.g. legacy mismatch or over-deducted), just recalculate
      await recalculateCustomerPoints(customerId);
    } catch (e) {
      debugPrint('Error redeeming points: $e');
    }
  }

  Future<void> recalculateCustomerPoints(int customerId) async {
    try {
      // Sum valid points
      final res = await _dbService.query('''
        SELECT SUM(points_earned - points_used) as total
        FROM point_ledger
        WHERE customer_id = :cid
          AND (points_earned > points_used)
          AND (expires_at IS NULL OR expires_at > NOW())
      ''', {'cid': customerId});

      int newTotal = 0;
      if (res.isNotEmpty) {
        newTotal =
            double.tryParse(res.first['total']?.toString() ?? '0')?.toInt() ??
                0;
      }

      // Update main customer table to keep it in sync for fast read
      await _dbService.execute('''
        UPDATE customer SET currentPoints = :pts WHERE id = :cid
      ''', {'pts': newTotal, 'cid': customerId});
    } catch (e) {
      debugPrint('Error recalculating points: $e');
    }
  }

  Future<void> updatePoints(int customerId, int pointsToAdd) async {
    if (pointsToAdd > 0) {
      await addPoints(customerId, pointsToAdd);
    } else if (pointsToAdd < 0) {
      await redeemPoints(customerId, pointsToAdd.abs());
    } else {
      await recalculateCustomerPoints(customerId); // Just refresh if 0
    }
  }

  Future<int> clearAllPoints() async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // Set points_used = points_earned for all non-expired records
      await _dbService.execute('''
        UPDATE point_ledger 
        SET points_used = points_earned 
        WHERE points_earned > points_used 
          AND (expires_at IS NULL OR expires_at > NOW())
      ''');

      final res = await _dbService.execute(
          'UPDATE customer SET currentPoints = 0 WHERE currentPoints > 0');

      if (res.affectedRows.toInt() > 0) {
        await _activityRepo.log(
            action: 'CLEAR_POINTS',
            details: 'ล้างคะแนนสะสมทั้งหมด (${res.affectedRows} รายการ)');
      }
      return res.affectedRows.toInt();
    } catch (e) {
      debugPrint('Error clearing points: $e');
      return 0;
    }
  }
}

// Top-level function for compute
List<Customer> _parseCustomerList(List<Map<String, dynamic>> rows) {
  return rows.map((row) => Customer.fromJson(row)).toList();
}
