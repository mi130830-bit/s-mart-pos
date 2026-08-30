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

    // Find the ID of 'หลอดไฟ' in product_type
    final typeRes = await conn.execute(
      "SELECT id FROM product_type WHERE name = :name",
      {'name': 'หลอดไฟ'}
    );

    if (typeRes.rows.isEmpty) {
      stdout.writeln('Error: Product type "หลอดไฟ" not found in product_type table!');
      return;
    }

    final bulbTypeId = int.parse(typeRes.rows.first.colByName('id')!);
    stdout.writeln('Found "หลอดไฟ" product type ID: $bulbTypeId');

    // Count how many products will be affected
    final countRes = await conn.execute(
      """
      SELECT COUNT(*) as cnt FROM product 
      WHERE name LIKE 'หลอดไฟ%' 
         OR name LIKE 'หลอดled%' 
         OR name LIKE 'หลอดLED%' 
         OR name LIKE 'หลอดbulb%' 
         OR name LIKE 'หลอดBulb%' 
         OR name LIKE 'หลอดจับแมลง%' 
         OR name LIKE 'หลอดใส%' 
         OR name LIKE 'ชุดหลอดled%' 
         OR name LIKE 'ชุดหลอดLED%' 
         OR name LIKE 'ชุดหลอดไฟ%'
      """
    );
    final count = int.parse(countRes.rows.first.colByName('cnt')!);
    stdout.writeln('Number of products matching prefixes: $count');

    if (count == 0) {
      stdout.writeln('No products found matching prefixes. No update needed.');
      return;
    }

    // Perform the update
    final updateRes = await conn.execute(
      """
      UPDATE product SET productType = :typeId 
      WHERE name LIKE 'หลอดไฟ%' 
         OR name LIKE 'หลอดled%' 
         OR name LIKE 'หลอดLED%' 
         OR name LIKE 'หลอดbulb%' 
         OR name LIKE 'หลอดBulb%' 
         OR name LIKE 'หลอดจับแมลง%' 
         OR name LIKE 'หลอดใส%' 
         OR name LIKE 'ชุดหลอดled%' 
         OR name LIKE 'ชุดหลอดLED%' 
         OR name LIKE 'ชุดหลอดไฟ%'
      """,
      {'typeId': bulbTypeId}
    );
    stdout.writeln('Update successful! Affected rows: ${updateRes.affectedRows}');

    // Log this activity to activity_log
    await conn.execute(
      "INSERT INTO activity_log (action, details) VALUES (:action, :details)",
      {
        'action': 'UPDATE_PRODUCT',
        'details': 'เปลี่ยนประเภทสินค้าเป็น หลอดไฟ (ID: $bulbTypeId) สำหรับสินค้ากลุ่มหลอดไฟ/ชุดหลอดไฟ ทั้งหมดจำนวน $count รายการ'
      }
    );
    stdout.writeln('Logged activity to database.');

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
