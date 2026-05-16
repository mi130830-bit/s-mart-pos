import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_desktop/services/system/backup_service.dart';
import 'package:pos_desktop/services/mysql_service.dart';

// Mock MySQL
class MockMySQLBackup implements MySQLService {
  @override
  bool isConnected() => true;

  @override
  Future<void> connect() async {}

  @override
  Future<List<Map<String, dynamic>>> query(String sql,
      [Map<String, dynamic>? params]) async {
    // 1. Show Tables
    if (sql.contains("SHOW TABLES")) {
      return [
        {'table': 'users'},
        {'table': 'products'}
      ];
    }

    // 2. Users Table
    // SELECT * FROM `users` LIMIT 1000 OFFSET 0
    if (sql.contains("FROM `users`")) {
      if (sql.contains("OFFSET 0")) {
        return [
          {'id': 1, 'name': 'Admin', 'created_at': DateTime(2023, 1, 1)}
        ];
      }
      return []; // Offset > 0 empty
    }

    // 3. Products Table
    if (sql.contains("FROM `products`")) {
      if (sql.contains("OFFSET 0")) {
        return [
          {'id': 100, 'name': 'Coke', 'price': 15.0}
        ];
      }
      return [];
    }

    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Since I cannot inject MockDB easily into BackupService (it instantiates internally),
// I must refactor BackupService to accept db injection OR I use a trick or overrides.
// The file `backup_service.dart` has `final MySQLService _db = MySQLService();`.
// I should refactor BackupService to allow injection first for testability.

void main() {
  test('BackupService streams data correctly', () async {
    final mockDB = MockMySQLBackup();
    final backupService = BackupService(db: mockDB);

    // Create temp file for test
    final tempDir = Directory.systemTemp.createTempSync();
    final file = File('${tempDir.path}/test_backup.json');

    await backupService.createBackup(customPath: file.path);

    // Verify Content
    final content = await file.readAsString();
    // print('Backup Content: $content');

    // Expect Valid JSON
    expect(content, startsWith('{'));
    expect(content, endsWith('}'));
    expect(content, contains('"users":['));
    expect(content, contains('"products":['));
    // Check data
    expect(content, contains('"name":"Admin"'));
    expect(content, contains('"name":"Coke"'));

    // Cleanup
    if (file.existsSync()) file.deleteSync();
  });
}
