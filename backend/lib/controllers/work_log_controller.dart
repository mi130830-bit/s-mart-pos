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
      if (logs.any((log) => log is! Map)) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid logs'}));
      }

      final conn = await DbConfig().connection;
      await conn.execute('START TRANSACTION');

      try {
        var noOpCount = 0;
        for (final rawLog in logs) {
          final logData = Map<String, dynamic>.from(rawLog as Map);
          final syncId = logData['sync_id']?.toString().trim() ?? '';
          final delivererId = logData['deliverer_id']?.toString().trim() ?? '';
          final loggedAt = logData['logged_at'];
          final items = logData['items'] as List<dynamic>? ?? [];
          if (!_isValidSyncId(syncId) ||
              delivererId.isEmpty ||
              loggedAt == null ||
              items.any((item) => item is! Map)) {
            await conn.execute('ROLLBACK');
            return Response.badRequest(
              body: jsonEncode({'error': 'Invalid work log'}),
            );
          }
          if (!await _canManageDeliverer(conn, request, delivererId)) {
            await conn.execute('ROLLBACK');
            return Response.forbidden(
              jsonEncode({
                'error': 'Cannot create a work log for another user',
              }),
            );
          }

          // A checked sheet is immutable.  A network retry of the exact same
          // payload succeeds as a no-op; any changed payload is rejected.
          final existing = await conn.execute(
            '''SELECT deliverer_id, stock_checked_at
               FROM shop_work_logs WHERE sync_id = :syncId FOR UPDATE''',
            {'syncId': syncId},
          );
          if (existing.rows.isNotEmpty &&
              !await _canManageDeliverer(
                conn,
                request,
                existing.rows.first.colByName('deliverer_id')?.toString() ?? '',
              )) {
            await conn.execute('ROLLBACK');
            return Response.forbidden(
              jsonEncode({'error': 'Cannot update another user\'s work log'}),
            );
          }
          if (existing.rows.isNotEmpty &&
              existing.rows.first.colByName('stock_checked_at') != null) {
            final unchanged = await _matchesExistingLog(
              conn,
              syncId: syncId,
              delivererId: delivererId,
              items: items,
            );
            if (!unchanged) {
              await conn.execute('ROLLBACK');
              return Response(
                409,
                body: jsonEncode({
                  'error': 'stock_check_processed',
                  'sync_id': syncId,
                }),
              );
            }
            noOpCount++;
            continue;
          }

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
            },
          );

          // If updating, delete existing items first
          await conn.execute(
            'DELETE FROM shop_work_log_items WHERE log_sync_id = :syncId',
            {'syncId': syncId},
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
              },
            );
          }
        }
        await conn.execute('COMMIT');
        return Response.ok(
          jsonEncode({
            'status': 'success',
            'synced_count': logs.length - noOpCount,
            'noop_count': noOpCount,
          }),
        );
      } catch (e) {
        await conn.execute('ROLLBACK');
        rethrow;
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  // GET /hr/worklogs
  Future<Response> _getWorkLogs(Request request) async {
    try {
      final conn = await DbConfig().connection;

      // Optional filters
      final delivererId = request.url.queryParameters['deliverer_id'];

      String sql = '''
        SELECT l.sync_id, l.deliverer_id,
               COALESCE(
                 CONVERT(e.display_name USING utf8mb4) COLLATE utf8mb4_unicode_ci,
                 CONVERT(u.displayName USING utf8mb4) COLLATE utf8mb4_unicode_ci,
                 CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
               ) AS deliverer_name,
               l.logged_at,
               i.description, i.quantity, i.unit
        FROM shop_work_logs l
        LEFT JOIN shop_work_log_items i
          ON CONVERT(l.sync_id USING utf8mb4) COLLATE utf8mb4_unicode_ci =
             CONVERT(i.log_sync_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
        LEFT JOIN employee_profile e
          ON e.id = (
            SELECT ep.id
            FROM employee_profile ep
            WHERE CONVERT(ep.firebase_uid USING utf8mb4) COLLATE utf8mb4_bin =
                  CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_bin
               OR CONVERT(CAST(ep.user_id AS CHAR) USING utf8mb4) COLLATE utf8mb4_unicode_ci =
                  CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
               OR CONVERT(CAST(ep.id AS CHAR) USING utf8mb4) COLLATE utf8mb4_unicode_ci =
                  CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
            ORDER BY CASE
              WHEN CONVERT(ep.firebase_uid USING utf8mb4) COLLATE utf8mb4_bin =
                   CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_bin THEN 0
              WHEN CONVERT(CAST(ep.user_id AS CHAR) USING utf8mb4) COLLATE utf8mb4_unicode_ci =
                   CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci THEN 1
              WHEN CONVERT(CAST(ep.id AS CHAR) USING utf8mb4) COLLATE utf8mb4_unicode_ci =
                   CONVERT(l.deliverer_id USING utf8mb4) COLLATE utf8mb4_unicode_ci THEN 2
              ELSE 3
            END, ep.id ASC
            LIMIT 1
          )
        LEFT JOIN user u ON u.id = e.user_id
      ''';

      Map<String, dynamic> params = {};
      var countSql = 'SELECT COUNT(*) AS total FROM shop_work_logs l';
      if (delivererId != null && delivererId.isNotEmpty) {
        sql += ''' WHERE CONVERT(l.deliverer_id USING utf8mb4)
            COLLATE utf8mb4_bin = CONVERT(:delivererId USING utf8mb4)
            COLLATE utf8mb4_bin''';
        countSql += ''' WHERE CONVERT(l.deliverer_id USING utf8mb4)
            COLLATE utf8mb4_bin = CONVERT(:delivererId USING utf8mb4)
            COLLATE utf8mb4_bin''';
        params['delivererId'] = delivererId;
      }

      sql += ' ORDER BY l.logged_at DESC LIMIT 200';

      final result = await conn.execute(sql, params);
      final countResult = await conn.execute(countSql, params);
      final total =
          int.tryParse(
            countResult.rows.first.colByName('total')?.toString() ?? '0',
          ) ??
          0;

      // Group items by log
      Map<String, Map<String, dynamic>> logsMap = {};

      for (final row in result.rows) {
        final syncId = row.colByName('sync_id')!;

        if (!logsMap.containsKey(syncId)) {
          logsMap[syncId] = {
            'sync_id': syncId,
            'deliverer_id': row.colByName('deliverer_id'),
            'deliverer_name': row.colByName('deliverer_name'),
            'logged_at': row.colByName('logged_at'),
            'items': [],
          };
        }

        if (row.colByName('description') != null) {
          logsMap[syncId]!['items'].add({
            'description': row.colByName('description'),
            'quantity':
                double.tryParse(row.colByName('quantity') ?? '1') ?? 1.0,
            'unit': row.colByName('unit'),
          });
        }
      }

      return Response.ok(
        jsonEncode({
          'logs': logsMap.values.toList(),
          // Only a complete snapshot may remove a cached record on S-Link.
          'is_complete': total <= 200,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  // DELETE /hr/worklogs/:syncId
  Future<Response> _deleteWorkLog(Request request, String syncId) async {
    try {
      final conn = await DbConfig().connection;

      await conn.execute('START TRANSACTION');
      final existing = await conn.execute(
        '''SELECT deliverer_id, stock_checked_at
           FROM shop_work_logs WHERE sync_id = :syncId FOR UPDATE''',
        {'syncId': syncId},
      );
      if (existing.rows.isEmpty) {
        await conn.execute('ROLLBACK');
        return Response.ok(
          jsonEncode({'status': 'success', 'already_deleted': true}),
        );
      }
      final delivererId =
          existing.rows.first.colByName('deliverer_id')?.toString() ?? '';
      if (!await _canManageDeliverer(conn, request, delivererId)) {
        await conn.execute('ROLLBACK');
        return Response.forbidden(
          jsonEncode({'error': 'Cannot delete another user\'s work log'}),
        );
      }
      if (existing.rows.first.colByName('stock_checked_at') != null) {
        await conn.execute('ROLLBACK');
        return Response(
          409,
          body: jsonEncode({
            'error': 'stock_check_processed',
            'sync_id': syncId,
          }),
        );
      }

      // Items are deleted automatically via CASCADE.
      await conn.execute('DELETE FROM shop_work_logs WHERE sync_id = :syncId', {
        'syncId': syncId,
      });
      await conn.execute('COMMIT');

      return Response.ok(jsonEncode({'status': 'success'}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  bool _isValidSyncId(String value) =>
      RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(value);

  bool _isPrivileged(Request request) {
    final user = request.context['user'];
    final role = user is Map ? user['role']?.toString().toUpperCase() : '';
    return role == 'ADMIN' || role == 'HR';
  }

  Future<bool> _canManageDeliverer(
    dynamic conn,
    Request request,
    String delivererId,
  ) async {
    if (_isPrivileged(request)) return true;
    final user = request.context['user'];
    final userId = user is Map ? user['id']?.toString() : null;
    if (userId == null || userId.isEmpty) return false;
    if (delivererId == userId) return true;
    final result = await conn.execute(
      '''SELECT 1 FROM employee_profile
         WHERE user_id = :userId
           AND (CAST(id AS CHAR) = :delivererId OR firebase_uid = :delivererId)
         LIMIT 1''',
      {'userId': userId, 'delivererId': delivererId},
    );
    return result.rows.isNotEmpty;
  }

  Future<bool> _matchesExistingLog(
    dynamic conn, {
    required String syncId,
    required String delivererId,
    required List<dynamic> items,
  }) async {
    final header = await conn.execute(
      'SELECT deliverer_id FROM shop_work_logs WHERE sync_id = :syncId LIMIT 1',
      {'syncId': syncId},
    );
    if (header.rows.isEmpty ||
        header.rows.first.colByName('deliverer_id')?.toString() !=
            delivererId) {
      return false;
    }
    final saved = await conn.execute(
      '''SELECT description, quantity, unit FROM shop_work_log_items
         WHERE log_sync_id = :syncId ORDER BY id ASC''',
      {'syncId': syncId},
    );
    if (saved.rows.length != items.length) return false;
    for (var index = 0; index < items.length; index++) {
      final expected = Map<String, dynamic>.from(items[index] as Map);
      final row = saved.rows[index];
      final sameDescription =
          row.colByName('description')?.toString() ==
          expected['description']?.toString();
      final sameUnit =
          row.colByName('unit')?.toString() ==
          (expected['unit']?.toString() ?? 'ครั้ง');
      final savedQuantity = double.tryParse(
        row.colByName('quantity')?.toString() ?? '',
      );
      final requestedQuantity = double.tryParse(
        expected['quantity']?.toString() ?? '1',
      );
      if (!sameDescription ||
          !sameUnit ||
          savedQuantity == null ||
          requestedQuantity == null ||
          (savedQuantity - requestedQuantity).abs() > 0.00001) {
        return false;
      }
    }
    return true;
  }
}
