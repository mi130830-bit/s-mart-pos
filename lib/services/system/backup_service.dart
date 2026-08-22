import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../mysql_service.dart';

/// Result of a non-mutating backup-file inspection.
class BackupValidationResult {
  const BackupValidationResult._({
    required this.isValid,
    required this.isLegacy,
    this.error,
    this.tableCount = 0,
  });

  const BackupValidationResult.valid({
    required bool isLegacy,
    required int tableCount,
  }) : this._(isValid: true, isLegacy: isLegacy, tableCount: tableCount);

  const BackupValidationResult.invalid(String error)
      : this._(isValid: false, isLegacy: false, error: error);

  final bool isValid;
  final bool isLegacy;
  final String? error;
  final int tableCount;
}

class BackupService {
  static const _format = 'POS_DESKTOP_BACKUP';
  static const _version = 2;
  static const _checksumAlgorithm = 'SHA-256';
  static final RegExp _identifier = RegExp(r'^[A-Za-z0-9_]+$');

  final MySQLService _db;

  /// Location of the verified automatic backup made immediately before the
  /// latest restore. Null means restore did not reach its mutation stage.
  String? lastRestoreSafetyBackupPath;

  BackupService({MySQLService? db}) : _db = db ?? MySQLService();

  /// Creates a versioned backup with per-table row counts and SHA-256 hashes.
  /// It streams table rows, avoiding one giant in-memory database copy.
  Future<File?> createBackup({String? customPath}) async {
    try {
      if (!_db.isConnected()) await _db.connect();
      return await _createBackupInternal(customPath: customPath);
    } catch (e, stackTrace) {
      debugPrint('Error creating backup: $e\n$stackTrace');
      return null;
    }
  }

  Future<File?> _createBackupInternal({String? customPath}) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final targetFile = customPath == null
        ? File('${(await getTemporaryDirectory()).path}/backup_$timestamp.json')
        : File(customPath);
    await targetFile.parent.create(recursive: true);

    IOSink? sink;
    try {
      final tables = await _loadLiveTables();
      if (tables.isEmpty) throw StateError('No database tables were found.');

      sink = targetFile.openWrite();
      sink.write('{"data":{');
      final tableManifest = <String, Map<String, dynamic>>{};

      for (var tableIndex = 0; tableIndex < tables.length; tableIndex++) {
        final table = tables[tableIndex];
        final schema = await _loadTableSchema(table);
        if (tableIndex > 0) sink.write(',');
        sink.write('${jsonEncode(table)}:[');

        final digest = _DigestWriter()..add('[');
        var rowCount = 0;
        var firstRow = true;
        var offset = 0;
        const limit = 1000;
        while (true) {
          final rows = await _db.query(
              'SELECT * FROM `${_safeIdentifier(table)}` LIMIT $limit OFFSET $offset');
          if (rows.isEmpty) break;
          for (final row in rows) {
            final rowMap = <String, dynamic>{
              for (final column in schema.columns)
                column: _prepValue(row[column]),
            };
            final encoded = jsonEncode(_canonicalize(rowMap));
            if (!firstRow) {
              sink.write(',');
              digest.add(',');
            }
            sink.write(encoded);
            digest.add(encoded);
            firstRow = false;
            rowCount++;
          }
          offset += limit;
          await Future<void>.delayed(Duration.zero);
        }
        sink.write(']');
        digest.add(']');
        tableManifest[table] = <String, dynamic>{
          'rowCount': rowCount,
          'columns': schema.columns,
          'binaryColumns': schema.binaryColumns,
          'checksum': digest.close(),
        };
      }

      final manifest = <String, dynamic>{
        'format': _format,
        'version': _version,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'checksumAlgorithm': _checksumAlgorithm,
        'overallChecksum': _manifestChecksum(tableManifest),
        'tables': tableManifest,
      };
      sink.write('},"manifest":${jsonEncode(_canonicalize(manifest))}}');
      await sink.flush();
      await sink.close();
      sink = null;

      final validation = await inspectBackup(targetFile);
      if (!validation.isValid) {
        throw StateError(
            'Generated backup failed verification: ${validation.error}');
      }
      debugPrint('Backup created and verified: ${targetFile.path}');
      return targetFile;
    } catch (_) {
      await sink?.close();
      if (await targetFile.exists()) await targetFile.delete();
      rethrow;
    }
  }

  /// Validates a backup before restore. Live table and column metadata form a
  /// strict allowlist; a file cannot name arbitrary tables or SQL columns.
  Future<BackupValidationResult> inspectBackup(File backupFile) async {
    try {
      if (!await backupFile.exists()) {
        return const BackupValidationResult.invalid('ไม่พบไฟล์สำรองข้อมูล');
      }
      if (!_db.isConnected()) await _db.connect();
      final decoded = jsonDecode(await backupFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const BackupValidationResult.invalid(
            'รูปแบบไฟล์สำรองข้อมูลไม่ถูกต้อง');
      }
      return _validateDecodedBackup(decoded);
    } catch (e) {
      return BackupValidationResult.invalid('ตรวจสอบไฟล์ไม่ผ่าน: $e');
    }
  }

  Future<BackupValidationResult> _validateDecodedBackup(
      Map<String, dynamic> decoded) async {
    final isVersioned = decoded['manifest'] is Map && decoded['data'] is Map;
    final data = isVersioned ? decoded['data'] : decoded;
    if (data is! Map) {
      return const BackupValidationResult.invalid('ส่วนข้อมูลสำรองไม่ถูกต้อง');
    }
    final liveTables = await _loadLiveTables();
    final dataTables = data.keys.map((key) => key.toString()).toSet();
    if (dataTables.length != liveTables.length ||
        !dataTables.containsAll(liveTables)) {
      return const BackupValidationResult.invalid(
          'ตารางในไฟล์ไม่ตรงกับโครงสร้างฐานข้อมูลปัจจุบัน');
    }

    Map<String, dynamic>? tableManifest;
    if (isVersioned) {
      final manifest = Map<String, dynamic>.from(decoded['manifest'] as Map);
      if (manifest['format'] != _format ||
          manifest['version'] != _version ||
          manifest['checksumAlgorithm'] != _checksumAlgorithm ||
          manifest['tables'] is! Map) {
        return const BackupValidationResult.invalid(
            'เวอร์ชันหรือ Manifest ของไฟล์ไม่รองรับ');
      }
      tableManifest = Map<String, dynamic>.from(manifest['tables'] as Map);
      if (tableManifest.length != liveTables.length ||
          !tableManifest.keys.toSet().containsAll(liveTables)) {
        return const BackupValidationResult.invalid(
            'Manifest มีตารางไม่ครบหรือไม่ตรงกัน');
      }
    }

    final checksums = <String, Map<String, dynamic>>{};
    for (final table in liveTables) {
      final rows = data[table];
      if (rows is! List) {
        return BackupValidationResult.invalid(
            'ตาราง $table ไม่ได้อยู่ในรูปแบบรายการข้อมูล');
      }
      final schema = await _loadTableSchema(table);
      final meta = tableManifest?[table];
      if (!isVersioned && schema.binaryColumns.isNotEmpty) {
        return BackupValidationResult.invalid(
            'ไฟล์สำรองรูปแบบเดิมไม่รองรับข้อมูลไบนารีในตาราง $table อย่างปลอดภัย');
      }
      if (meta != null &&
          (meta is! Map ||
              !_sameStringList(meta['columns'], schema.columns) ||
              !_sameStringList(meta['binaryColumns'], schema.binaryColumns))) {
        return BackupValidationResult.invalid(
            'โครงสร้างคอลัมน์ของตาราง $table ไม่ตรงกัน');
      }

      final digest = _DigestWriter()..add('[');
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        if (row is! Map) {
          return BackupValidationResult.invalid(
              'แถวที่ $index ของตาราง $table ไม่ถูกต้อง');
        }
        final normalizedRow = Map<String, dynamic>.from(row);
        if (normalizedRow.length != schema.columns.length ||
            !normalizedRow.keys.toSet().containsAll(schema.columns)) {
          return BackupValidationResult.invalid(
              'คอลัมน์ในตาราง $table ไม่ตรงกับฐานข้อมูล');
        }
        if (index > 0) digest.add(',');
        digest.add(jsonEncode(_canonicalize(normalizedRow)));
      }
      digest.add(']');
      final checksum = digest.close();
      checksums[table] = <String, dynamic>{
        'rowCount': rows.length,
        'checksum': checksum,
      };
      if (meta != null &&
          (meta['rowCount'] != rows.length || meta['checksum'] != checksum)) {
        return BackupValidationResult.invalid(
            'Checksum หรือจำนวนแถวของตาราง $table ไม่ถูกต้อง');
      }
    }

    if (isVersioned) {
      final manifest = Map<String, dynamic>.from(decoded['manifest'] as Map);
      final merged = <String, Map<String, dynamic>>{};
      for (final table in liveTables) {
        merged[table] = <String, dynamic>{
          ...Map<String, dynamic>.from(tableManifest![table] as Map),
          ...checksums[table]!,
        };
      }
      if (manifest['overallChecksum'] != _manifestChecksum(merged)) {
        return const BackupValidationResult.invalid(
            'Checksum รวมของไฟล์ไม่ถูกต้อง');
      }
    }
    return BackupValidationResult.valid(
        isLegacy: !isVersioned, tableCount: liveTables.length);
  }

  /// MySQL TRUNCATE implicitly commits, so transaction rollback cannot recover
  /// an interrupted restore. A separately verified pre-restore copy is made
  /// first. The exclusive scope prevents this desktop app from interleaving SQL.
  Future<bool> restoreBackup(File backupFile) async {
    lastRestoreSafetyBackupPath = null;
    try {
      if (!_db.isConnected()) await _db.connect();
      final validation = await inspectBackup(backupFile);
      if (!validation.isValid) {
        debugPrint('Restore refused: ${validation.error}');
        return false;
      }
      final decoded = Map<String, dynamic>.from(
          jsonDecode(await backupFile.readAsString()) as Map);
      final data = Map<String, dynamic>.from(
          (decoded['data'] is Map ? decoded['data'] : decoded) as Map);
      final manifest = decoded['manifest'] is Map
          ? Map<String, dynamic>.from(decoded['manifest'] as Map)
          : null;

      return await _db.runExclusiveTransaction(() async {
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final safetyFile = await _createBackupInternal(
            customPath:
                '${(await getTemporaryDirectory()).path}/pre_restore_$timestamp.json');
        if (safetyFile == null) {
          throw StateError('Could not create the required pre-restore backup.');
        }
        lastRestoreSafetyBackupPath = safetyFile.path;

        var foreignKeysDisabled = false;
        try {
          await _db.execute('SET FOREIGN_KEY_CHECKS = 0');
          foreignKeysDisabled = true;
          final tables = await _loadLiveTables();
          for (final table in tables) {
            await _db.execute('TRUNCATE TABLE `${_safeIdentifier(table)}`');
          }
          for (final table in tables) {
            final rows = data[table] as List;
            final schema = await _loadTableSchema(table);
            final binaryColumns = manifest == null
                ? const <String>[]
                : List<String>.from(Map<String, dynamic>.from(
                        Map.from(manifest['tables'] as Map)[table]
                            as Map)['binaryColumns'] ??
                    const <dynamic>[]);
            for (final rawRow in rows) {
              final row = Map<String, dynamic>.from(rawRow as Map);
              final params = <String, dynamic>{};
              for (var i = 0; i < schema.columns.length; i++) {
                final column = schema.columns[i];
                final value = row[column];
                params['v$i'] =
                    binaryColumns.contains(column) && value is String
                        ? base64Decode(value)
                        : value;
              }
              final quotedColumns = schema.columns
                  .map((column) => '`${_safeIdentifier(column)}`')
                  .join(', ');
              final placeholders = List<String>.generate(
                  schema.columns.length, (index) => ':v$index').join(', ');
              await _db.execute(
                  'INSERT INTO `${_safeIdentifier(table)}` ($quotedColumns) VALUES ($placeholders)',
                  params);
            }
            final count = await _db.query(
                'SELECT COUNT(*) AS rowCount FROM `${_safeIdentifier(table)}`');
            final actual =
                int.tryParse(count.single['rowCount'].toString()) ?? -1;
            if (actual != rows.length) {
              throw StateError('Row-count verification failed for $table');
            }
          }
          return true;
        } finally {
          if (foreignKeysDisabled) {
            await _db.execute('SET FOREIGN_KEY_CHECKS = 1');
          }
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Error restoring backup: $e\n$stackTrace');
      return false;
    }
  }

  Future<List<String>> _loadLiveTables() async {
    final tables = await _db.query('SHOW TABLES');
    final names = tables.map((row) => row.values.first.toString()).toList()
      ..sort();
    if (names.any((name) => !_identifier.hasMatch(name))) {
      throw StateError('Database contains an unsupported table identifier.');
    }
    return names;
  }

  Future<_TableSchema> _loadTableSchema(String table) async {
    final rows =
        await _db.query('SHOW COLUMNS FROM `${_safeIdentifier(table)}`');
    final columns = <String>[];
    final binaryColumns = <String>[];
    for (final row in rows) {
      final name = row['Field']?.toString();
      final type = row['Type']?.toString().toUpperCase() ?? '';
      if (name == null || !_identifier.hasMatch(name)) {
        throw StateError('Unsupported column identifier in $table');
      }
      columns.add(name);
      if (type.contains('BLOB') ||
          type.contains('BINARY') ||
          type.startsWith('BIT')) {
        binaryColumns.add(name);
      }
    }
    return _TableSchema(columns: columns, binaryColumns: binaryColumns);
  }

  dynamic _prepValue(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is List<int>) return base64Encode(value);
    return value;
  }

  String _manifestChecksum(Map<String, Map<String, dynamic>> tables) {
    final entries = tables.keys.toList()..sort();
    final summary = entries
        .map((table) => <String, dynamic>{
              'table': table,
              'rowCount': tables[table]!['rowCount'],
              'checksum': tables[table]!['checksum'],
            })
        .toList();
    return sha256
        .convert(utf8.encode(jsonEncode(_canonicalize(summary))))
        .toString();
  }

  dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) return value.map(_canonicalize).toList();
    return value;
  }

  bool _sameStringList(dynamic raw, List<String> expected) {
    if (raw is! List || raw.length != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (raw[i]?.toString() != expected[i]) return false;
    }
    return true;
  }

  String _safeIdentifier(String name) {
    if (!_identifier.hasMatch(name)) throw ArgumentError.value(name, 'name');
    return name;
  }

  Future<int> cleanupLocalBackups(int maxKeep) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir
          .listSync()
          .whereType<File>()
          .where((file) =>
              file.path.contains('backup_') && file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      var count = 0;
      for (var index = maxKeep; index < files.length; index++) {
        await files[index].delete();
        count++;
      }
      return count;
    } catch (e) {
      debugPrint('Error cleaning local backups: $e');
      return 0;
    }
  }
}

class _TableSchema {
  const _TableSchema({required this.columns, required this.binaryColumns});

  final List<String> columns;
  final List<String> binaryColumns;
}

class _DigestWriter {
  final _sink = _DigestSink();
  late final ByteConversionSink _input = sha256.startChunkedConversion(_sink);

  void add(String value) => _input.add(utf8.encode(value));

  String close() {
    _input.close();
    return _sink.value.toString();
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _digest;

  Digest get value =>
      _digest ?? (throw StateError('Digest was not completed.'));

  @override
  void add(Digest data) {
    _digest = data;
  }

  @override
  void close() {}
}
