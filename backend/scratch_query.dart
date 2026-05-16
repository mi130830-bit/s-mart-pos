import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  var env = DotEnv(includePlatformEnvironment: true)..load();
  final host = env['DB_HOST'] ?? '127.0.0.1';
  final port = int.tryParse(env['DB_PORT'] ?? '3306') ?? 3306;
  final user = env['DB_USER'] ?? 'root';
  final pass = env['DB_PASS'] ?? '';
  final db = env['DB_NAME'] ?? 'pos_data';

  stdout.writeln('Connecting to DB: $host:$port ($db)...');

  final conn = await MySQLConnection.createConnection(
    host: host,
    port: port,
    userName: user,
    password: pass,
    databaseName: db.isEmpty ? null : db,
    secure: false,
  );

  try {
    await conn.connect();
    stdout.writeln('Connected!');

    stdout.writeln('\n--- Customers ---');
    var result = await conn.execute("SELECT id, firstName, phone, line_user_id FROM customer WHERE line_user_id IS NOT NULL OR line_display_name IS NOT NULL");

    for (final row in result.rows) {
      stdout.writeln('ID: ${row.colByName("id")} | Name: ${row.colByName("firstName")} | Phone: ${row.colByName("phone")} | LineID: ${row.colByName("line_user_id")}');
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
