import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../mysql_service.dart';

class BackupService {
  final MySQLService _db;

  BackupService({MySQLService? db}) : _db = db ?? MySQLService();

  Future<File?> createBackup({String? customPath}) async {
    try {
      if (!_db.isConnected()) await _db.connect();

      // 1. Prepare File
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      File targetFile;
      if (customPath != null) {
        targetFile = File(customPath);
      } else {
        final tempDir = await getTemporaryDirectory();
        targetFile = File('${tempDir.path}/backup_$timestamp.json');
      }

      final sink = targetFile.openWrite();

      // 2. Start JSON Object
      sink.write('{');

      // 3. Get Tables
      final tablesResult = await _db.query("SHOW TABLES");
      if (tablesResult.isEmpty) {
        sink.write('}');
        await sink.close();
        return null; // Or empty backup
      }

      final tables = tablesResult.map((r) => r.values.first as String).toList();
      debugPrint('Found ${tables.length} tables to backup (Streamed).');

      int tableCount = 0;
      for (var table in tables) {
        if (tableCount > 0) sink.write(',');
        sink.write('"$table":[');

        // 4. Fetch & Write Rows (Pagination)
        int offset = 0;
        const limit = 1000;
        bool isFirstRow = true;

        while (true) {
          final rows = await _db
              .query("SELECT * FROM `$table` LIMIT $limit OFFSET $offset");
          if (rows.isEmpty) break;

          for (var row in rows) {
            if (!isFirstRow) sink.write(',');

            // Extract row data manually to Map to ensure encodability
            final Map<String, dynamic> rowMap = {};
            for (var entry in row.entries) {
              rowMap[entry.key] = _prepValue(entry.value);
            }

            sink.write(jsonEncode(rowMap));
            isFirstRow = false;
          }

          offset += limit;
          // Yield to event loop to prevent blocking UI too much
          await Future.delayed(Duration.zero);
        }

        sink.write(']');
        tableCount++;
      }

      // 5. Close JSON Object
      sink.write('}');
      await sink.flush();
      await sink.close();

      debugPrint('Backup created successfully: ${targetFile.path}');
      return targetFile;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }

  dynamic _prepValue(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is List<int>) return base64Encode(value);
    return value;
  }

  // Placeholder for Restore (Optional for this task but good to have structure)
  // Restore Backup Logic
  Future<bool> restoreBackup(File backupFile) async {
    try {
      if (!_db.isConnected()) await _db.connect();

      debugPrint('Reading backup file: ${backupFile.path}');
      final content = await backupFile.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(content);

      debugPrint('Found ${backupData.length} tables to restore.');

      // Disable Foreign Keys Checks
      try {
        await _db.execute('SET FOREIGN_KEY_CHECKS = 0;');
      } catch (_) {}

      for (var tableName in backupData.keys) {
        debugPrint('Restoring table: $tableName');
        final rows = backupData[tableName] as List<dynamic>;

        // 3. Truncate Table
        bool tableExists = true;
        try {
          await _db.execute('TRUNCATE TABLE `$tableName`');
        } catch (e) {
          debugPrint('Table $tableName truncate failed: $e');
          if (e.toString().contains("doesn't exist")) {
            tableExists = false;
          }
        }

        if (!tableExists) continue;

        // 4. Insert Data
        if (rows.isNotEmpty) {
          int rowCount = 0;
          for (var row in rows) {
            if (row is Map<String, dynamic>) {
              final columns = row.keys.map((k) => '`$k`').join(', ');
              final values = row.values.map((v) => _escapeValue(v)).join(', ');
              final sql =
                  "INSERT INTO `$tableName` ($columns) VALUES ($values)";
              await _db.execute(sql);
              rowCount++;
            }
          }
          debugPrint('Imported $rowCount rows into $tableName');
        }
      }

      // Enable Foreign Keys Checks
      await _db.execute('SET FOREIGN_KEY_CHECKS = 1;');

      debugPrint('Restore completed successfully.');
      return true;
    } catch (e) {
      debugPrint('Error restoring backup: $e');
      // Ensure FK checks are re-enabled even on error
      try {
        await _db.execute('SET FOREIGN_KEY_CHECKS = 1;');
      } catch (_) {}
      return false;
    }
  }

  String _escapeValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is num) return '$value';
    if (value is bool) return value ? '1' : '0';
    // String escaping roughly
    String str = value.toString();
    str = str.replaceAll("'", "''").replaceAll(r'\\', r'\\\\');
    return "'$str'";
  }

  // Cleanup Local Temp Files (Count Based)
  Future<int> cleanupLocalBackups(int maxKeep) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Only get relevant json backup files
      final files = tempDir
          .listSync()
          .where((e) {
            return e is File &&
                e.path.contains('backup_') &&
                e.path.endsWith('.json');
          })
          .cast<File>()
          .toList();

      if (files.length <= maxKeep) return 0;

      // Sort by Modified Date DESC (Newest First)
      files.sort((a, b) {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      });

      int count = 0;
      // Undo excess files
      for (int i = maxKeep; i < files.length; i++) {
        try {
          await files[i].delete();
          count++;
        } catch (e) {
          debugPrint('Failed to delete temp backup: ${files[i].path}');
        }
      }

      if (count > 0) {
        debugPrint(
            '🧹 Cleaned up $count local temp backups (Policy: Keep $maxKeep).');
      }
      return count;
    } catch (e) {
      debugPrint('Error cleaning local backups: $e');
      return 0;
    }
  }
}
