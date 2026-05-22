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

  /// Get writable data directory for storing dynamic files (like bills).
  /// Never writes inside C:\Program Files\ to avoid Access Denied errors.
  String get writableDir {
    // Priority 1: Standard Windows user directories
    if (Platform.isWindows) {
      final candidates = [
        Platform.environment['LOCALAPPDATA'],
        Platform.environment['APPDATA'],
        Platform.environment['USERPROFILE'],
      ];
      for (final base in candidates) {
        if (base != null && base.isNotEmpty && !base.contains('Program Files')) {
          final appDir = Directory('$base/S_Mart_POS');
          try {
            if (!appDir.existsSync()) appDir.createSync(recursive: true);
            stdout.writeln('📁 [EnvConfig] writableDir resolved to: ${appDir.path}');
            return appDir.path;
          } catch (_) {
            continue;
          }
        }
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final appDir = Directory('$home/.s_mart_pos');
        try {
          if (!appDir.existsSync()) appDir.createSync(recursive: true);
          return appDir.path;
        } catch (_) {}
      }
    }

    // Priority 2: Sibling "data" folder next to the exe (writable by user)
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      // Avoid writing inside Program Files
      if (!exeDir.path.contains('Program Files') &&
          !exeDir.path.contains('Program Files (x86)')) {
        final dataDir = Directory('${exeDir.path}/pos_data');
        if (!dataDir.existsSync()) dataDir.createSync(recursive: true);
        stdout.writeln('📁 [EnvConfig] writableDir (exe-sibling) resolved to: ${dataDir.path}');
        return dataDir.path;
      }
    } catch (_) {}

    // Priority 3: System temp as last resort
    final tempDir = Directory('${Directory.systemTemp.path}/S_Mart_POS');
    try {
      if (!tempDir.existsSync()) tempDir.createSync(recursive: true);
    } catch (_) {}
    stdout.writeln('⚠️ [EnvConfig] writableDir fallback to temp: ${tempDir.path}');
    return tempDir.path;
  }
}
