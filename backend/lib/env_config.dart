import 'dart:io';
import 'package:dotenv/dotenv.dart';

class EnvConfig {
  static final EnvConfig _instance = EnvConfig._internal();
  factory EnvConfig() => _instance;

  late final DotEnv _env;

  EnvConfig._internal() {
    // ✅ โหลด .env จาก directory ที่ exe อยู่ก่อน แล้ว fallback ไป CWD
    // ป้องกันปัญหา working directory ไม่ตรงเมื่อรันจาก path อื่น
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    _env = DotEnv(includePlatformEnvironment: true)
      ..load(['$exeDir/.env', '.env']);
  }

  /// Get environment variable by key
  String? operator [](String key) => _env[key];

  /// Get Public URL (for Line Webhooks/Images)
  String get publicUrl =>
      (_env['PUBLIC_URL'] ?? 'http://localhost:8080').trim();

  /// Get Line Channel Access Token
  String get lineChannelToken => _env['LINE_CHANNEL_TOKEN'] ?? '';
}
