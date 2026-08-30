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
    stdout.writeln('Connected!');

    stdout.writeln('\n--- Checking products starting with "ยาแนว" ---');
    final queryStr = """
      SELECT id, name, reorderPoint, productType 
      FROM product 
      WHERE name LIKE 'ยาแนว%'
    """;
    var result = await conn.execute(queryStr);
    stdout.writeln('Found ${result.rows.length} products.');
    for (final row in result.rows) {
      stdout.writeln('ID: ${row.colByName("id")}, Name: ${row.colByName("name")}, ReorderPoint: ${row.colByName("reorderPoint")}, ProductType: ${row.colByName("productType")}');
    }

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
