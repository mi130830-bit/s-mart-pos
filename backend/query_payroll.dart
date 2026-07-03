import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  var env = DotEnv(includePlatformEnvironment: true)..load();
  final host = env['DB_HOST'] ?? '127.0.0.1';
  final port = int.tryParse(env['DB_PORT'] ?? '3306') ?? 3306;
  final user = env['DB_USER'] ?? 'root';
  final pass = env['DB_PASS'] ?? '';
  final db = env['DB_NAME'] ?? 'sorborikan';

  final conn = await MySQLConnection.createConnection(
    host: host,
    port: port,
    userName: user,
    password: pass,
    databaseName: db,
    secure: false,
  );

  try {
    await conn.connect();
    var res = await conn.execute("DESCRIBE payroll_record");
    for (final row in res.rows) {
      stdout.writeln('${row.colAt(0)} | ${row.colAt(1)}');
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    await conn.close();
  }
}
