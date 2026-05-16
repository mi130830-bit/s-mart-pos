import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';

class HealthController {
  Router get router {
    final router = Router();
    router.get('/', _healthCheck);
    return router;
  }

  Future<Response> _healthCheck(Request request) async {
    final Map<String, dynamic> status = {
      'status': 'ok',
      'service': 'pos_backend',
      'version': '1.1.0',
      'database': 'unknown',
    };

    try {
      final conn = await DbConfig().connection;
      // Simple query to check DB connection
      await conn.execute('SELECT 1');
      status['database'] = 'connected';
    } catch (e) {
      status['database'] = 'error';
      status['error'] = e.toString();
    }

    return Response.ok(
      jsonEncode(status),
      headers: {'content-type': 'application/json'},
    );
  }
}
