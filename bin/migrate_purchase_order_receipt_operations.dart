// ignore_for_file: avoid_print

// Safe, rerunnable migration. Run: dart run bin/migrate_purchase_order_receipt_operations.dart
// It reads DB_* from environment or .env and never prints credentials.
import 'dart:convert';
import 'dart:io';

import 'package:mysql_client_plus/mysql_client_plus.dart';

const _table = 'purchase_order_receipt_operation';
const _lockName = 'pos_purchase_order_receipt_operations_v1';

Future<void> main() async {
  final started = DateTime.now().toUtc();
  final stamp = started.toIso8601String().replaceAll(':', '-');
  final reports = Directory(
      '${Directory.current.path}${Platform.pathSeparator}migration_reports');
  await reports.create(recursive: true);
  final reportFile = File(
      '${reports.path}${Platform.pathSeparator}purchase_order_receipt_operations_$stamp.json');
  final report = <String, dynamic>{
    'migration': 'purchase_order_receipt_operations_v1',
    'startedAtUtc': started.toIso8601String(),
    'status': 'started'
  };
  MySQLConnection? db;
  var locked = false;
  try {
    final config = await _config();
    db = await MySQLConnection.createConnection(
        host: config['host']!,
        port: int.parse(config['port']!),
        userName: config['user']!,
        password: config['password']!,
        databaseName: config['database']!);
    await db.connect();
    final lock = await db
        .execute('SELECT GET_LOCK(:name, 30) AS acquired', {'name': _lockName});
    locked = lock.rows.isNotEmpty && lock.rows.first.assoc()['acquired'] == '1';
    if (!locked) {
      throw StateError(
          'Another receipt-operation migration is already running.');
    }
    final source = await db.execute(
        "SELECT COUNT(*) AS count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'purchase_order'");
    if (source.rows.first.assoc()['count'] != '1') {
      throw StateError('purchase_order table is required.');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_order_receipt_operation (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        poId INT NOT NULL,
        operationKey VARCHAR(64) NOT NULL,
        payloadHash CHAR(64) NOT NULL,
        receiptMode ENUM('FULL', 'PARTIAL', 'CLOSE') NOT NULL,
        status ENUM('COMPLETED') NOT NULL DEFAULT 'COMPLETED',
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        completedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY idx_po_receipt_operation_key (operationKey),
        INDEX idx_po_receipt_operation_po (poId)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    ''');
    await db.execute('''
      ALTER TABLE purchase_order_receipt_operation
      MODIFY receiptMode ENUM('FULL', 'PARTIAL', 'CLOSE') NOT NULL
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_order_audit_log (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        poId INT NOT NULL,
        eventType VARCHAR(48) NOT NULL,
        operationKey VARCHAR(64) NULL,
        payloadJson LONGTEXT NOT NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_purchase_order_audit_po (poId),
        INDEX idx_purchase_order_audit_operation (operationKey)
      ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    ''');
    final verification = await db.execute('''
      SELECT COUNT(*) AS count FROM information_schema.statistics
      WHERE table_schema = DATABASE() AND table_name = :table
        AND index_name IN ('idx_po_receipt_operation_key', 'idx_po_receipt_operation_po')
    ''', {'table': _table});
    final indexCount =
        int.tryParse(verification.rows.first.assoc()['count'] ?? '') ?? 0;
    if (indexCount != 2) {
      throw StateError('Receipt-operation indexes failed verification.');
    }
    report['indexCount'] = indexCount;
    report['status'] = 'migrated_or_verified';
  } catch (error, stack) {
    report['status'] = 'failed';
    report['error'] = error.toString();
    report['stackTrace'] = stack.toString();
    exitCode = 1;
  } finally {
    if (locked && db != null) {
      try {
        await db.execute('SELECT RELEASE_LOCK(:name)', {'name': _lockName});
      } catch (_) {}
    }
    await db?.close();
    report['finishedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    await reportFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    print('Receipt operation migration report: ${reportFile.path}');
    print('Status: ${report['status']}');
  }
}

Future<Map<String, String>> _config() async {
  final values = <String, String>{
    'host': Platform.environment['DB_HOST'] ?? '127.0.0.1',
    'port': Platform.environment['DB_PORT'] ?? '3306',
    'user': Platform.environment['DB_USER'] ?? '',
    'password': Platform.environment['DB_PASS'] ?? '',
    'database': Platform.environment['DB_NAME'] ?? '',
  };
  final env = File('${Directory.current.path}${Platform.pathSeparator}.env');
  if (await env.exists()) {
    for (final raw in await env.readAsLines()) {
      final line = raw.trim();
      final split = line.indexOf('=');
      if (line.isEmpty || line.startsWith('#') || split < 1) continue;
      final target = {
        'DB_HOST': 'host',
        'DB_PORT': 'port',
        'DB_USER': 'user',
        'DB_PASS': 'password',
        'DB_NAME': 'database'
      }[line.substring(0, split).trim()];
      var value = line.substring(split + 1).trim();
      if (value.length > 1 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      if (target != null && values[target]!.isEmpty) {
        values[target] = value;
      }
    }
  }
  if (values['user']!.isEmpty ||
      values['database']!.isEmpty ||
      int.tryParse(values['port']!) == null) {
    throw StateError(
        'Set valid DB_USER, DB_NAME and DB_PORT in .env or environment variables.');
  }
  return values;
}
