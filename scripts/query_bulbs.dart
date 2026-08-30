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

    stdout.writeln('\n--- Checking products for bulb-related keywords ---');
    final queryStr = """
      SELECT id, name, productType 
      FROM product 
      WHERE name LIKE 'หลอดไฟ%' 
         OR name LIKE 'หลอดled%' 
         OR name LIKE 'หลอดbulb%' 
         OR name LIKE 'หลอดจับแมลง%' 
         OR name LIKE 'หลอดใส%' 
         OR name LIKE 'ชุดหลอดled%' 
         OR name LIKE 'ชุดหลอดไฟ%'
    """;
    var result = await conn.execute(queryStr);
    stdout.writeln('Found ${result.rows.length} products starting with keywords.');
    for (final row in result.rows) {
      stdout.writeln('ID: ${row.colByName("id")}, Name: ${row.colByName("name")}, ProductType: ${row.colByName("productType")}');
    }

    stdout.writeln('\n--- Checking products CONTAINING keywords but not starting with them ---');
    final queryStrContains = """
      SELECT id, name, productType 
      FROM product 
      WHERE (
        name LIKE '%หลอดไฟ%' 
        OR name LIKE '%หลอดled%' 
        OR name LIKE '%หลอดbulb%' 
        OR name LIKE '%หลอดจับแมลง%' 
        OR name LIKE '%หลอดใส%' 
        OR name LIKE '%ชุดหลอดled%' 
        OR name LIKE '%ชุดหลอดไฟ%'
      ) AND NOT (
        name LIKE 'หลอดไฟ%' 
        OR name LIKE 'หลอดled%' 
        OR name LIKE 'หลอดbulb%' 
        OR name LIKE 'หลอดจับแมลง%' 
        OR name LIKE 'หลอดใส%' 
        OR name LIKE 'ชุดหลอดled%' 
        OR name LIKE 'ชุดหลอดไฟ%'
      )
    """;
    var resultContains = await conn.execute(queryStrContains);
    stdout.writeln('Found ${resultContains.rows.length} products containing keywords but not starting with them.');
    for (final row in resultContains.rows) {
      stdout.writeln('ID: ${row.colByName("id")}, Name: ${row.colByName("name")}, ProductType: ${row.colByName("productType")}');
    }

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
