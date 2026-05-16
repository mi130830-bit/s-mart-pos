import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:dotenv/dotenv.dart';

class DbConfig {
  static final DbConfig _instance = DbConfig._internal();
  factory DbConfig() => _instance;
  DbConfig._internal();

  MySQLConnection? _conn;

  Future<MySQLConnection> get connection async {
    if (_conn != null && _conn!.connected) {
      return _conn!;
    }

    // Load env if not loaded (though main should load it)
    var env = DotEnv(includePlatformEnvironment: true)..load();

    final host = env['DB_HOST'] ?? '127.0.0.1';
    final port = int.tryParse(env['DB_PORT'] ?? '3306') ?? 3306;
    final user = env['DB_USER'] ?? 'root';
    final pass = env['DB_PASS'] ?? '';
    final db = env['DB_NAME'] ?? '';

    stdout.writeln('🔌 Connecting to DB: $host:$port ($db)...');

    _conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: user,
      password: pass,
      databaseName: db.isEmpty ? null : db,
      secure: false,
    );

    await _conn!.connect();
    stdout.writeln('✅ Connected to MySQL');
    return _conn!;
  }
}
