import 'dart:async';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import 'mysql/mysql_connection_pool.dart';
import 'mysql/mysql_query_executor.dart';
import 'logger_service.dart';

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

  final MySQLConnectionManager _pool = MySQLConnectionManager();
  final MySqlQueryExecutor _executor = MySqlQueryExecutor();

  /// Exposes the active connection instance for any custom direct integrations.
  MySQLConnection? get connection => _pool.connection;

  // 0. ตรวจสอบว่ามีการตั้งค่า DB หรือยัง
  Future<Map<String, String?>> getConfig() => _pool.getConfig();

  // 0. ตรวจสอบว่ามีการตั้งค่า DB หรือยัง
  Future<bool> hasConfig() => _pool.hasConfig();

  // 1. เชื่อมต่อฐานข้อมูล
  Future<void> connect() => _pool.connect();

  // ทดสอบการเชื่อมต่อ (สำหรับหน้า UI Settings)
  // คืนค่าเป็น String? (null = สำเร็จ, String = Error Message)
  Future<String?> testConnection({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
  }) =>
      _pool.testConnection(
        host: host,
        port: port,
        user: user,
        pass: pass,
        db: db,
      );

  // บันทึกการตั้งค่า
  Future<void> saveConfig({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
    String? machineName,
  }) =>
      _pool.saveConfig(
        host: host,
        port: port,
        user: user,
        pass: pass,
        db: db,
        machineName: machineName,
      );

  // 2. ตรวจสอบสถานะ
  bool isConnected() => _pool.isConnected();

  // 4. Execute (สำหรับ INSERT, UPDATE, DELETE)
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) =>
      _executor.execute(sql, params);
  // 3. Query (สำหรับ SELECT)
  Future<List<Map<String, dynamic>>> query(String sql, [Map<String, dynamic>? params]) =>
      _executor.query(sql, params);

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

  Future<void> initPosCommandsTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS pos_commands (
        id VARCHAR(50) PRIMARY KEY,
        command VARCHAR(100) NOT NULL,
        payload JSON NULL,
        status ENUM('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED') DEFAULT 'PENDING',
        target_device_id VARCHAR(100) NULL,
        result_message TEXT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        claimed_at DATETIME NULL,
        executed_at DATETIME NULL,
        INDEX(status),
        INDEX(target_device_id)
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
        status ENUM('DRAFT', 'ORDERED', 'RECEIVED', 'CANCELLED', 'PARTIAL') DEFAULT 'DRAFT',
        userId INT NULL,
        note TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        isPaid TINYINT(1) DEFAULT 0,
        INDEX(supplierId),
        INDEX(branchId),
        INDEX(status),
        INDEX(documentNo),
        INDEX(isPaid)
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

      // Check for vatType
      final checkVat = await query('''
        SELECT COUNT(*) as count 
        FROM information_schema.columns 
        WHERE table_schema = DATABASE() 
        AND table_name = 'purchase_order' 
        AND column_name = 'vatType'
      ''');
      if (checkVat.isNotEmpty &&
          (int.tryParse(checkVat.first['count'].toString()) ?? 0) == 0) {
        await execute(
            "ALTER TABLE purchase_order ADD COLUMN vatType INT DEFAULT 0 COMMENT '0=Included, 1=Excluded, 2=NoVAT';");
      }

      // Check for isPaid
      final checkPaid = await query('''
        SELECT COUNT(*) as count 
        FROM information_schema.columns 
        WHERE table_schema = DATABASE() 
        AND table_name = 'purchase_order' 
        AND column_name = 'isPaid'
      ''');
      if (checkPaid.isNotEmpty &&
          (int.tryParse(checkPaid.first['count'].toString()) ?? 0) == 0) {
        await execute(
            "ALTER TABLE purchase_order ADD COLUMN isPaid TINYINT(1) DEFAULT 0 AFTER vatType;");
        await execute("ALTER TABLE purchase_order ADD INDEX (isPaid);");
      }
    } catch (e) {
      LoggerService.error('MySQLService', 'Error ensuring purchase_order columns', e);
    }
  }

  Future<void> ensureBranchColumns() async {
    final tables = ['order', 'product', 'stockledger', 'customer', 'expense'];
    for (var table in tables) {
      await ensureColumn(table, 'branchId', 'INT DEFAULT 1');
    }
  }

  /// Utility to safely add a column without triggering 1060 MySQL errors in logs
  Future<void> ensureColumn(String table, String columnName, String columnType) async {
    try {
      final safeTable = table == 'order' ? '`order`' : table;
      final checkSql = "SHOW COLUMNS FROM $safeTable LIKE '$columnName'";
      final res = await query(checkSql);
      if (res.isEmpty) {
        await execute('ALTER TABLE $safeTable ADD COLUMN $columnName $columnType');
        LoggerService.info('MySQLService', 'Added column: $columnName to $safeTable');
      }
    } catch (e) {
      LoggerService.warning('MySQLService', 'Failed to ensure column $columnName in $table: $e');
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
        LoggerService.info('MySQLService', 'Adding missing UNIQUE KEY to user_permission...');
        // ลบ row ที่ซ้ำกันออกก่อน (เก็บแค่ id ต่ำสุดของแต่ละ userId+permissionKey)
        await execute('''
          DELETE t1 FROM user_permission t1
          INNER JOIN user_permission t2
          WHERE t1.id > t2.id
            AND t1.userId = t2.userId
            AND t1.permissionKey = t2.permissionKey
        ''');
        // แล้วค่อย ADD UNIQUE KEY (ใช้ได้ใน MySQL 5.7.4+ ทุกเวอร์ชัน)
        await execute(
            'ALTER TABLE user_permission ADD UNIQUE KEY idx_user_perm (userId, permissionKey);');
      }
    } catch (e) {
      LoggerService.warning('MySQLService', 'ensureUserPermissionUniqueKey error: $e');
    }
  }

  Future<void> initSystemSettingsTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS system_settings (
        setting_key VARCHAR(100) PRIMARY KEY,
        setting_value MEDIUMTEXT,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
      
    ''';
    await execute(sql);
    // ✅ Ensure existing DB column is large enough for base64 images
    await ensureSettingsColumnSize();
  }

  /// เพิ่มขนาด column setting_value จาก TEXT เป็น MEDIUMTEXT สำหรับฐานข้อมูลเดิมที่สร้างด้วย TEXT
  Future<void> ensureSettingsColumnSize() async {
    try {
      const checkSql = '''
        SELECT DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'system_settings'
          AND column_name = 'setting_value'
      ''';
      final res = await query(checkSql);
      if (res.isNotEmpty) {
        final dataType =
            (res.first['DATA_TYPE'] ?? '').toString().toLowerCase();
        // ถ้ายังเป็น TEXT (เก็บได้แค่ ~65KB) ให้ ALTER เป็น MEDIUMTEXT (~16MB)
        if (dataType == 'tinytext' || dataType == 'text') {
          LoggerService.info(
              'MySQLService', 'Upgrading system_settings.setting_value: $dataType → MEDIUMTEXT');
          await execute(
              'ALTER TABLE system_settings MODIFY COLUMN setting_value MEDIUMTEXT');
          LoggerService.info(
              'MySQLService', 'system_settings.setting_value upgraded to MEDIUMTEXT');
        }
      }
    } catch (e) {
      LoggerService.warning('MySQLService', 'ensureSettingsColumnSize error: $e');
    }
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
          LoggerService.info('MySQLService', 'Adding $col column to debtor_transaction...');
          await execute(
              'ALTER TABLE debtor_transaction ADD COLUMN $col DECIMAL(10,2) DEFAULT 0.0;');
        }
      }
    } catch (e) {
      LoggerService.error('MySQLService', 'Error ensuring debtor_transaction columns', e);
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
