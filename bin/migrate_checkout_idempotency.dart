// ignore_for_file: avoid_print

// Safe, rerunnable schema migration for checkout and new purchase-order keys.
// Run: dart run bin/migrate_checkout_idempotency.dart
import 'dart:convert';
import 'dart:io';

import 'package:mysql_client_plus/mysql_client_plus.dart';

const _lockName = 'pos_checkout_idempotency_v1';

Future<void> main() async {
  final report = <String, dynamic>{
    'migration': 'checkout_idempotency_v1',
    'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'databaseChanged': false,
  };
  final reportDirectory = Directory(
      '${Directory.current.path}${Platform.pathSeparator}migration_reports');
  await reportDirectory.create(recursive: true);
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final reportFile = File(
      '${reportDirectory.path}${Platform.pathSeparator}checkout_idempotency_$stamp.json');
  MySQLConnection? db;
  var locked = false;
  try {
    final config = await _config();
    db = await MySQLConnection.createConnection(
      host: config['host']!,
      port: int.parse(config['port']!),
      userName: config['user']!,
      password: config['password']!,
      databaseName: config['database']!,
    );
    await db.connect();
    final lock = await db
        .execute('SELECT GET_LOCK(:name, 30) AS acquired', {'name': _lockName});
    locked = lock.rows.isNotEmpty && lock.rows.first.assoc()['acquired'] == '1';
    if (!locked) {
      throw StateError('Another checkout idempotency migration is running.');
    }

    for (final table in ['order', 'purchase_order']) {
      final exists = await db.execute('''
        SELECT COUNT(*) AS count FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = :table
      ''', {'table': table});
      if (exists.rows.first.assoc()['count'] != '1') {
        throw StateError('Required table `$table` does not exist.');
      }
      await _ensureColumn(db, table, 'idempotencyKey', 'VARCHAR(64) NULL');
      await _ensureColumn(db, table, 'idempotencyPayloadHash', 'CHAR(64) NULL');
      final duplicates = await db.execute('''
        SELECT idempotencyKey, COUNT(*) AS count FROM `$table`
        WHERE idempotencyKey IS NOT NULL AND idempotencyKey <> ''
        GROUP BY idempotencyKey HAVING COUNT(*) > 1 LIMIT 1
      ''');
      if (duplicates.rows.isNotEmpty) {
        final row = duplicates.rows.first.assoc();
        throw StateError(
            'Duplicate existing key in `$table`: ${row['idempotencyKey']} (${row['count']} rows). No index was added.');
      }
      final indexName = table == 'order'
          ? 'idx_order_idempotency'
          : 'idx_purchase_order_idempotency';
      final index = await db.execute('''
        SELECT COUNT(*) AS count FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = :table AND index_name = :index
      ''', {'table': table, 'index': indexName});
      if (index.rows.first.assoc()['count'] != '1') {
        await db.execute(
            'ALTER TABLE `$table` ADD UNIQUE KEY `$indexName` (idempotencyKey)');
        report['databaseChanged'] = true;
      }
    }
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
    print('Checkout idempotency migration report: ${reportFile.path}');
    print('Status: ${report['status']}');
  }
}

Future<void> _ensureColumn(
    MySQLConnection db, String table, String column, String definition) async {
  final columns = await db
      .execute('SHOW COLUMNS FROM `$table` LIKE :column', {'column': column});
  if (columns.rows.isEmpty) {
    await db.execute('ALTER TABLE `$table` ADD COLUMN `$column` $definition');
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
      final equals = raw.indexOf('=');
      if (equals < 1 || raw.trimLeft().startsWith('#')) continue;
      final name = raw.substring(0, equals).trim();
      final target = {
        'DB_HOST': 'host',
        'DB_PORT': 'port',
        'DB_USER': 'user',
        'DB_PASS': 'password',
        'DB_NAME': 'database'
      }[name];
      if (target != null && values[target]!.isEmpty) {
        var value = raw.substring(equals + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith('"') && value.endsWith('"')) ||
                (value.startsWith("'") && value.endsWith("'")))) {
          value = value.substring(1, value.length - 1);
        }
        values[target] = value;
      }
    }
  }
  if (values['user']!.isEmpty ||
      values['database']!.isEmpty ||
      int.tryParse(values['port']!) == null) {
    throw StateError(
        'Set DB_USER, DB_NAME and DB_PORT in .env or environment variables.');
  }
  return values;
}
