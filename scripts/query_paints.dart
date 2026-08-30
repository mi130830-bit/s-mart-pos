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

    stdout.writeln('\n--- Product Types (Categories) ---');
    var typesResult = await conn.execute("SELECT * FROM product_type WHERE name = 'สี'");
    for (final row in typesResult.rows) {
      stdout.writeln('ID: ${row.colByName("id")}, Name: ${row.colByName("name")}');
    }

    stdout.writeln('\n--- Products starting with "สี" ---');
    var productsResult = await conn.execute("SELECT id, name, productType FROM product WHERE name LIKE 'สี%'");
    stdout.writeln('Found ${productsResult.rows.length} products.');
    for (final row in productsResult.rows) {
      stdout.writeln('ID: ${row.colByName("id")}, Name: ${row.colByName("name")}, ProductType: ${row.colByName("productType")}');
    }

  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
