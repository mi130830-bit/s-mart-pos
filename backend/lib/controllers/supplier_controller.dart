import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db_config.dart';

/// Read-only supplier lookup for creating a purchase-order draft on S-Link.
class SupplierController {
  Router get router {
    final router = Router();
    router.get('/', _list);
    return router;
  }

  Future<Response> _list(Request request) async {
    final query = request.url.queryParameters['q']?.trim() ?? '';
    final requestedLimit = int.tryParse(
      request.url.queryParameters['limit'] ?? '',
    );
    final limit = (requestedLimit ?? 100).clamp(1, 100);
    final conn = await DbConfig().connection;
    final rows = await conn.execute(
      query.isEmpty
          ? 'SELECT id, name FROM supplier ORDER BY name LIMIT :limit'
          : 'SELECT id, name FROM supplier WHERE name LIKE :query ORDER BY name LIMIT :limit',
      query.isEmpty ? {'limit': limit} : {'query': '%$query%', 'limit': limit},
    );
    return Response.ok(
      jsonEncode(rows.rows.map((row) => row.assoc()).toList()),
      headers: {'content-type': 'application/json'},
    );
  }
}
