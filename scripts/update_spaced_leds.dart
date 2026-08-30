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

    // 1. Process "หลอด LED"
    var resultLED = await conn.execute(
      """
      UPDATE product 
      SET productType = :typeId, name = REPLACE(name, 'หลอด LED', 'หลอดLED') 
      WHERE name LIKE 'หลอด LED%'
      """,
      {'typeId': bulbTypeId}
    );
    stdout.writeln('Processed "หลอด LED%": ${resultLED.affectedRows} rows affected.');

    // 2. Process "หลอด led"
    var resultled = await conn.execute(
      """
      UPDATE product 
      SET productType = :typeId, name = REPLACE(name, 'หลอด led', 'หลอดLED') 
      WHERE name LIKE 'หลอด led%'
      """,
      {'typeId': bulbTypeId}
    );
    stdout.writeln('Processed "หลอด led%": ${resultled.affectedRows} rows affected.');

    // 3. Process "หลอด Led"
    var resultLed = await conn.execute(
      """
      UPDATE product 
      SET productType = :typeId, name = REPLACE(name, 'หลอด Led', 'หลอดLED') 
      WHERE name LIKE 'หลอด Led%'
      """,
      {'typeId': bulbTypeId}
    );
    stdout.writeln('Processed "หลอด Led%": ${resultLed.affectedRows} rows affected.');

    int totalAffected = resultLED.affectedRows.toInt() + resultled.affectedRows.toInt() + resultLed.affectedRows.toInt();

    // Log this activity to activity_log
    await conn.execute(
      "INSERT INTO activity_log (action, details) VALUES (:action, :details)",
      {
        'action': 'UPDATE_PRODUCT',
        'details': 'เปลี่ยนประเภทสินค้าเป็น หลอดไฟ (ID: $bulbTypeId) และลบเว้นวรรคชื่อ "หลอด LED" เป็น "หลอดLED" จำนวน $totalAffected รายการ'
      }
    );
    stdout.writeln('Logged activity to database.');

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
