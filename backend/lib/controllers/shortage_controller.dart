import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';

class ShortageController {
  Router get router {
    final router = Router();

    // GET /api/v1/shortages - List open shortages
    router.get('/', _listShortages);

    // POST /api/v1/shortages - Create new shortage
    router.post('/', _createShortage);

    // PUT /api/v1/shortages/<id>/order - Mark as ordered
    router.put('/<id>/order', _markAsOrdered);

    // DELETE /api/v1/shortages/<id> - Delete shortage
    router.delete('/<id>', _deleteShortage);

    return router;
  }

  // GET / -> List
  Future<Response> _listShortages(Request request) async {
    stdout.writeln('📦 [ShortageController] Fetching shortages...');
    try {
      final conn = await DbConfig().connection;
      // Query specific to the requirement: Open + Ordered within last 24h (or 6h as per old logic)
      // Old logic: OR (status = 'ordered' AND ordered_at >= DATE_SUB(NOW(), INTERVAL 6 HOUR))
      const sql = '''
        SELECT * FROM shortage_logs 
        WHERE status = 'open' 
           OR (status = 'ordered' AND ordered_at >= DATE_SUB(NOW(), INTERVAL 6 HOUR))
        ORDER BY FIELD(status, 'open', 'ordered'), created_at DESC 
        LIMIT 100
      ''';

      final results = await conn.execute(sql);
      stdout.writeln(
        '📦 [ShortageController] Fetched ${results.rows.length} items.',
      );

      final List<Map<String, dynamic>> list = [];
      for (final row in results.rows) {
        final data = row.assoc();
        // Ensure keys match what frontend expects (camelCase usually preferred in JSON)
        // Frontend ShortageLogModel uses map['item_name'], map['status'], etc. from MySQL row directly.
        // So we can return snake_case as is, or convert.
        // Let's return as is to minimize frontend changes for serialization.
        list.add(data);
      }

      return Response.ok(
        jsonEncode(list),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stdout.writeln('❌ [ShortageController] Error fetching shortages: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to list shortages: $e'}),
      );
    }
  }

  // POST / -> Create
  Future<Response> _createShortage(Request request) async {
    try {
      final payload = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(payload);

      final itemName = data['itemName'];
      final reporterId = data['reporterId'];

      if (itemName == null || reporterId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing itemName or reporterId'}),
        );
      }

      final conn = await DbConfig().connection;
      const sql = '''
        INSERT INTO shortage_logs (item_name, status, reported_by, created_at)
        VALUES (:itemName, 'open', :reporterId, NOW())
      ''';

      await conn.execute(sql, {'itemName': itemName, 'reporterId': reporterId});

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Shortage created'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create shortage: $e'}),
      );
    }
  }

  // PUT /<id>/order -> Mark Ordered
  Future<Response> _markAsOrdered(Request request, String idStr) async {
    try {
      final id = int.tryParse(idStr);
      if (id == null) return Response.badRequest(body: 'Invalid ID');

      final conn = await DbConfig().connection;
      const sql = '''
        UPDATE shortage_logs 
        SET status = 'ordered', ordered_at = NOW() 
        WHERE id = :id
      ''';

      await conn.execute(sql, {'id': id});

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Marked as ordered'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to mark ordered: $e'}),
      );
    }
  }

  // DELETE /<id> -> Delete
  Future<Response> _deleteShortage(Request request, String idStr) async {
    try {
      final id = int.tryParse(idStr);
      if (id == null) return Response.badRequest(body: 'Invalid ID');

      final conn = await DbConfig().connection;
      const sql = 'DELETE FROM shortage_logs WHERE id = :id';

      await conn.execute(sql, {'id': id});

      return Response.ok(
        jsonEncode({'success': true, 'message': 'Deleted successfully'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete: $e'}),
      );
    }
  }
}
