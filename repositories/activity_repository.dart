import 'package:flutter/foundation.dart';
import '../services/mysql_service.dart';

class ActivityRepository {
  final MySQLService _db = MySQLService();

  Future<void> log({
    int? userId,
    int branchId = 1,
    required String action,
    String? details,
  }) async {
    try {
      const sql = '''
        INSERT INTO activity_log (userId, branchId, action, details, createdAt)
        VALUES (:uid, :bid, :act, :det, NOW())
      ''';
      await _db.execute(sql, {
        'uid': userId,
        'bid': branchId,
        'act': action,
        'det': details,
      });
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLogs({
    int? branchId,
    int limit = 100,
  }) async {
    try {
      String sql = '''
        SELECT l.*, u.username, u.displayName
        FROM activity_log l
        LEFT JOIN user u ON l.userId = u.id
      ''';
      if (branchId != null) {
        sql += ' WHERE l.branchId = :bid';
      }
      sql += ' ORDER BY l.createdAt DESC LIMIT :limit';

      return await _db.query(sql, {
        if (branchId != null) 'bid': branchId,
        'limit': limit,
      });
    } catch (e) {
      debugPrint('Error getting activity logs: $e');
      return [];
    }
  }
}
