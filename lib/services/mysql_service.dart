import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'settings_service.dart';

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
  // ❌ Hardcoded defaults removed for security
  // These will be loaded from SecureStorage or require Initial Setup
  // static const String _defaultHost = '127.0.0.1'; ...

  MySQLConnection? _conn;
  bool _isConnecting = false;
  Completer<void>? _connectionCompleter;

  // 0. ตรวจสอบว่ามีการตั้งค่า DB หรือยัง
  Future<Map<String, String?>> getConfig() async {
    const storage = FlutterSecureStorage();
    return {
      'host': await storage.read(key: 'db_host'),
      'port': await storage.read(key: 'db_port'),
      'user': await storage.read(key: 'db_user'),
      'pass': await storage.read(key: 'db_pass'),
      'db': await storage.read(key: 'db_name'),
      'machine_name': await storage.read(key: 'machine_name'),
    };
  }

  // 0. ตรวจสอบว่ามีการตั้งค่า DB หรือยัง
  Future<bool> hasConfig() async {
    const storage = FlutterSecureStorage();
    final host = await storage.read(key: 'db_host');
    final user = await storage.read(key: 'db_user');
    return host != null && user != null;
  }

  Future<String?> _resolveWindowsHostname(String hostname) async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run('ping', ['-4', '-n', '1', '-w', '1000', hostname]);
      if (result.exitCode == 0) {
        final RegExp match = RegExp(r'\[(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\]');
        final ipMatch = match.firstMatch(result.stdout.toString());
        if (ipMatch != null) return ipMatch.group(1);
        
        final RegExp match2 = RegExp(r'Reply from (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
        final ipMatch2 = match2.firstMatch(result.stdout.toString());
        if (ipMatch2 != null) return ipMatch2.group(1);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _scanSubnetForHostname(String targetHostname, int port, String user, String pass, String? db) async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final List<String> myIps = [];
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.address != '127.0.0.1') {
            myIps.add(addr.address);
          }
        }
      }

      if (myIps.isEmpty) return null;

      final Set<String> targetIps = {};
      for (var ip in myIps) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          final base = '${parts[0]}.${parts[1]}.${parts[2]}';
          for (int i = 1; i < 255; i++) {
             final candidate = '$base.$i';
             if (candidate != ip) targetIps.add(candidate);
          }
        }
      }

      String? foundIp;
      final ipList = targetIps.toList();
      const batchSize = 50;
      
      for (int i = 0; i < ipList.length; i += batchSize) {
        if (foundIp != null) break;
        
        final batch = ipList.skip(i).take(batchSize).toList();
        final futures = batch.map((candidateIp) async {
           try {
             final socket = await Socket.connect(candidateIp, port, timeout: const Duration(milliseconds: 500));
             socket.destroy();
             return candidateIp;
           } catch (_) {
             return null;
           }
        });
        
        final results = await Future.wait(futures);
        final openIps = results.where((ip) => ip != null).cast<String>().toList();
        
        for (var openIp in openIps) {
           try {
               final conn = await MySQLConnection.createConnection(
                  host: openIp,
                  port: port,
                  userName: user,
                  password: pass,
                  databaseName: db?.isEmpty == true ? null : db,
                  secure: false,
               );
               await conn.connect().timeout(const Duration(seconds: 2));
               final rows = await conn.execute("SELECT @@hostname AS hname");
               await conn.close();
               
               if (rows.rows.isNotEmpty) {
                 final hname = rows.rows.first.assoc()['hname']?.toString() ?? '';
                 if (hname.toLowerCase() == targetHostname.toLowerCase()) {
                    foundIp = openIp;
                    break;
                 }
               }
           } catch (e) {
               debugPrint('Scanner probe failed on $openIp: $e');
           }
        }
      }
      return foundIp;
    } catch (e) {
      debugPrint('Scanner Fatal Error: $e');
      return null;
    }
  }

  // 1. เชื่อมต่อฐานข้อมูล
  Future<void> connect() async {
    if (isConnected()) return;
    if (_isConnecting) return _connectionCompleter?.future;

    _isConnecting = true;
    _connectionCompleter = Completer<void>();

    try {
      final storage = const FlutterSecureStorage();

      final String? host = await storage.read(key: 'db_host');
      final String? portStr = await storage.read(key: 'db_port');
      final int port = int.tryParse(portStr ?? '3306') ?? 3306;
      final String? user = await storage.read(key: 'db_user');
      final String? pass = await storage.read(key: 'db_pass');
      final String? db = await storage.read(key: 'db_name');

      if (host == null || user == null) {
        throw Exception(
            'Database configuration not found. Please setup first.');
      }

      // 0. Define strategy to try DB then No-DB
      final tryDBs = [db, null]; // Try specific DB first, then no DB
      // 1. Define Secure Modes to try (False first, then True)
      // Some servers (MySQL 8+) with caching_sha2_password REQUIRE secure connection.
      final secureModes = [false, true];

      Object? lastError;
      bool success = false;

      // 0. Proactive mDNS Generation & IP Resolution
      final Set<String> hostsToTry = {};

      // Auto-resolve hostname to IPv4 (to fix NetBIOS/IPv6 socket issues on Windows)
      if (host != 'localhost' &&
          host != '127.0.0.1' &&
          !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
        try {
          final lookups = [host];
          if (!host.contains('.')) lookups.add('$host.local');
          for (var h in lookups) {
            bool resolved = false;
            try {
              final result = await InternetAddress.lookup(h)
                  .timeout(const Duration(seconds: 2));
              for (var addr in result) {
                if (addr.type == InternetAddressType.IPv4) {
                  hostsToTry.add(addr.address);
                  resolved = true;
                  debugPrint(
                      '✅ [MySql] Dynamic resolved $h to IP: ${addr.address}');
                }
              }
            } catch (_) {}
            
            // 🛡️ Fallback: Windows CMD Ping Resolution (bullet-proof for NetBIOS/hostname caching issues)
            String? pingIp;
            if (!resolved && Platform.isWindows) {
              pingIp = await _resolveWindowsHostname(h);
              if (pingIp != null) {
                hostsToTry.add(pingIp);
                debugPrint('✅ [MySql] Ping resolved $h to IP: $pingIp');
              }
            }

            // 🚀 Ultimate Fallback: Deep Subnet Scanner (Bypasses Windows Firewall completely)
            if (!resolved && pingIp == null) {
              final cleanHost = h.replaceAll('.local', '');
              debugPrint('⚠️ Network resolution blocked. Starting deep subnet scan for "$cleanHost"...');
              final scanIp = await _scanSubnetForHostname(cleanHost, port, user, pass ?? '', db);
              if (scanIp != null) {
                hostsToTry.add(scanIp);
                debugPrint('🎉 [MySql] Subnet Scanner found "$cleanHost" at IP: $scanIp');
              }
            }

            hostsToTry.add(h); // OS DNS fallback
          }
        } catch (_) {}
      } else {
        hostsToTry.add(host);
      }

      // 1. Try Configured Connection First
      // Outer Loop: Hosts (Primary then mDNS)
      for (var currentHost in hostsToTry) {
        if (success) break;
        // Middle Loop: DB vs No-DB
        for (var targetDB in tryDBs) {
          if (success) break;
          // Inner Loop: Secure vs Non-Secure
          for (var isSecure in secureModes) {
            if (success) break;

            try {
              debugPrint(
                  '🔌 [MySql] Attempting connection: $currentHost:$port | DB: ${targetDB ?? "NONE"} | Secure: $isSecure');

              _conn = await MySQLConnection.createConnection(
                host: currentHost,
                port: port,
                userName: user,
                password: pass ?? '',
                databaseName: targetDB,
                secure: isSecure,
              );

              // Use a snappy timeout for discovery (3s if mDNS, 5s otherwise)
              final timeout = (currentHost.endsWith('.local')) ? 3 : 5;
              await _conn!.connect().timeout(Duration(seconds: timeout));

              if (_conn!.connected) {
                debugPrint('✅ [MySql] Connected successfully to $currentHost.');

                // 🛡️ Self-Healing: If we connected via a different host, update config
                // BUT only if it wasn't just dynamically resolved from a NetBIOS name to an IP
                final isResolvedIpFromHost = (currentHost != host &&
                    RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')
                        .hasMatch(currentHost) &&
                    !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')
                        .hasMatch(host));

                if (currentHost != host && !isResolvedIpFromHost) {
                  debugPrint('🔄 [MySql] Updating host config to $currentHost');
                  await storage.write(key: 'db_host', value: currentHost);
                  // ✅ Also sync API URL so it uses the working host
                  await SettingsService().syncApiUrlWithHost(currentHost);
                } else if (isResolvedIpFromHost) {
                  debugPrint(
                      'ℹ️ [MySql] Connected using mapped IP $currentHost. Config remains $host');
                }

                _connectionCompleter?.complete();
                success = true;
                return;
              }
            } catch (e) {
              lastError = e;
              debugPrint(
                  '⚠️ [MySql] Connection attempt failed ($currentHost): $e');
            }
          }
        }
      }

      throw Exception(
          'Could not connect to MySQL after several attempts. Last error: $lastError');
    } catch (e) {
      // 🛡️ Self-Healing: If Host Lookup Failed (SocketException), try mDNS (.local)
      final errStr = e.toString();
      if (errStr.contains('SocketException') ||
          errStr.contains('Failed host lookup')) {
        try {
          final storage = const FlutterSecureStorage();
          final currentHost = await storage.read(key: 'db_host');

          // If current host is a simple name (e.g. "ms") without dots, try adding ".local"
          if (currentHost != null && !currentHost.contains('.')) {
            final mDnsHost = '$currentHost.local';
            debugPrint(
                'Listen: Failed to resolve "$currentHost". Attempting mDNS fallback to "$mDnsHost"...');

            _conn = await MySQLConnection.createConnection(
              host: mDnsHost,
              port:
                  int.tryParse(await storage.read(key: 'db_port') ?? '3306') ??
                      3306,
              userName: await storage.read(key: 'db_user') ?? '',
              password: await storage.read(key: 'db_pass') ?? '',
              databaseName: await storage.read(key: 'db_name'),
              secure: false,
            );
            await _conn!.connect();

            if (_conn!.connected) {
              debugPrint('✅ [MySql] mDNS ($mDnsHost) work! Updating config.');
              await storage.write(key: 'db_host', value: mDnsHost);
              _connectionCompleter?.complete();
              return;
            }
          }
        } catch (innerE) {
          debugPrint('❌ mDNS Fallback failed: $innerE');
        }
      }

      // 🛡️ Self-Healing: Removed aggressive 127.0.0.1 fallback on Access Denied
      // If we got 1045 on a remote host, it means wrong password, not that they want to connect to themselves!
      if (e.toString().contains('1045')) {
        throw Exception(
            'Access Denied. Please check your Username and Password.\n(Error: ${e.toString()})');
      }

      debugPrint('❌ MySQL Connection Error: $e');
      _connectionCompleter?.completeError(e);
      rethrow;
    } finally {
      _isConnecting = false;
      _connectionCompleter = null;
    }
  }

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
    final Set<String> hostsToTry = {};

    // 🛡️ Auto-resolve hostname to IPv4 (for test Connection UI)
    if (host != 'localhost' &&
        host != '127.0.0.1' &&
        !RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
      try {
        final lookups = [host];
        if (!host.contains('.')) lookups.add('$host.local');
        for (var h in lookups) {
          bool resolved = false;
          try {
            final result = await InternetAddress.lookup(h)
                .timeout(const Duration(seconds: 2));
            for (var addr in result) {
              if (addr.type == InternetAddressType.IPv4) {
                hostsToTry.add(addr.address);
                resolved = true;
              }
            }
          } catch (_) {}

          // 🛡️ Fallback: Windows CMD Ping Resolution (bullet-proof for NetBIOS/hostname caching issues)
          String? pingIp;
          if (!resolved && Platform.isWindows) {
            pingIp = await _resolveWindowsHostname(h);
            if (pingIp != null) {
              hostsToTry.add(pingIp);
              debugPrint('✅ [MySql] Test Ping resolved $h to IP: $pingIp');
            }
          }

          // 🚀 Ultimate Fallback: Deep Subnet Scanner
          if (!resolved && pingIp == null) {
             final cleanHost = h.replaceAll('.local', '');
             debugPrint('⚠️ Network resolution blocked. Starting deep subnet scan for "$cleanHost"...');
             final scanIp = await _scanSubnetForHostname(cleanHost, port, user, pass, db);
             if (scanIp != null) {
                hostsToTry.add(scanIp);
                debugPrint('🎉 [MySql] Subnet Scanner found "$cleanHost" at IP: $scanIp');
             }
          }

          hostsToTry.add(h); // add hostname fallback
        }
      } catch (_) {}
    } else {
      hostsToTry.add(host);
    }

    // 🛡️ Smart Fallbacks
    if (host == 'localhost') hostsToTry.add('127.0.0.1');
    if (host == '127.0.0.1') hostsToTry.add('localhost');

    // mDNS Fallback: If it's a simple name like "MS-MAIN", try "MS-MAIN.local" as well
    if (!host.contains('.') && host != 'localhost' && host != '127.0.0.1') {
      hostsToTry.add('$host.local');
    }

    String? lastError;

    for (var currentHost in hostsToTry) {
      for (var isSecure in secureModes) {
        MySQLConnection? testConn;
        try {
          debugPrint(
              '🧪 [MySql] Testing connection: $currentHost:$port (Secure: $isSecure)');
          testConn = await MySQLConnection.createConnection(
            host: currentHost,
            port: port,
            userName: user,
            password: pass,
            databaseName: db.isEmpty ? null : db,
            secure: isSecure,
          );

          // Use a timeout for responsiveness
          await testConn.connect().timeout(const Duration(seconds: 5));
          if (testConn.connected) {
            debugPrint('✅ [MySql] Test Success: $currentHost');
            await testConn.close();
            return null; // Success
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint('❌ Test Failed ($currentHost, Secure: $isSecure): $e');
        } finally {
          try {
            await testConn?.close();
          } catch (_) {}
        }
      }
    }
    return lastError ?? 'Unknown Error';
  }

  // บันทึกการตั้งค่า
  // บันทึกการตั้งค่า (ลง SecureStorage)
  Future<void> saveConfig({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
    String? machineName,
  }) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'db_host', value: host);
    await storage.write(key: 'db_port', value: port.toString());
    await storage.write(key: 'db_user', value: user);
    await storage.write(key: 'db_pass', value: pass);
    await storage.write(key: 'db_name', value: db);
    if (machineName != null && machineName.isNotEmpty) {
      await storage.write(key: 'machine_name', value: machineName);
    }

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
      debugPrint('Error ensuring purchase_order columns: $e');
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
        debugPrint('   ✅ Added column: $columnName to $safeTable');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to ensure column $columnName in $table: $e');
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
      debugPrint('⚠️ ensureUserPermissionUniqueKey error: $e');
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
          debugPrint(
              '🔧 [MySQLService] Upgrading system_settings.setting_value: $dataType → MEDIUMTEXT');
          await execute(
              'ALTER TABLE system_settings MODIFY COLUMN setting_value MEDIUMTEXT');
          debugPrint(
              '✅ [MySQLService] system_settings.setting_value upgraded to MEDIUMTEXT');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [MySQLService] ensureSettingsColumnSize error: $e');
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
