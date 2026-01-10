import 'dart:io'; // Added for InternetAddress
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MySQLService {
  // ---------------------------------------------------------
  // ✅ Singleton Pattern
  // ---------------------------------------------------------
  static final MySQLService _instance = MySQLService._internal();

  factory MySQLService() {
    return _instance;
  }

  MySQLService._internal();
  // ---------------------------------------------------------

  // ข้อมูลการเชื่อมต่อ Local MySQL (Laragon Defaults)
  static const String _defaultHost = '127.0.0.1';
  static const String _defaultUser =
      'admin'; // Reverted to admin as per request
  static const String _defaultPass = '1234'; // Reverted to 1234
  static const String _defaultDb = 'sorborikan';

  MySQLConnection? _conn;
  bool _isConnecting = false;
  Completer<void>? _connectionCompleter;

  // 1. เชื่อมต่อฐานข้อมูล
  Future<void> connect() async {
    if (isConnected()) return;
    if (_isConnecting) return _connectionCompleter?.future;

    _isConnecting = true;
    _connectionCompleter = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String host = prefs.getString('db_host') ?? _defaultHost;
      final int port = (() {
        final val = prefs.get('db_port');
        if (val is int) return val;
        if (val is String) return int.tryParse(val) ?? 3306;
        return 3306;
      })();
      final String user = prefs.getString('db_user') ?? _defaultUser;
      final String pass = prefs.getString('db_pass') ?? _defaultPass;
      final String db = prefs.getString('db_name') ?? _defaultDb;

      // 0. Define strategy to try DB then No-DB
      final tryDBs = [db, null]; // Try specific DB first, then no DB
      Object? lastError;

      // 1. Try Configured Connection First
      for (var targetDB in tryDBs) {
        try {
          debugPrint(
              '🔌 [MySql] Connecting to configured: $host:$port | User: $user | DB: ${targetDB ?? "NONE"}');
          _conn = await MySQLConnection.createConnection(
            host: host,
            port: port,
            userName: user,
            password: pass,
            databaseName: targetDB,
            secure: false,
          );

          // 🔍 [Added] Hostname Resolution Logging
          try {
            final List<InternetAddress> ips =
                await InternetAddress.lookup(host);
            if (ips.isNotEmpty) {
              debugPrint('🔍 [MySql] Resolved "$host" -> ${ips.first.address}');
            }
          } catch (e) {
            debugPrint('⚠️ [MySql] Could not resolve host "$host": $e');
            // Continue anyway, maybe the driver handles it differently or it's an IP
          }

          await _conn!.connect();
          if (_conn!.connected) {
            debugPrint(
                '✅ [MySql] Connected successfully (DB: ${targetDB ?? "NONE"}).');
            _connectionCompleter?.complete();
            return;
          }
        } catch (e) {
          lastError = e;
          debugPrint(
              '⚠️ [MySql] Configured connection failed (DB: ${targetDB ?? "NONE"}): $e');
        }
      }

      // 2. Fallbacks (Only if localhost/127.0.0.1)
      if (host == 'localhost' || host == '127.0.0.1') {
        final fallbacks = [
          {'user': 'root', 'pass': '', 'host': host},
          {'user': 'root', 'pass': '1234', 'host': host},
          {'user': 'admin', 'pass': '1234', 'host': host},
          {'user': 'root', 'pass': 'root', 'host': host}, // Added root/root
          {
            'user': 'root',
            'pass': '',
            'host': host == 'localhost' ? '127.0.0.1' : 'localhost'
          },
        ];

        for (var fb in fallbacks) {
          for (var targetDB in tryDBs) {
            // Apply DB retry to fallbacks too
            try {
              debugPrint(
                  '🔌 [MySql] Trying fallback: ${fb['host']} | User: ${fb['user']} | DB: ${targetDB ?? "NONE"}');
              _conn = await MySQLConnection.createConnection(
                host: fb['host']!,
                port: port,
                userName: fb['user']!,
                password: fb['pass']!,
                databaseName: targetDB,
                secure: false,
              );
              await _conn!.connect();
              if (_conn!.connected) {
                debugPrint(
                    '✅ [MySql] Connected using fallback credentials (DB: ${targetDB ?? "NONE"}).');
                _connectionCompleter?.complete();

                // Optional: Save this working config so we don't need fallback next time?
                // For now, just connect.
                return;
              }
            } catch (e) {
              lastError = e;
              // Continue
            }
            await Future.delayed(
                const Duration(milliseconds: 200)); // Small delay
          }
        }
      }

      throw Exception(
          'Could not connect to MySQL after several attempts. Last error: $lastError');
    } catch (e) {
      debugPrint('❌ MySQL Connection Error: $e');
      _connectionCompleter?.completeError(e);
      rethrow;
    } finally {
      _isConnecting = false;
      _connectionCompleter = null;
    }
  }

  // ทดสอบการเชื่อมต่อ (สำหรับหน้า UI Settings)
  // คืนค่าเป็น bool แทนเพื่อความง่ายใน UI
  // ทดสอบการเชื่อมต่อ (สำหรับหน้า UI Settings)
  // คืนค่าเป็น String? (null = สำเร็จ, String = Error Message)
  Future<String?> testConnection({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
  }) async {
    final secureModes = [false, true];
    final hostsToTry = {host};
    if (host == 'localhost') hostsToTry.add('127.0.0.1');
    if (host == '127.0.0.1') hostsToTry.add('localhost');

    String? lastError;

    for (var currentHost in hostsToTry) {
      for (var isSecure in secureModes) {
        MySQLConnection? testConn;
        try {
          testConn = await MySQLConnection.createConnection(
            host: currentHost,
            port: port,
            userName: user,
            password: pass,
            databaseName: db.isEmpty ? null : db,
            secure: isSecure,
          );

          await testConn.connect();
          if (testConn.connected) {
            await testConn.close();
            return null; // Success
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint('❌ Test Failed ($currentHost, Secure: $isSecure): $e');
        }
      }
    }
    return lastError ?? 'Unknown Error';
  }

  // บันทึกการตั้งค่า
  Future<void> saveConfig({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('db_host', host);
    await prefs.setInt('db_port', port);
    await prefs.setString('db_user', user);
    await prefs.setString('db_pass', pass);
    await prefs.setString('db_name', db);

    if (_conn != null) {
      try {
        if (_conn!.connected) await _conn!.close();
      } catch (e) {
        debugPrint(
            '⚠️ Warning: Could not close MySQL connection gracefully: $e');
      }
      _conn = null;
    }
    await connect();
  }

  // 2. ตรวจสอบสถานะ
  bool isConnected() => _conn != null && _conn!.connected;

  // 4. Execute (สำหรับ INSERT, UPDATE, DELETE)
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) async {
    if (!isConnected()) await connect();
    if (_conn == null) throw Exception('Database connection failed');

    try {
      return await _conn!
          .execute(sql, params)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Error executing statement: $e');
      if (e.toString().contains('closed') ||
          e.toString().contains('Broken pipe')) {
        await connect();
        return await _conn!.execute(sql, params);
      }
      rethrow;
    }
  }

  // 3. Query (สำหรับ SELECT)
  Future<List<Map<String, dynamic>>> query(String sql,
      [Map<String, dynamic>? params]) async {
    if (!isConnected()) {
      await connect();
      if (!isConnected()) return [];
    }

    try {
      final results = await _conn!
          .execute(sql, params)
          .timeout(const Duration(seconds: 15));
      return results.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      debugPrint('Error executing query: $e');
      if (e.toString().contains('closed') ||
          e.toString().contains('Broken pipe')) {
        await connect();
        final retryResults = await _conn!
            .execute(sql, params)
            .timeout(const Duration(seconds: 15));
        return retryResults.rows.map((row) => row.assoc()).toList();
      }
      rethrow;
    }
  }

  // Database Initialization Methods
  Future<void> initHeldBillsTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS held_bills (
        id INT AUTO_INCREMENT PRIMARY KEY,
        customerId INT NULL,
        itemsJson LONGTEXT NOT NULL, 
        note TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sql);
  }

  Future<void> initOrderPaymentTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS order_payment (
        id INT AUTO_INCREMENT PRIMARY KEY,
        orderId INT NOT NULL,
        paymentMethod VARCHAR(50) NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX(orderId)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sql);
  }

  Future<void> initProductBarcodeTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS product_barcode (
        id INT AUTO_INCREMENT PRIMARY KEY,
        productId INT NOT NULL,
        barcode VARCHAR(100) NOT NULL,
        unitName VARCHAR(50) NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        quantity DECIMAL(10,2) NOT NULL, 
        INDEX(productId),
        INDEX(barcode)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sql);
  }

  Future<void> initActivityLogTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS activity_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NULL,
        branchId INT DEFAULT 1,
        action VARCHAR(100) NOT NULL,
        details TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        INDEX(userId),
        INDEX(branchId)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sql);
  }

  Future<void> initPurchaseOrderTables() async {
    const sqlHeader = '''
      CREATE TABLE IF NOT EXISTS purchase_order (
        id INT AUTO_INCREMENT PRIMARY KEY,
        documentNo VARCHAR(100) NULL,
        supplierId INT NOT NULL,
        branchId INT NOT NULL DEFAULT 1,
        totalAmount DECIMAL(10,2) NOT NULL DEFAULT 0.0,
        status ENUM('DRAFT', 'ORDERED', 'RECEIVED', 'CANCELLED') DEFAULT 'DRAFT',
        userId INT NULL,
        note TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX(supplierId),
        INDEX(branchId),
        INDEX(status),
        INDEX(documentNo)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sqlHeader);

    const sqlItems = '''
      CREATE TABLE IF NOT EXISTS purchase_order_item (
        id INT AUTO_INCREMENT PRIMARY KEY,
        poId INT NOT NULL,
        productId INT NOT NULL,
        productName VARCHAR(255) NOT NULL,
        quantity DECIMAL(10,2) NOT NULL,
        costPrice DECIMAL(10,2) NOT NULL,
        total DECIMAL(10,2) NOT NULL,
        INDEX(poId),
        INDEX(productId)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sqlItems);
  }

  Future<void> ensurePurchaseOrderColumns() async {
    try {
      const checkSql = '''
        SELECT COUNT(*) as count 
        FROM information_schema.columns 
        WHERE table_schema = DATABASE() 
        AND table_name = 'purchase_order' 
        AND column_name = 'documentNo'
      ''';
      final res = await query(checkSql);
      if (res.isNotEmpty &&
          (int.tryParse(res.first['count'].toString()) ?? 0) == 0) {
        await execute(
            'ALTER TABLE purchase_order ADD COLUMN documentNo VARCHAR(100) NULL AFTER id;');
      }
    } catch (e) {
      debugPrint('Error ensuring purchase_order columns: $e');
    }
  }

  Future<void> ensureBranchColumns() async {
    final tables = ['order', 'product', 'stockledger', 'customer', 'expense'];
    for (var table in tables) {
      try {
        final tableName = table == 'order' ? '`order`' : table;
        final checkSql = '''
          SELECT COUNT(*) as count 
          FROM information_schema.columns 
          WHERE table_schema = DATABASE() 
          AND table_name = '${table == 'order' ? 'order' : table}' 
          AND column_name = 'branchId'
        ''';
        final res = await query(checkSql);
        if (res.isNotEmpty &&
            (int.tryParse(res.first['count'].toString()) ?? 0) == 0) {
          await execute(
              'ALTER TABLE $tableName ADD COLUMN branchId INT DEFAULT 1;');
        }
      } catch (e) {
        debugPrint('Error ensuring branch column for $table: $e');
      }
    }
  }

  Future<void> initUserPermissionTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS user_permission (
        id INT AUTO_INCREMENT PRIMARY KEY,
        userId INT NOT NULL,
        permissionKey VARCHAR(100) NOT NULL,
        isAllowed TINYINT(1) DEFAULT 0,
        INDEX(userId),
        UNIQUE KEY idx_user_perm (userId, permissionKey)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sql);
    await ensureUserPermissionUniqueKey(); // ✅ Ensure key exists for old DBs
  }

  Future<void> ensureUserPermissionUniqueKey() async {
    try {
      // Check if index exists
      final checkSql = '''
        SELECT COUNT(1) IndexIsThere FROM INFORMATION_SCHEMA.STATISTICS
        WHERE table_schema=DATABASE() AND table_name='user_permission' AND index_name='idx_user_perm';
      ''';
      final res = await query(checkSql);
      final count = int.tryParse(res.first['IndexIsThere'].toString()) ?? 0;

      if (count == 0) {
        debugPrint('🔧 Adding missing UNIQUE KEY to user_permission...');
        // Might fail if duplicates exist, so we try to clean duplicates first?
        // Simple strategy: IGNORE duplicates or just try ADD UNIQUE
        // Better: let it fail if duplicates, but at least we try.
        await execute(
            'ALTER IGNORE TABLE user_permission ADD UNIQUE KEY idx_user_perm (userId, permissionKey);');
      }
    } catch (e) {
      debugPrint('⚠️ ensureUserPermissionUniqueKey error: $e');
    }
  }

  Future<void> initSystemSettingsTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS system_settings (
        setting_key VARCHAR(100) PRIMARY KEY,
        setting_value TEXT,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sql);
  }

  Future<void> ensureDebtorTransactionColumns() async {
    try {
      final columns = ['balanceBefore', 'balanceAfter'];
      for (var col in columns) {
        final checkSql = '''
          SELECT COUNT(*) as count 
          FROM information_schema.columns 
          WHERE table_schema = DATABASE() 
          AND table_name = 'debtor_transaction' 
          AND column_name = '$col'
        ''';
        final res = await query(checkSql);
        if (res.isNotEmpty &&
            (int.tryParse(res.first['count'].toString()) ?? 0) == 0) {
          debugPrint('Adding $col column to debtor_transaction...');
          await execute(
              'ALTER TABLE debtor_transaction ADD COLUMN $col DECIMAL(10,2) DEFAULT 0.0;');
        }
      }
    } catch (e) {
      debugPrint('Error ensuring debtor_transaction columns: $e');
    }
  }

  // --- Product Master Data ---
  Future<void> initProductTypeTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS product_type (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        isWeighing TINYINT(1) DEFAULT 0,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ''';
    await execute(sql);

    // Seed default values if empty
    final count = await query('SELECT COUNT(*) as c FROM product_type');
    final c = int.tryParse(count.first['c'].toString()) ?? 0;
    if (c == 0) {
      // Use IGNORE to prevent duplicates if race condition or part-fail
      await execute(
          "INSERT IGNORE INTO product_type (id, name, isWeighing) VALUES (0, 'ทั่วไป', 0)");
      await execute(
          "INSERT IGNORE INTO product_type (id, name, isWeighing) VALUES (1, 'ชั่งน้ำหนัก', 1)");
    }
  }
}
