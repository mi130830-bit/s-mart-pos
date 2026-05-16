import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';

// Copy config from db_config.dart
class DbConfig {
  static const String host = '127.0.0.1';
  static const int port = 3306;
  static const String user = 'root';
  static const String password = 'password';
  static const String dbName = 's_link_pos';
}

Future<void> main() async {
  stdout.writeln('Connecting to DB...');
  final conn = await MySQLConnection.createConnection(
    host: DbConfig.host,
    port: DbConfig.port,
    userName: DbConfig.user,
    password: DbConfig.password,
    databaseName: DbConfig.dbName,
  );

  try {
    await conn.connect();
    stdout.writeln('Connected!');

    stdout.writeln('\n--- Product Schema (Barcode) ---');
    var result =
        await conn.execute("SHOW COLUMNS FROM product WHERE Field = 'barcode'");

    for (final row in result.rows) {
      stdout.writeln('Field: ${row.colByName("Field")}');
      stdout.writeln('Type: ${row.colByName("Type")}');
      stdout.writeln('Null: ${row.colByName("Null")}');
      stdout.writeln('Key: ${row.colByName("Key")}');
      stdout.writeln('Default: ${row.colByName("Default")}');
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
