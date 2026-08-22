// ignore_for_file: avoid_print

// Safe, rerunnable database migration. Run: dart run bin/migrate_barcode_registry.dart
// Reads DB_* from environment or the workspace .env; credentials are never printed.
import 'dart:convert';
import 'dart:io';

import 'package:mysql_client_plus/mysql_client_plus.dart';

const _lockName = 'pos_barcode_registry_migration_v1';
const _registry = 'barcode_registry';
const _triggers = <String>[
  'trg_product_registry_ai',
  'trg_product_barcode_registry_bu_primary',
  'trg_product_barcode_registry_au_primary',
  'trg_product_barcode_registry_ad_product',
  'trg_product_barcode_registry_ai',
  'trg_product_barcode_registry_bu',
  'trg_product_barcode_registry_au',
  'trg_product_barcode_registry_ad',
];

Future<void> main() async {
  final started = DateTime.now().toUtc();
  final stamp = started.toIso8601String().replaceAll(':', '-');
  final reports = Directory(
      '${Directory.current.path}${Platform.pathSeparator}migration_reports');
  await reports.create(recursive: true);
  final reportFile = File(
      '${reports.path}${Platform.pathSeparator}barcode_registry_migration_$stamp.json');
  final report = <String, dynamic>{
    'migration': 'barcode_registry_v1',
    'startedAtUtc': started.toIso8601String(),
    'status': 'started',
    'databaseChanged': false,
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
    locked = await _lock(db);
    if (!locked) {
      throw StateError(
          'Another barcode-registry migration is already running.');
    }
    await _requireSourceTables(db);

    final source = await _readSource(db);
    final collisions = _collisions(source);
    report['sourceCounts'] = source.counts;
    report['collisionCount'] = collisions.length;
    report['collisions'] = collisions;
    if (collisions.isNotEmpty) {
      throw StateError(
          'Duplicate audit found ${collisions.length} collision group(s); no DDL was run.');
    }

    final installed = await _installationState(db);
    report['installationStateBefore'] = installed;
    if (installed['complete'] == true) {
      final verification = await _verify(db, source);
      report['verification'] = verification;
      if (verification['ok'] != true) {
        throw StateError(
            'Existing registry failed verification; no repair was attempted.');
      }
      report['status'] = 'already_installed_verified';
      return;
    }
    if (installed['tableExists'] == true ||
        (installed['triggers'] as List).isNotEmpty) {
      throw StateError(
          'Partial registry installation found; no automatic repair was attempted.');
    }

    final snapshot = await _snapshot(source, stamp);
    report['snapshotFile'] = snapshot.path;
    await _createTable(db);
    await _backfill(db);
    await _createTriggers(db);
    report['databaseChanged'] = true;
    final verification = await _verify(db, source);
    report['verification'] = verification;
    if (verification['ok'] != true) {
      throw StateError(
          'Post-migration verification failed; review before new barcode writes.');
    }
    report['status'] = 'migrated_verified';
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
    await reportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
        encoding: utf8);
    print('Barcode registry migration report: ${reportFile.path}');
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
  final file = File('${Directory.current.path}${Platform.pathSeparator}.env');
  if (await file.exists()) {
    for (final raw in await file.readAsLines()) {
      final line = raw.trim();
      final split = line.indexOf('=');
      if (line.isEmpty || line.startsWith('#') || split < 1) {
        continue;
      }
      final key = line.substring(0, split).trim();
      var value = line.substring(split + 1).trim();
      if (value.length > 1 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      final map = {
        'DB_HOST': 'host',
        'DB_PORT': 'port',
        'DB_USER': 'user',
        'DB_PASS': 'password',
        'DB_NAME': 'database'
      };
      final target = map[key];
      if (target != null &&
          (values[target]!.isEmpty ||
              (target == 'host' && values[target] == '127.0.0.1') ||
              (target == 'port' && values[target] == '3306'))) {
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

Future<bool> _lock(MySQLConnection db) async {
  final result = await db
      .execute('SELECT GET_LOCK(:name, 30) AS acquired', {'name': _lockName});
  return result.rows.isNotEmpty && result.rows.first.assoc()['acquired'] == '1';
}

Future<void> _requireSourceTables(MySQLConnection db) async {
  final result = await db.execute(
      "SELECT COUNT(*) AS count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ('product', 'product_barcode')");
  final count = int.tryParse(result.rows.first.assoc()['count'] ?? '') ?? 0;
  if (count != 2) {
    throw StateError(
        'Required source tables product and product_barcode must exist.');
  }
}

Future<_Source> _readSource(MySQLConnection db) async {
  final primary = await db.execute(
      "SELECT id, barcode FROM product WHERE barcode IS NOT NULL AND TRIM(barcode) <> '' ORDER BY id");
  final unit = await db.execute(
      "SELECT id, productId, barcode, unitName, price, quantity FROM product_barcode WHERE barcode IS NOT NULL AND TRIM(barcode) <> '' ORDER BY id");
  return _Source(primary.rows.map((row) => row.assoc()).toList(),
      unit.rows.map((row) => row.assoc()).toList());
}

String _norm(String value) => value.trim().toUpperCase();

List<Map<String, dynamic>> _collisions(_Source source) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  void add(String kind, Map<String, dynamic> row) {
    final barcode = row['barcode']!.toString().trim();
    grouped.putIfAbsent(_norm(barcode), () => []).add({
      'source': kind,
      'sourceRowId': row['id'],
      'productId': row['productId'] ?? row['id'],
      'barcode': barcode
    });
  }

  for (final row in source.primary) {
    add('primary', row);
  }
  for (final row in source.unit) {
    add('unit', row);
  }
  final result = grouped.entries
      .where((entry) => entry.value.length > 1)
      .map((entry) => <String, dynamic>{
            'normalizedBarcode': entry.key,
            'entries': entry.value
          })
      .toList();
  result.sort((a, b) => (a['normalizedBarcode'] as String)
      .compareTo(b['normalizedBarcode'] as String));
  return result;
}

Future<Map<String, dynamic>> _installationState(MySQLConnection db) async {
  final table = await db.execute(
      'SELECT COUNT(*) AS count FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = :table',
      {'table': _registry});
  final names = _triggers.map((name) => "'$name'").join(', ');
  final triggerRows = await db.execute(
      'SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema = DATABASE() AND trigger_name IN ($names) ORDER BY trigger_name');
  // information_schema field-name casing varies by MySQL server/driver.
  final triggers = triggerRows.rows
      .map((row) => row.assoc().values.first)
      .whereType<String>()
      .toList();
  final tableExists = table.rows.first.assoc()['count'] == '1';
  return {
    'tableExists': tableExists,
    'triggers': triggers,
    'complete': tableExists && triggers.length == _triggers.length
  };
}

Future<File> _snapshot(_Source source, String stamp) async {
  final directory = Directory(
      '${Directory.current.path}${Platform.pathSeparator}backups${Platform.pathSeparator}barcode_registry');
  await directory.create(recursive: true);
  final file = File(
      '${directory.path}${Platform.pathSeparator}barcode_registry_source_snapshot_$stamp.json');
  await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
        'purpose': 'Pre-DDL snapshot for barcode_registry migration',
        'productIdAndBarcodeRows': source.primary,
        'productBarcodeRows': source.unit,
      }),
      encoding: utf8);
  return file;
}

Future<void> _createTable(MySQLConnection db) => db.execute('''
  CREATE TABLE barcode_registry (
    id BIGINT NOT NULL AUTO_INCREMENT, barcode VARCHAR(100) NOT NULL,
    normalizedBarcode VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
    productId INT NOT NULL, source ENUM('primary', 'unit') NOT NULL, sourceRowId INT NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_barcode_registry_normalized (normalizedBarcode),
    UNIQUE KEY uq_barcode_registry_source_row (source, sourceRowId), KEY idx_barcode_registry_product (productId)
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
''');

Future<void> _backfill(MySQLConnection db) async {
  await db.execute(
      "INSERT INTO barcode_registry (barcode, normalizedBarcode, productId, source, sourceRowId) SELECT TRIM(barcode), UPPER(TRIM(barcode)), id, 'primary', id FROM product WHERE barcode IS NOT NULL AND TRIM(barcode) <> ''");
  await db.execute(
      "INSERT INTO barcode_registry (barcode, normalizedBarcode, productId, source, sourceRowId) SELECT TRIM(barcode), UPPER(TRIM(barcode)), productId, 'unit', id FROM product_barcode WHERE barcode IS NOT NULL AND TRIM(barcode) <> ''");
}

Future<void> _createTriggers(MySQLConnection db) async {
  await db.execute(
      "CREATE TRIGGER trg_product_registry_ai AFTER INSERT ON product FOR EACH ROW INSERT INTO barcode_registry (barcode, normalizedBarcode, productId, source, sourceRowId) SELECT TRIM(NEW.barcode), UPPER(TRIM(NEW.barcode)), NEW.id, 'primary', NEW.id WHERE NEW.barcode IS NOT NULL AND TRIM(NEW.barcode) <> ''");
  await db.execute(
      "CREATE TRIGGER trg_product_barcode_registry_bu_primary BEFORE UPDATE ON product FOR EACH ROW DELETE FROM barcode_registry WHERE source = 'primary' AND sourceRowId = OLD.id AND (NOT (COALESCE(TRIM(OLD.barcode), '') <=> COALESCE(TRIM(NEW.barcode), '')) OR NOT (OLD.id <=> NEW.id))");
  await db.execute(
      "CREATE TRIGGER trg_product_barcode_registry_au_primary AFTER UPDATE ON product FOR EACH ROW INSERT INTO barcode_registry (barcode, normalizedBarcode, productId, source, sourceRowId) SELECT TRIM(NEW.barcode), UPPER(TRIM(NEW.barcode)), NEW.id, 'primary', NEW.id WHERE NEW.barcode IS NOT NULL AND TRIM(NEW.barcode) <> '' AND (NOT (COALESCE(TRIM(OLD.barcode), '') <=> COALESCE(TRIM(NEW.barcode), '')) OR NOT (OLD.id <=> NEW.id))");
  await db.execute(
      "CREATE TRIGGER trg_product_barcode_registry_ad_product AFTER DELETE ON product FOR EACH ROW DELETE FROM barcode_registry WHERE productId = OLD.id");
  await db.execute(
      "CREATE TRIGGER trg_product_barcode_registry_ai AFTER INSERT ON product_barcode FOR EACH ROW INSERT INTO barcode_registry (barcode, normalizedBarcode, productId, source, sourceRowId) SELECT TRIM(NEW.barcode), UPPER(TRIM(NEW.barcode)), NEW.productId, 'unit', NEW.id WHERE NEW.barcode IS NOT NULL AND TRIM(NEW.barcode) <> ''");
  await db.execute(
      "CREATE TRIGGER trg_product_barcode_registry_bu BEFORE UPDATE ON product_barcode FOR EACH ROW DELETE FROM barcode_registry WHERE source = 'unit' AND sourceRowId = OLD.id AND (NOT (COALESCE(TRIM(OLD.barcode), '') <=> COALESCE(TRIM(NEW.barcode), '')) OR NOT (OLD.productId <=> NEW.productId))");
  await db.execute(
      "CREATE TRIGGER trg_product_barcode_registry_au AFTER UPDATE ON product_barcode FOR EACH ROW INSERT INTO barcode_registry (barcode, normalizedBarcode, productId, source, sourceRowId) SELECT TRIM(NEW.barcode), UPPER(TRIM(NEW.barcode)), NEW.productId, 'unit', NEW.id WHERE NEW.barcode IS NOT NULL AND TRIM(NEW.barcode) <> '' AND (NOT (COALESCE(TRIM(OLD.barcode), '') <=> COALESCE(TRIM(NEW.barcode), '')) OR NOT (OLD.productId <=> NEW.productId))");
  await db.execute(
      "CREATE TRIGGER trg_product_barcode_registry_ad AFTER DELETE ON product_barcode FOR EACH ROW DELETE FROM barcode_registry WHERE source = 'unit' AND sourceRowId = OLD.id");
}

Future<Map<String, dynamic>> _verify(MySQLConnection db, _Source source) async {
  final count =
      await db.execute('SELECT COUNT(*) AS count FROM barcode_registry');
  final registryCount = int.parse(count.rows.first.assoc()['count']!);
  final mismatch = await db.execute(
      "SELECT COUNT(*) AS count FROM (SELECT p.id FROM product p LEFT JOIN barcode_registry r ON r.source = 'primary' AND r.sourceRowId = p.id AND r.normalizedBarcode = UPPER(TRIM(p.barcode)) WHERE p.barcode IS NOT NULL AND TRIM(p.barcode) <> '' AND r.id IS NULL UNION ALL SELECT pb.id FROM product_barcode pb LEFT JOIN barcode_registry r ON r.source = 'unit' AND r.sourceRowId = pb.id AND r.normalizedBarcode = UPPER(TRIM(pb.barcode)) WHERE pb.barcode IS NOT NULL AND TRIM(pb.barcode) <> '' AND r.id IS NULL) AS mismatches");
  final mismatchCount = int.parse(mismatch.rows.first.assoc()['count']!);
  final expected = source.primary.length + source.unit.length;
  return {
    'sourceNonBlankBarcodeCount': expected,
    'registryCount': registryCount,
    'sourceRegistryMismatchCount': mismatchCount,
    'ok': expected == registryCount && mismatchCount == 0
  };
}

class _Source {
  const _Source(this.primary, this.unit);
  final List<Map<String, dynamic>> primary;
  final List<Map<String, dynamic>> unit;
  Map<String, int> get counts => {
        'primary': primary.length,
        'unit': unit.length,
        'total': primary.length + unit.length
      };
}
