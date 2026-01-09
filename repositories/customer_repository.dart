import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';
import '../models/customer.dart';
import '../models/member_tier.dart';

class CustomerRepository {
  final MySQLService _dbService = MySQLService();

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
      {String? searchTerm, bool onlyDebtors = false}) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
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

      String whereClause =
          conditions.isNotEmpty ? 'WHERE ${conditions.join(" AND ")}' : '';

      params['limit'] = pageSize;
      params['offset'] = offset;

      final sql = '''
        SELECT c.*, t.name as tierName 
        FROM customer c
        LEFT JOIN member_tier t ON c.tierId = t.id
        $whereClause 
        ORDER BY c.currentDebt DESC, c.id DESC LIMIT :limit OFFSET :offset
      ''';
      // Note: If onlyDebtors is ON, sorting by debt DESC is useful.
      // If NOT, maybe sorting by ID is fine? I added currentDebt DESC as secondary or primary sort?
      // Let's stick to simple ID desc for general, but maybe Debt desc for debtors?
      // Re-writing SQL to keep simple.
      // Actually, user wants to see debtors. Sorting by debt might be nice.
      // Let's just append sorting.

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
      {String? searchTerm, bool onlyDebtors = false}) async {
    if (!_dbService.isConnected()) await _dbService.connect();
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

      String whereClause =
          conditions.isNotEmpty ? 'WHERE ${conditions.join(" AND ")}' : '';

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
      await _dbService.connect();
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
    } catch (e) {
      debugPrint('Error ensuring columns exist: $e');
    }
  }

  Future<bool> saveCustomer(Customer customer) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }

    try {
      if (customer.id == 0) {
        // Insert
        const sql = '''
          INSERT INTO customer (
            memberCode, firstName, lastName, phone, currentPoints, 
            address, shippingAddress, dateOfBirth, membershipExpiryDate,
            nationalId, email, taxId, creditLimit, currentDebt, remarks, totalSpending, tierId
          ) VALUES (
            :code, :fname, :lname, :phone, :points,
            :addr, :shipAddr, :dob, :exp,
            :nid, :email, :tax, :limit, :debt, :remarks, :spending, :tierId
          )
        ''';
        final params = {
          'code': customer.memberCode,
          'fname': customer.firstName,
          'lname': customer.lastName,
          'phone': customer.phone,
          'points': customer.currentPoints,
          'addr': customer.address,
          'shipAddr': customer.shippingAddress,
          'dob': customer.dateOfBirth?.toIso8601String(),
          'exp': customer.membershipExpiryDate?.toIso8601String(),
          'nid': customer.nationalId,
          'email': customer.email,
          'tax': customer.taxId,
          'limit': customer.creditLimit,
          'debt': customer.currentDebt,
          'remarks': customer.remarks,
          'spending': customer.totalSpending,
          'tierId': customer.tierId,
        };
        await _dbService.execute(sql, params);
      } else {
        // Update
        const sql = '''
          UPDATE customer SET 
            memberCode = :code, firstName = :fname, lastName = :lname, phone = :phone,
            currentPoints = :points, address = :addr, shippingAddress = :shipAddr,
            dateOfBirth = :dob, membershipExpiryDate = :exp,
            nationalId = :nid, email = :email, taxId = :tax, creditLimit = :limit,
            currentDebt = :debt, remarks = :remarks, totalSpending = :spending,
            tierId = :tierId
          WHERE id = :id
        ''';
        final params = {
          'id': customer.id,
          'code': customer.memberCode,
          'fname': customer.firstName,
          'lname': customer.lastName,
          'phone': customer.phone,
          'points': customer.currentPoints,
          'addr': customer.address,
          'shipAddr': customer.shippingAddress,
          'dob': customer.dateOfBirth?.toIso8601String(),
          'exp': customer.membershipExpiryDate?.toIso8601String(),
          'nid': customer.nationalId,
          'email': customer.email,
          'tax': customer.taxId,
          'limit': customer.creditLimit,
          'debt': customer.currentDebt,
          'remarks': customer.remarks,
          'spending': customer.totalSpending,
          'tierId': customer.tierId,
        };
        await _dbService.execute(sql, params);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving customer: $e');
      return false;
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

  Future<bool> deleteCustomer(int id) async {
    if (!_dbService.isConnected()) {
      await _dbService.connect();
    }
    try {
      await _dbService
          .execute('DELETE FROM customer WHERE id = :id', {'id': id});
      return true;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLedger(int customerId) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      final results = await _dbService.query(
        'SELECT * FROM customer_ledger WHERE customerId = :id ORDER BY createdAt DESC',
        {'id': customerId},
      );
      return results;
    } catch (e) {
      debugPrint('Error fetching ledger: $e');
      return [];
    }
  }

  Future<void> addTransaction({
    required int customerId,
    required String type,
    required double amount,
    int? orderId,
    String? note,
  }) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      // 1. Insert Ledger
      await _dbService.execute(
        'INSERT INTO customer_ledger (customerId, transactionType, amount, orderId, note) VALUES (:cid, :type, :amt, :oid, :note)',
        {
          'cid': customerId,
          'type': type,
          'amt': amount,
          'oid': orderId,
          'note': note,
        },
      );

      // 2. Update Customer Debt Balance (Atomic)
      await _dbService.execute(
        'UPDATE customer SET currentDebt = currentDebt + :amt WHERE id = :cid',
        {'amt': amount, 'cid': customerId},
      );
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
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

  Future<void> updatePoints(int customerId, int pointsToAdd) async {
    if (!_dbService.isConnected()) await _dbService.connect();
    try {
      await _dbService.execute(
        'UPDATE customer SET currentPoints = currentPoints + :pts WHERE id = :id',
        {'pts': pointsToAdd, 'id': customerId},
      );
    } catch (e) {
      debugPrint('Error updating points: $e');
    }
  }
}

// Top-level function for compute
List<Customer> _parseCustomerList(List<Map<String, dynamic>> rows) {
  return rows.map((row) => Customer.fromJson(row)).toList();
}
