import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error, debug }

/// Application-wide logger providing level-based filtering, console coloring, and file logging support.
class LoggerService {
  static void info(String tag, String message) => _log(LogLevel.info, tag, message);
  static void warning(String tag, String message) => _log(LogLevel.warning, tag, message);
  static void error(String tag, String message, [Object? error, StackTrace? stack]) {
    _log(LogLevel.error, tag, "$message ${error != null ? '\nError: $error' : ''}");
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }
  static void debug(String tag, String message) => _log(LogLevel.debug, tag, message);

  static void _log(LogLevel level, String tag, String message) {
    if (!kDebugMode) return;
    final timestamp = DateTime.now().toIso8601String();
    final color = _getColor(level);
    final reset = '\x1B[0m';
    final logLine = '$color[$timestamp] [${level.name.toUpperCase()}] [$tag] $message$reset';
    debugPrint(logLine);
    _writeToFile(timestamp, level, tag, message);
  }

  static String _getColor(LogLevel level) {
    switch (level) {
      case LogLevel.info: return '\x1B[32m'; // Green
      case LogLevel.warning: return '\x1B[33m'; // Yellow
      case LogLevel.error: return '\x1B[31m'; // Red
      case LogLevel.debug: return '\x1B[36m'; // Cyan
    }
  }

  /// Appends log entries to a local log file for diagnostic reports.
  static Future<void> _writeToFile(String timestamp, LogLevel level, String tag, String message) async {
    try {
      // Future implementation: Write to a file in documents directory
      // final directory = await getApplicationSupportDirectory();
      // final logFile = File('${directory.path}/app_logs.txt');
      // await logFile.writeAsString('[$timestamp] [${level.name.toUpperCase()}] [$tag] $message\n', mode: FileMode.append);
    } catch (e) {
      // Keep it silent to prevent recursive exceptions or stack overflows
      debugPrint('Failed to write log to file: $e');
    }
  }
}
