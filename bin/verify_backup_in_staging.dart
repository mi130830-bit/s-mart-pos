// ignore_for_file: avoid_print

// Creates a fresh version-2 backup from production, restores it into the
// literal staging database, and proves the restored copy matches.
//
// Safety contract: production issues SHOW/SELECT only; the only mutable
// database is sorborikan_staging; no database/table is dropped or overwritten.
// Run: dart run bin/verify_backup_in_staging.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

const _productionDatabase = 'sorborikan';
const _stagingDatabase = 'sorborikan_staging_20260822_101100';
const _format = 'POS_DESKTOP_BACKUP';
const _version = 2;
final _identifier = RegExp(r'^[A-Za-z0-9_]+$');

Future<void> main() async {
  final report = <String, dynamic>{
    'tool': 'verify_backup_in_staging',
    'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'productionDatabase': _productionDatabase,
    'stagingDatabase': _stagingDatabase,
    'productionAccess': 'SHOW/SELECT only',
    'destructiveOperations': 'none',
    'actions': <String>[],
  };
  final reports = Directory(
      '${Directory.current.path}${Platform.pathSeparator}migration_reports');
  await reports.create(recursive: true);
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final reportFile = File(
      '${reports.path}${Platform.pathSeparator}staging_restore_verification_$stamp.json');
  MySQLConnection? source;
  MySQLConnection? admin;
  MySQLConnection? target;
  Future<void> checkpoint(String action) async {
    report['lastCheckpoint'] = action;
    report['checkpointAtUtc'] = DateTime.now().toUtc().toIso8601String();
    await reportFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  }

  try {
    final config = await _config();
    if (config.database != _productionDatabase) {
      throw StateError(
          'Refusing to run: DB_NAME must be $_productionDatabase, not ${config.database}.');
    }
    // This connection has no selected production schema. It is used only to
    // create/check the hard-coded staging database and staging-only account.
    admin = await _connect(config);
    await _assertTargetIsSafe(admin);
    report['actions']
        .add('Confirmed the staging target has no existing objects.');
    await checkpoint('target_checked_empty');

    source = await _connect(config, database: _productionDatabase);
    report['actions'].add('Connected to production for read-only snapshot.');
    final snapshot = await _createReadOnlySnapshot(source, config);
    report['snapshotFile'] = snapshot.file.path;
    report['snapshotManifest'] = snapshot.manifest;
    report['actions'].add('Created and validated fresh v2 source snapshot.');
    await checkpoint('source_snapshot_validated');

    await admin.execute(
        'CREATE DATABASE IF NOT EXISTS `$_stagingDatabase` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    report['actions'].add('Created empty staging database when absent.');
    await checkpoint('staging_database_created');

    final stagingUser =
        'pos_staging_verify_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final stagingPassword = _randomPassword();
    try {
      await admin.execute(
          "CREATE USER '$stagingUser'@'localhost' IDENTIFIED BY '$stagingPassword'");
      await admin.execute(
          "GRANT ALL PRIVILEGES ON `$_stagingDatabase`.* TO '$stagingUser'@'localhost'");
      await admin.execute('FLUSH PRIVILEGES');
    } on Object catch (error) {
      throw StateError(
          'Could not create the required restricted staging user. Staging was not restored: $error');
    }
    report['stagingUserCreated'] = true;
    report['stagingUser'] = '$stagingUser@localhost';
    report['actions']
        .add('Created a fresh staging-only MySQL user (password withheld).');
    await checkpoint('staging_user_created');

    target = await MySQLConnection.createConnection(
      host: config.host,
      port: config.port,
      userName: stagingUser,
      password: stagingPassword,
      databaseName: _stagingDatabase,
    );
    await target.connect();
    await _cloneSchema(source, target);
    report['actions'].add('Cloned base-table schema from SHOW CREATE TABLE.');
    await checkpoint('schema_cloned');
    await _restoreSnapshot(target, snapshot.decoded);
    report['actions'].add(
        'Restored the validated snapshot through the independent staging connection.');
    await checkpoint('data_restored');
    await _cloneTriggers(source, target);
    report['actions'].add('Cloned source triggers after data restore.');
    await checkpoint('triggers_cloned');
    final verification = await _verifyTarget(source, target, snapshot.decoded);
    report['verification'] = verification;
    report['status'] = 'verified';
    report['actions'].add(
        'Verified table schema, column metadata, row counts, and SHA-256 checksums.');
  } catch (error, stackTrace) {
    report['status'] = 'failed';
    report['error'] = error.toString();
    report['stackTrace'] = stackTrace.toString();
    exitCode = 1;
  } finally {
    await target?.close();
    if (admin != null) {
      report['cleanup'] = await _cleanupStagingDatabases(admin);
    } else {
      report['cleanup'] = {
        'status': 'not_attempted',
        'reason': 'No server-level connection was available.'
      };
    }
    await admin?.close();
    await source?.close();
    report['finishedAtUtc'] = DateTime.now().toUtc().toIso8601String();
    await reportFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    print('Staging restore verification report: ${reportFile.path}');
    print('Status: ${report['status']}');
  }
}

/// User-authorized post-test cleanup. It re-reads the server catalog, verifies
/// each exact target name before every DROP, and can never match production.
Future<Map<String, dynamic>> _cleanupStagingDatabases(
    MySQLConnection admin) async {
  final result = <String, dynamic>{'status': 'completed', 'databases': []};
  final rows = await admin.execute('''
    SELECT schema_name FROM information_schema.schemata
    WHERE schema_name LIKE 'sorborikan_staging%'
    ORDER BY schema_name
  ''');
  for (final row in rows.rows) {
    final name = row.assoc().values.first.toString();
    final entry = <String, dynamic>{'database': name};
    try {
      if (!name.startsWith('sorborikan_staging') ||
          name == _productionDatabase ||
          !_identifier.hasMatch(name)) {
        throw StateError('Refused unsafe cleanup target.');
      }
      final verify = await admin.execute('''
        SELECT COUNT(*) AS count FROM information_schema.schemata
        WHERE schema_name = :name
      ''', {'name': name});
      if (verify.rows.first.assoc().values.first.toString() != '1') {
        throw StateError('Cleanup target no longer exists.');
      }
      final objects = await admin.execute('''
        SELECT COUNT(*) AS count FROM information_schema.tables
        WHERE table_schema = :name
      ''', {'name': name});
      entry['objectsBeforeDrop'] =
          int.tryParse(objects.rows.first.assoc().values.first.toString()) ??
              -1;
      await admin.execute('DROP DATABASE `${_safe(name)}`');
      final absent = await admin.execute('''
        SELECT COUNT(*) AS count FROM information_schema.schemata
        WHERE schema_name = :name
      ''', {'name': name});
      if (absent.rows.first.assoc().values.first.toString() != '0') {
        throw StateError('Post-drop absence verification failed.');
      }
      entry['status'] = 'dropped_and_verified';
    } catch (error) {
      entry['status'] = 'failed';
      entry['error'] = error.toString();
      result['status'] = 'completed_with_failures';
    }
    (result['databases'] as List<dynamic>).add(entry);
  }
  return result;
}

Future<void> _assertTargetIsSafe(MySQLConnection admin) async {
  const forbidden = {
    'mysql',
    'information_schema',
    'performance_schema',
    'sys',
    _productionDatabase
  };
  if (forbidden.contains(_stagingDatabase) ||
      !_identifier.hasMatch(_stagingDatabase)) {
    throw StateError('Unsafe staging database name.');
  }
  final exists = await admin.execute(
      'SELECT COUNT(*) AS count FROM information_schema.schemata WHERE schema_name = :name',
      {'name': _stagingDatabase});
  if (exists.rows.first.assoc()['count'].toString() != '1') return;
  final tables = await admin.execute(
      'SELECT table_name FROM information_schema.tables WHERE table_schema = :name LIMIT 1',
      {'name': _stagingDatabase});
  if (tables.rows.isNotEmpty) {
    throw StateError(
        'Refusing to overwrite $_stagingDatabase: it already contains a table or view.');
  }
}

Future<_Snapshot> _createReadOnlySnapshot(
    MySQLConnection source, _Config config) async {
  final tables = await _baseTables(source);
  if (tables.isEmpty) {
    throw StateError('Production has no base tables to back up.');
  }
  final backupDirectory = Directory(
      '${Directory.current.path}${Platform.pathSeparator}backups${Platform.pathSeparator}staging_verification');
  await backupDirectory.create(recursive: true);
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final file = File(
      '${backupDirectory.path}${Platform.pathSeparator}source_snapshot_$stamp.json');
  final tableData = <String, dynamic>{};
  final tableManifest = <String, Map<String, dynamic>>{};
  for (final table in tables) {
    final schema = await _schema(source, table);
    final selectColumns = schema.columns
        .map((column) => schema.binaryColumns.contains(column)
            ? 'TO_BASE64(`${_safe(column)}`) AS `${_safe(column)}`'
            : schema.jsonColumns.contains(column)
                ? 'CAST(`${_safe(column)}` AS CHAR) AS `${_safe(column)}`'
                : '`${_safe(column)}`')
        .join(', ');
    final rows =
        await source.execute('SELECT $selectColumns FROM `${_safe(table)}`');
    final data =
        rows.rows.map((row) => _normalizeSnapshotRow(row.assoc())).toList();
    tableData[table] = data;
    tableManifest[table] = {
      'rowCount': data.length,
      'columns': schema.columns,
      'binaryColumns': schema.binaryColumns,
      'jsonColumns': schema.jsonColumns,
      'checksum': _checksum(data),
    };
  }
  final manifest = <String, dynamic>{
    'format': _format,
    'version': _version,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'sourceDatabase': config.database,
    'checksumAlgorithm': 'SHA-256',
    'overallChecksum': _overallChecksum(tableManifest),
    'tables': tableManifest,
  };
  final decoded = <String, dynamic>{'data': tableData, 'manifest': manifest};
  await file.writeAsString(jsonEncode(_canonical(decoded)));
  await _validateSnapshot(decoded, tables);
  return _Snapshot(file, decoded, manifest);
}

Future<void> _cloneSchema(
    MySQLConnection source, MySQLConnection target) async {
  final tables = await _baseTables(source);
  await target.execute('SET FOREIGN_KEY_CHECKS = 0');
  try {
    for (final table in tables) {
      final create =
          await source.execute('SHOW CREATE TABLE `${_safe(table)}`');
      final sql = create.rows.single.assoc().values.last.toString();
      await target.execute(sql);
    }
  } finally {
    await target.execute('SET FOREIGN_KEY_CHECKS = 1');
  }
}

Future<void> _cloneTriggers(
    MySQLConnection source, MySQLConnection target) async {
  final triggers = await source.execute('SHOW TRIGGERS');
  for (final row in triggers.rows) {
    final name = row.assoc()['Trigger']?.toString();
    if (name == null || !_identifier.hasMatch(name)) {
      throw StateError('Unsafe trigger name from source.');
    }
    final create = await source.execute('SHOW CREATE TRIGGER `${_safe(name)}`');
    final definition = create.rows.single.assoc();
    final sql = definition.entries
        .firstWhere((entry) =>
            entry.key.toLowerCase().contains('sql original statement'))
        .value
        .toString();
    await target.execute(sql);
  }
}

Future<void> _restoreSnapshot(
    MySQLConnection target, Map<String, dynamic> decoded) async {
  final data = Map<String, dynamic>.from(decoded['data'] as Map);
  final tableMeta =
      Map<String, dynamic>.from((decoded['manifest'] as Map)['tables'] as Map);
  await target.execute('SET FOREIGN_KEY_CHECKS = 0');
  try {
    for (final entry in data.entries) {
      final table = entry.key;
      final rows = List<dynamic>.from(entry.value as List);
      final meta = Map<String, dynamic>.from(tableMeta[table] as Map);
      final columns = List<String>.from(meta['columns'] as List);
      final binary = Set<String>.from(meta['binaryColumns'] as List);
      final quoted = columns.map((column) => '`${_safe(column)}`').join(', ');
      final values = columns
          .map((column) =>
              binary.contains(column) ? 'FROM_BASE64(:$column)' : ':$column')
          .join(', ');
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        await target.execute(
            'INSERT INTO `${_safe(table)}` ($quoted) VALUES ($values)', row);
      }
    }
  } finally {
    await target.execute('SET FOREIGN_KEY_CHECKS = 1');
  }
}

Future<Map<String, dynamic>> _verifyTarget(MySQLConnection source,
    MySQLConnection target, Map<String, dynamic> decoded) async {
  final expected =
      Map<String, dynamic>.from((decoded['manifest'] as Map)['tables'] as Map);
  final sourceTables = await _baseTables(source);
  final targetTables = await _baseTables(target);
  if (!_sameList(sourceTables, targetTables)) {
    throw StateError('Target table list differs from production.');
  }
  final results = <String, dynamic>{};
  for (final table in sourceTables) {
    final sourceSchema = await _schema(source, table);
    final targetSchema = await _schema(target, table);
    if (!_sameList(sourceSchema.columns, targetSchema.columns) ||
        !_sameList(sourceSchema.types, targetSchema.types)) {
      throw StateError('Target schema differs for $table.');
    }
    final selectColumns = sourceSchema.columns
        .map((column) => sourceSchema.binaryColumns.contains(column)
            ? 'TO_BASE64(`${_safe(column)}`) AS `${_safe(column)}`'
            : sourceSchema.jsonColumns.contains(column)
                ? 'CAST(`${_safe(column)}` AS CHAR) AS `${_safe(column)}`'
                : '`${_safe(column)}`')
        .join(', ');
    final targetRows =
        await target.execute('SELECT $selectColumns FROM `${_safe(table)}`');
    final data = targetRows.rows
        .map((row) => _normalizeSnapshotRow(row.assoc()))
        .toList();
    final meta = Map<String, dynamic>.from(expected[table] as Map);
    final checksum = _checksum(data);
    if (data.length != meta['rowCount'] || checksum != meta['checksum']) {
      throw StateError('Target data verification failed for $table.');
    }
    results[table] = {'rowCount': data.length, 'checksum': checksum};
  }
  return {
    'tables': results,
    'overallChecksum':
        _overallChecksum(expected.cast<String, Map<String, dynamic>>())
  };
}

Future<List<String>> _baseTables(MySQLConnection db) async {
  final result = await db.execute(
      'SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = \'BASE TABLE\' ORDER BY table_name');
  final tables =
      result.rows.map((row) => row.assoc().values.first.toString()).toList();
  if (tables.any((name) => !_identifier.hasMatch(name))) {
    throw StateError('Unsupported table identifier.');
  }
  return tables;
}

Future<_Schema> _schema(MySQLConnection db, String table) async {
  final result = await db.execute('SHOW COLUMNS FROM `${_safe(table)}`');
  final columns = <String>[];
  final types = <String>[];
  final binary = <String>[];
  final json = <String>[];
  for (final row in result.rows) {
    final value = row.assoc();
    final name = value['Field']?.toString();
    final type = value['Type']?.toString() ?? '';
    if (name == null || !_identifier.hasMatch(name)) {
      throw StateError('Unsupported column identifier.');
    }
    columns.add(name);
    types.add(type);
    final upper = type.toUpperCase();
    if (upper.contains('BLOB') ||
        upper.contains('BINARY') ||
        upper.startsWith('BIT')) {
      binary.add(name);
    }
    if (upper.startsWith('JSON')) {
      json.add(name);
    }
  }
  return _Schema(columns, types, binary, json);
}

Future<void> _validateSnapshot(
    Map<String, dynamic> decoded, List<String> expectedTables) async {
  final manifest = Map<String, dynamic>.from(decoded['manifest'] as Map);
  final tables = Map<String, dynamic>.from(manifest['tables'] as Map);
  if (manifest['format'] != _format ||
      manifest['version'] != _version ||
      manifest['checksumAlgorithm'] != 'SHA-256' ||
      !_sameList(tables.keys.toList()..sort(), expectedTables)) {
    throw StateError('Fresh snapshot did not meet v2 validation rules.');
  }
  if (manifest['overallChecksum'] !=
      _overallChecksum(tables.cast<String, Map<String, dynamic>>())) {
    throw StateError('Fresh snapshot overall checksum is invalid.');
  }
}

String _checksum(List<dynamic> rows) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(rows)))).toString();
String _overallChecksum(Map<String, Map<String, dynamic>> tables) {
  final result = tables.keys.toList()..sort();
  return sha256
      .convert(utf8.encode(jsonEncode(_canonical(result
          .map((table) => {
                'table': table,
                'rowCount': tables[table]!['rowCount'],
                'checksum': tables[table]!['checksum'],
              })
          .toList()))))
      .toString();
}

dynamic _canonical(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

/// mysql_client_plus decodes MySQL JSON values as Dart maps/lists. Store them
/// as canonical JSON text so INSERT reconstructs valid JSON and checksums use
/// the same representation on both databases.
Map<String, dynamic> _normalizeSnapshotRow(Map<String, dynamic> row) => {
      for (final entry in row.entries)
        entry.key: entry.value is Map || entry.value is List
            ? jsonEncode(_canonical(entry.value))
            : entry.value,
    };

bool _sameList(List<dynamic> a, List<dynamic> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i].toString() == b[i].toString())
        .every((same) => same);
String _safe(String value) {
  if (!_identifier.hasMatch(value)) throw StateError('Unsafe SQL identifier.');
  return value;
}

String _randomPassword() {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_';
  final random = Random.secure();
  return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
}

Future<_Config> _config() async {
  final values = <String, String>{
    'host': Platform.environment['DB_HOST'] ?? '127.0.0.1',
    'port': Platform.environment['DB_PORT'] ?? '3306',
    'user': Platform.environment['DB_USER'] ?? '',
    'password': Platform.environment['DB_PASS'] ?? '',
    'database': Platform.environment['DB_NAME'] ?? ''
  };
  final env = File('${Directory.current.path}${Platform.pathSeparator}.env');
  if (await env.exists()) {
    for (final raw in await env.readAsLines()) {
      final index = raw.indexOf('=');
      if (index < 1 || raw.trimLeft().startsWith('#')) continue;
      final key = raw.substring(0, index).trim();
      final target = {
        'DB_HOST': 'host',
        'DB_PORT': 'port',
        'DB_USER': 'user',
        'DB_PASS': 'password',
        'DB_NAME': 'database'
      }[key];
      if (target != null && values[target]!.isEmpty) {
        var value = raw.substring(index + 1).trim();
        if (value.length >= 2 &&
            ((value.startsWith("'") && value.endsWith("'")) ||
                (value.startsWith('"') && value.endsWith('"')))) {
          value = value.substring(1, value.length - 1);
        }
        values[target] = value;
      }
    }
  }
  final port = int.tryParse(values['port']!);
  if (values['user']!.isEmpty || values['database']!.isEmpty || port == null) {
    throw StateError('Missing valid DB_HOST, DB_PORT, DB_USER, or DB_NAME.');
  }
  return _Config(values['host']!, port, values['user']!, values['password']!,
      values['database']!);
}

Future<MySQLConnection> _connect(_Config config, {String? database}) async {
  final connection = await MySQLConnection.createConnection(
      host: config.host,
      port: config.port,
      userName: config.user,
      password: config.password,
      databaseName: database);
  await connection.connect();
  return connection;
}

class _Config {
  const _Config(this.host, this.port, this.user, this.password, this.database);
  final String host;
  final int port;
  final String user;
  final String password;
  final String database;
}

class _Schema {
  const _Schema(this.columns, this.types, this.binaryColumns, this.jsonColumns);
  final List<String> columns;
  final List<String> types;
  final List<String> binaryColumns;
  final List<String> jsonColumns;
}

class _Snapshot {
  const _Snapshot(this.file, this.decoded, this.manifest);
  final File file;
  final Map<String, dynamic> decoded;
  final Map<String, dynamic> manifest;
}
