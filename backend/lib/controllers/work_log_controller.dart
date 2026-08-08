import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';

class WorkLogController {
  Router get router {
    final router = Router();
    router.post('/sync', _syncWorkLogs);
    router.get('/', _getWorkLogs);
    router.delete('/<syncId>', _deleteWorkLog);
    return router;
  }

  // POST /hr/worklogs/sync
  // Payload: { "logs": [ { "sync_id": "...", "deliverer_id": "...", "logged_at": "...", "items": [ ... ] } ] }
  Future<Response> _syncWorkLogs(Request request) async {
    try {
      final payload = await request.readAsString();
      if (payload.isEmpty) return Response.badRequest(body: 'Empty payload');
      
      final data = jsonDecode(payload);
      final List<dynamic> logs = data['logs'] ?? [];
      
      final conn = await DbConfig().connection;
      await conn.execute('START TRANSACTION');

      try {
        for (var logData in logs) {
          final syncId = logData['sync_id'];
          final delivererId = logData['deliverer_id'];
          final loggedAt = logData['logged_at'];
          final items = logData['items'] as List<dynamic>? ?? [];

          // Insert or Update the log
          await conn.execute(
            '''
            INSERT INTO shop_work_logs (sync_id, deliverer_id, logged_at)
            VALUES (:syncId, :delivererId, :loggedAt)
            ON DUPLICATE KEY UPDATE 
              deliverer_id = VALUES(deliverer_id),
              logged_at = VALUES(logged_at)
            ''',
            {
              'syncId': syncId,
              'delivererId': delivererId,
              'loggedAt': loggedAt,
            }
          );

          // If updating, delete existing items first
          await conn.execute(
            'DELETE FROM shop_work_log_items WHERE log_sync_id = :syncId',
            {'syncId': syncId}
          );

          // Insert items
          for (var item in items) {
            await conn.execute(
              '''
              INSERT INTO shop_work_log_items (log_sync_id, description, quantity, unit)
              VALUES (:syncId, :description, :quantity, :unit)
              ''',
              {
                'syncId': syncId,
                'description': item['description'],
                'quantity': item['quantity'] ?? 1.0,
                'unit': item['unit'] ?? 'ครั้ง',
              }
            );
          }
        }
        await conn.execute('COMMIT');
        return Response.ok(jsonEncode({'status': 'success', 'synced_count': logs.length}));
      } catch (e) {
        await conn.execute('ROLLBACK');
        rethrow;
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // GET /hr/worklogs
  Future<Response> _getWorkLogs(Request request) async {
    try {
      final conn = await DbConfig().connection;
      
      // Optional filters
      final delivererId = request.url.queryParameters['deliverer_id'];
      
      String sql = '''
        SELECT l.sync_id, l.deliverer_id, l.logged_at,
               i.description, i.quantity, i.unit
        FROM shop_work_logs l
        LEFT JOIN shop_work_log_items i ON l.sync_id = i.log_sync_id
      ''';
      
      Map<String, dynamic> params = {};
      if (delivererId != null && delivererId.isNotEmpty) {
        sql += ' WHERE l.deliverer_id = :delivererId';
        params['delivererId'] = delivererId;
      }
      
      sql += ' ORDER BY l.logged_at DESC LIMIT 200';

      final result = await conn.execute(sql, params);
      
      // Group items by log
      Map<String, Map<String, dynamic>> logsMap = {};
      
      for (final row in result.rows) {
        final syncId = row.colByName('sync_id')!;
        
        if (!logsMap.containsKey(syncId)) {
          logsMap[syncId] = {
            'sync_id': syncId,
            'deliverer_id': row.colByName('deliverer_id'),
            'logged_at': row.colByName('logged_at'),
            'items': []
          };
        }
        
        if (row.colByName('description') != null) {
          logsMap[syncId]!['items'].add({
            'description': row.colByName('description'),
            'quantity': double.tryParse(row.colByName('quantity') ?? '1') ?? 1.0,
            'unit': row.colByName('unit'),
          });
        }
      }

      return Response.ok(
        jsonEncode({'logs': logsMap.values.toList()}),
        headers: {'content-type': 'application/json'}
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  // DELETE /hr/worklogs/:syncId
  Future<Response> _deleteWorkLog(Request request, String syncId) async {
    try {
      final conn = await DbConfig().connection;
      
      // Items are deleted automatically via CASCADE
      await conn.execute(
        'DELETE FROM shop_work_logs WHERE sync_id = :syncId',
        {'syncId': syncId}
      );
      
      return Response.ok(jsonEncode({'status': 'success'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }
}
