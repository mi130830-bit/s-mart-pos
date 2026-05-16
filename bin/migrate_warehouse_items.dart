// ignore_for_file: avoid_print
import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';

void main() async {
  print('🚚 Starting Warehouse Item Migration...');

  const host = 'localhost';
  const port = 3306;
  const user = 'admin';
  const pass = '1234';
  const dbName = 'sorborikan';

  try {
    print('🔌 Connecting to MySQL ($host:$port)...');
    final conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: pass,
      databaseName: dbName,
      secure: false,
    );
    await conn.connect();
    print('✅ Connected.');

    print('🛠 Checking schema...');
    final checkCol = await conn.execute(
        "SELECT COUNT(*) as count FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = :db AND TABLE_NAME = 'product' AND COLUMN_NAME = 'isWarehouseItem'",
        {'db': dbName});

    final count = int.parse(checkCol.rows.first.assoc()['count']!);

    if (count == 0) {
      print('➕ Adding column `isWarehouseItem`...');
      await conn.execute(
          "ALTER TABLE product ADD COLUMN isWarehouseItem TINYINT(1) DEFAULT 0");
    } else {
      print('👌 Column `isWarehouseItem` already exists.');
    }

    final keywords = [
      'ทราย',
      'หิน',
      'เสา',
      'เหล็ก',
      'ไม้ฝา',
      'ไม้เชิงชาย',
      'ปูน',
      'อิฐ',
      'กระเบื้อง',
      'หลังคา',
      'ซีเมนต์',
      'แผ่นพื้น',
      'ไม้อัด',
      'ประตู'
    ];

    print('📦 Updating products based on keywords: ${keywords.join(", ")}...');

    int totalUpdated = 0;
    for (final kw in keywords) {
      final res = await conn.execute(
          "UPDATE product SET isWarehouseItem = 1 WHERE name LIKE :pattern AND isWarehouseItem = 0",
          {'pattern': '$kw%'});

      print('   - Keyword "$kw": Updated ${res.affectedRows} items.');
      totalUpdated += res.affectedRows.toInt();
    }

    print(
        '✅ Migration Complete. Total items marked as Warehouse Item: $totalUpdated');

    await conn.close();
    exit(0);
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}
