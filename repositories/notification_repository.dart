import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

class NotificationRepository {
  final MySQLService _db;

  NotificationRepository(this._db);

  /// Ensures the log table exists.
  Future<void> initTable() async {
    const sql = '''
      CREATE TABLE IF NOT EXISTS notification_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        order_id INT,
        line_user_id VARCHAR(255),
        message_type VARCHAR(50),
        content TEXT,
        status VARCHAR(50),
        attempt_count INT DEFAULT 0,
        last_attempt_at DATETIME,
        error_message TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''';
    try {
      await _db.execute(sql, {});
    } catch (e) {
      debugPrint('⚠️ Create notification_logs table failed: $e');
    }
  }

  /// Creates a new log entry. Returns the ID of the inserted record.
  Future<int> createLog({
    required int orderId,
    required String lineUserId,
    required String messageType,
    required String content,
  }) async {
    const sql = '''
      INSERT INTO notification_logs 
      (order_id, line_user_id, message_type, content, status, attempt_count, created_at)
      VALUES (:oid, :uid, :type, :content, 'PENDING', 0, NOW())
    ''';
    try {
      final res = await _db.execute(sql, {
        'oid': orderId,
        'uid': lineUserId,
        'type': messageType,
        'content': content,
      });
      return res.lastInsertID.toInt();
    } catch (e) {
      debugPrint('⚠️ Create Notification Log Error: $e');
      return -1;
    }
  }

  /// Updates the status and attempt count of a log entry.
  Future<void> updateLog(int id,
      {required String status, String? errorMessage}) async {
    String sql = '''
      UPDATE notification_logs 
      SET status = :status, 
          attempt_count = attempt_count + 1,
          last_attempt_at = NOW()
    ''';

    final params = <String, dynamic>{'status': status, 'id': id};

    if (errorMessage != null) {
      sql += ', error_message = :err';
      params['err'] = errorMessage;
    }

    sql += ' WHERE id = :id';

    try {
      await _db.execute(sql, params);
    } catch (e) {
      debugPrint('⚠️ Update Notification Log Error: $e');
    }
  }

  /// Reset a log to allow re-sending
  Future<void> resetLog(int id) async {
    const sql = '''
      UPDATE notification_logs 
      SET status = 'PENDING', attempt_count = 0, last_attempt_at = NULL, error_message = NULL
      WHERE id = :id
    ''';
    try {
      await _db.execute(sql, {'id': id});
    } catch (e) {
      debugPrint('⚠️ Reset Log Error: $e');
    }
  }

  /// Retrieves logs that need to be retried (PENDING or RETRYING)
  Future<List<Map<String, dynamic>>> getPendingLogs() async {
    const sql = '''
      SELECT * FROM notification_logs 
      WHERE status IN ('PENDING', 'RETRYING')
      ORDER BY created_at ASC
      LIMIT 50
    ''';
    try {
      final results = await _db.query(sql, {});
      return results.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('⚠️ Fetch Pending Logs Error: $e');
      return [];
    }
  }

  /// Marks a log as SUCCESS
  Future<void> markAsSuccess(int id) async {
    const sql = '''
      UPDATE notification_logs 
      SET status = 'SUCCESS', last_attempt_at = NOW(), error_message = NULL
      WHERE id = :id
    ''';
    try {
      await _db.execute(sql, {'id': id});
    } catch (e) {
      debugPrint('⚠️ Mark Log Success Error: $e');
    }
  }

  /// Marks a log as FAILED (final state)
  Future<void> markAsFailed(int id, String error) async {
    const sql = '''
      UPDATE notification_logs 
      SET status = 'FAILED', last_attempt_at = NOW(), error_message = :err
      WHERE id = :id
    ''';
    try {
      await _db.execute(sql, {'id': id, 'err': error});
    } catch (e) {
      debugPrint('⚠️ Mark Log Failed Error: $e');
    }
  }

  // ✅ New Method: Clear Logs
  Future<void> clearLogs({bool onlySuccess = false}) async {
    try {
      if (onlySuccess) {
        await _db.execute('DELETE FROM notification_logs WHERE status = "SUCCESS" OR status = "FAILED"');
      } else {
        await _db.execute('DELETE FROM notification_logs');
      }
    } catch (e) {
      debugPrint('Error clearing logs: $e');
    }
  }

  /// Retrieves all logs for display
  Future<List<Map<String, dynamic>>> getLogs(
      {int limit = 50, int offset = 0}) async {
    final sql = '''
      SELECT * FROM notification_logs 
      ORDER BY created_at DESC
      LIMIT $limit OFFSET $offset
    ''';
    try {
      final results = await _db.query(sql); // Remove params map for LIMIT
      return results.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      debugPrint('⚠️ Fetch Logs Error: $e');
      return [];
    }
  }
}
