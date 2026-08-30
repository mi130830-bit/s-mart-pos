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

    // Find the ID of 'ดอกสว่าน' in product_type
    final typeRes = await conn.execute(
      "SELECT id FROM product_type WHERE name = :name",
      {'name': 'ดอกสว่าน'}
    );

    if (typeRes.rows.isEmpty) {
      stdout.writeln('Error: Product type "ดอกสว่าน" not found in product_type table!');
      return;
    }

    final drillTypeId = int.parse(typeRes.rows.first.colByName('id')!);
    stdout.writeln('Found "ดอกสว่าน" product type ID: $drillTypeId');

    // Count how many products will be affected
    final countRes = await conn.execute(
      "SELECT COUNT(*) as cnt FROM product WHERE name LIKE 'ดอกสว่าน%'"
    );
    final count = int.parse(countRes.rows.first.colByName('cnt')!);
    stdout.writeln('Number of products starting with "ดอกสว่าน": $count');

    if (count == 0) {
      stdout.writeln('No products start with "ดอกสว่าน". No update needed.');
      return;
    }

    // Perform the update
    final updateRes = await conn.execute(
      "UPDATE product SET productType = :typeId WHERE name LIKE 'ดอกสว่าน%'",
      {'typeId': drillTypeId}
    );
    stdout.writeln('Update successful! Affected rows: ${updateRes.affectedRows}');

    // Log this activity to activity_log
    await conn.execute(
      "INSERT INTO activity_log (action, details) VALUES (:action, :details)",
      {
        'action': 'UPDATE_PRODUCT',
        'details': 'เปลี่ยนประเภทสินค้าเป็น ดอกสว่าน (ID: $drillTypeId) สำหรับสินค้าที่ขึ้นต้นด้วย "ดอกสว่าน" ทั้งหมด จำนวน $count รายการ'
      }
    );
    stdout.writeln('Logged activity to database.');

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
