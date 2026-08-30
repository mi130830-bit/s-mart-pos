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

    // Find the ID of 'สี' in product_type
    final typeRes = await conn.execute(
      "SELECT id FROM product_type WHERE name = :name",
      {'name': 'สี'}
    );

    if (typeRes.rows.isEmpty) {
      stdout.writeln('Error: Product type "สี" not found in product_type table!');
      return;
    }

    final paintTypeId = int.parse(typeRes.rows.first.colByName('id')!);
    stdout.writeln('Found "สี" product type ID: $paintTypeId');

    // Count how many products will be affected
    final countRes = await conn.execute(
      "SELECT COUNT(*) as cnt FROM product WHERE name LIKE 'สี%'"
    );
    final count = int.parse(countRes.rows.first.colByName('cnt')!);
    stdout.writeln('Number of products starting with "สี" or "สีน้ำมัน": $count');

    if (count == 0) {
      stdout.writeln('No products start with "สี". No update needed.');
      return;
    }

    // Perform the update
    final updateRes = await conn.execute(
      "UPDATE product SET productType = :typeId WHERE name LIKE 'สี%'",
      {'typeId': paintTypeId}
    );
    stdout.writeln('Update successful! Affected rows: ${updateRes.affectedRows}');

    // Log this activity to activity_log
    await conn.execute(
      "INSERT INTO activity_log (action, details) VALUES (:action, :details)",
      {
        'action': 'UPDATE_PRODUCT',
        'details': 'เปลี่ยนประเภทสินค้าเป็น สี (ID: $paintTypeId) สำหรับสินค้าที่ขึ้นต้นด้วย "สี" ทั้งหมด จำนวน $count รายการ'
      }
    );
    stdout.writeln('Logged activity to database.');

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
