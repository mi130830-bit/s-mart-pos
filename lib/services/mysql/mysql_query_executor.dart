import 'dart:async';
import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'mysql_connection_pool.dart';
import '../logger_service.dart';

/// Handles execution of SQL statements and queries with automatic connection-loss recovery (retries).
class MySqlQueryExecutor {
  final MySQLConnectionManager _pool;

  MySqlQueryExecutor({MySQLConnectionManager? pool})
      : _pool = pool ?? MySQLConnectionManager();

  /// ตรวจว่า error นี้ควร retry โดยการ reset + reconnect หรือไม่
  /// ครอบคลุม stale connection, SocketException, semaphore timeout ทุกกรณี
  bool _isRetryableError(Object e) {
    if (e is SocketException) return true;
    if (e is TimeoutException) return true;
    final s = e.toString().toLowerCase();
    return s.contains('closed') ||
        s.contains('broken pipe') ||
        s.contains('socketexception') ||
        s.contains('errno = 121') ||
        s.contains('semaphore') ||
        s.contains('connection reset') ||
        s.contains('connection timed out') ||
        s.contains('os error') ||
        s.contains('timeoutexception');
  }

  /// Executes INSERT, UPDATE, or DELETE statements. Reconnects and retries once if connection is lost.
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) async {
    if (!_pool.isConnected()) {
      await _pool.connect();
    }
    final conn = _pool.connection;
    if (conn == null) throw Exception('Database connection failed');

    try {
      return await conn
          .execute(sql, params)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      LoggerService.error('MySQLQuery', 'Error executing statement: $e');
      if (_isRetryableError(e)) {
        LoggerService.warning('MySQLQuery', 'Connection lost (${e.runtimeType}). Resetting and retrying execute...');
        await _pool.resetAndReconnect();
        final newConn = _pool.connection;
        if (newConn == null) throw Exception('Database connection failed on retry');
        return await newConn.execute(sql, params).timeout(const Duration(seconds: 15));
      }
      rethrow;
    }
  }

  /// Executes a SELECT query, returning maps of row column associations. Reconnects and retries once if connection is lost.
  Future<List<Map<String, dynamic>>> query(String sql, [Map<String, dynamic>? params]) async {
    if (!_pool.isConnected()) {
      await _pool.connect();
      if (!_pool.isConnected()) return [];
    }
    final conn = _pool.connection;
    if (conn == null) return [];

    try {
      final results = await conn
          .execute(sql, params)
          .timeout(const Duration(seconds: 15));
      return results.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      LoggerService.error('MySQLQuery', 'Error executing query: $e');
      if (_isRetryableError(e)) {
        LoggerService.warning('MySQLQuery', 'Connection lost (${e.runtimeType}). Resetting and retrying query...');
        await _pool.resetAndReconnect();
        final newConn = _pool.connection;
        if (newConn == null || !newConn.connected) return [];
        final retryResults = await newConn
            .execute(sql, params)
            .timeout(const Duration(seconds: 15));
        return retryResults.rows.map((row) => row.assoc()).toList();
      }
      rethrow;
    }
  }
}
