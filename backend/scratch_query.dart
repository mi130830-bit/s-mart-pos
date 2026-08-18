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

  final conn = await MySQLConnection.createConnection(
    host: host,
    port: port,
    userName: user,
    password: pass,
    databaseName: db.isEmpty ? null : db,
    secure: false,
  );
  await conn.connect();

  stdout.writeln('\n--- Describe delivery_jobs ---');
  var desc = await conn.execute("DESCRIBE delivery_jobs");
  for (final row in desc.rows) {
    stdout.writeln('${row.colAt(0)} | ${row.colAt(1)}');
  }
}
