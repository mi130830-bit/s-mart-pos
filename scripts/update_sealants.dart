import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';

Future<void> main() async {
  final conn = await MySQLConnection.createConnection(
    host: '127.0.0.1',
    port: 3306,
    userName: 'admin',
    password: '1234',
    databaseName: 'sorborikan',
  );

  try {
    await conn.connect();
    stdout.writeln('Connected to DB!');

    // Count how many products will be affected
    final countRes = await conn.execute(
      "SELECT COUNT(*) as cnt FROM product WHERE name LIKE 'ยาแนว%'"
    );
    final count = int.parse(countRes.rows.first.colByName('cnt')!);
    stdout.writeln('Number of products starting with "ยาแนว": $count');

    if (count == 0) {
      stdout.writeln('No products start with "ยาแนว". No update needed.');
      return;
    }

    // Perform the update
    final updateRes = await conn.execute(
      "UPDATE product SET reorderPoint = 5.0 WHERE name LIKE 'ยาแนว%'"
    );
    stdout.writeln('Update successful! Affected rows: ${updateRes.affectedRows}');

    // Log this activity to activity_log
    await conn.execute(
      "INSERT INTO activity_log (action, details) VALUES (:action, :details)",
      {
        'action': 'UPDATE_PRODUCT',
        'details': 'อัปเดตจุดสั่งซื้อขั้นต่ำ (reorderPoint) เป็น 5 สำหรับสินค้ากลุ่มยาแนวทั้งหมด จำนวน $count รายการ'
      }
    );
    stdout.writeln('Logged activity to database.');

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
