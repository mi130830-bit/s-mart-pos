import 'dart:async';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'mysql_connection_pool.dart';
import '../logger_service.dart';

/// Handles execution of SQL statements and queries with automatic connection-loss recovery (retries).
class MySqlQueryExecutor {
  final MySQLConnectionManager _pool;

  MySqlQueryExecutor({MySQLConnectionManager? pool})
      : _pool = pool ?? MySQLConnectionManager();

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
      final errStr = e.toString();
      if (errStr.contains('closed') || errStr.contains('Broken pipe')) {
        LoggerService.warning('MySQLQuery', 'Connection broken. Retrying execute...');
        await _pool.connect();
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
      final errStr = e.toString();
      if (errStr.contains('closed') || errStr.contains('Broken pipe')) {
        LoggerService.warning('MySQLQuery', 'Connection broken. Retrying query...');
        await _pool.connect();
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
