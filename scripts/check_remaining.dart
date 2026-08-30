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

    stdout.writeln('\n--- Checking products containing keywords but not having productType = 3 (สี) ---');
    final queryStr = """
      SELECT id, name, productType 
      FROM product 
      WHERE (
        name LIKE 'สีย้อมไม้%' 
        OR name LIKE 'สีรองพื้น%' 
        OR name LIKE 'สีกันสนิม%'
        OR name LIKE '%สีย้อมไม้%'
        OR name LIKE '%สีรองพื้น%'
        OR name LIKE '%สีกันสนิม%'
      ) AND productType != 3
    """;
    var result = await conn.execute(queryStr);
    stdout.writeln('Found ${result.rows.length} products.');
    for (final row in result.rows) {
      stdout.writeln('ID: ${row.colByName("id")}, Name: ${row.colByName("name")}, ProductType: ${row.colByName("productType")}');
    }

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
