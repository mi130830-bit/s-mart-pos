import 'dart:async';
import 'dart:io';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'mysql_connection_pool.dart';
import '../logger_service.dart';

/// Raised when a connection is lost while a write may already have reached MySQL.
///
/// Callers must reconcile the operation (for example via its idempotency key)
/// before allowing the user to submit it again.
class MySqlWriteOutcomeUnknownException implements Exception {
  final Object cause;

  const MySqlWriteOutcomeUnknownException(this.cause);

  @override
  String toString() =>
      'MySQL write outcome is unknown because the connection was lost. '
      'Do not retry automatically; reconciliation is required. Cause: $cause';
}

/// Handles SQL statements and queries with safe connection-loss recovery.
class MySqlQueryExecutor {
  final MySQLConnectionManager _pool;

  // The desktop app uses one physical MySQL connection.  A transaction must
  // therefore exclude every other zone until COMMIT/ROLLBACK has completed.
  static final Object _transactionZoneKey = Object();
  Future<void> _queueTail = Future<void>.value();

  MySqlQueryExecutor({MySQLConnectionManager? pool})
      : _pool = pool ?? MySQLConnectionManager();

  bool get _ownsExclusiveAccess => Zone.current[_transactionZoneKey] != null;

  Future<T> runExclusiveTransaction<T>(Future<T> Function() action) async {
    if (_ownsExclusiveAccess) {
      throw StateError('Nested MySQL transaction scopes are not supported.');
    }
    final release = Completer<void>();
    final previous = _queueTail;
    _queueTail = release.future;
    await previous;
    try {
      return await runZoned(action,
          zoneValues: {_transactionZoneKey: Object()});
    } finally {
      release.complete();
    }
  }

  Future<void> _waitForConnectionAccess() async {
    if (!_ownsExclusiveAccess) await _queueTail;
  }

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

  /// Executes INSERT, UPDATE, or DELETE statements.
  ///
  /// A write is never retried after a connection loss: MySQL may have committed
  /// it before the client lost the response. Retrying would duplicate money or
  /// stock records. Callers receive [MySqlWriteOutcomeUnknownException] and
  /// must reconcile the operation before a user retries it.
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) async {
    await _waitForConnectionAccess();
    if (!_pool.isConnected()) {
      if (_ownsExclusiveAccess) {
        throw MySqlWriteOutcomeUnknownException(StateError(
            'MySQL connection is unavailable inside a transaction scope'));
      }
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
        LoggerService.warning(
          'MySQLQuery',
          'Connection lost during write (${e.runtimeType}); not retrying because '
              'the write outcome is unknown and requires reconciliation.',
        );
        throw MySqlWriteOutcomeUnknownException(e);
      }
      rethrow;
    }
  }

  /// Executes a SELECT query, returning maps of row column associations. Reconnects and retries once if connection is lost.
  Future<List<Map<String, dynamic>>> query(String sql,
      [Map<String, dynamic>? params]) async {
    await _waitForConnectionAccess();
    if (!_pool.isConnected()) {
      if (_ownsExclusiveAccess) {
        throw StateError(
            'MySQL connection is unavailable inside a transaction scope');
      }
      await _pool.connect();
      if (!_pool.isConnected()) return [];
    }
    final conn = _pool.connection;
    if (conn == null) return [];

    try {
      final results =
          await conn.execute(sql, params).timeout(const Duration(seconds: 15));
      return results.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      LoggerService.error('MySQLQuery', 'Error executing query: $e');
      if (_isRetryableError(e)) {
        if (_ownsExclusiveAccess) {
          // Reconnecting would silently abandon the active transaction.
          rethrow;
        }
        LoggerService.warning('MySQLQuery',
            'Connection lost (${e.runtimeType}). Resetting and retrying query...');
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
