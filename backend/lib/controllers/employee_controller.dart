import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';

class EmployeeController {
  Router get router {
    final router = Router();
    router.get('/drivers', _getDrivers);
    return router;
  }

  Future<Response> _getDrivers(Request request) async {
    try {
      final conn = await DbConfig().connection;

      // ค้นหาพนักงานที่มี role_type = 'DRIVER' หรือที่มีคำว่า driver ใน position
      final result = await conn.execute(
        '''
        SELECT id, user_id, display_name, phone, role_type
        FROM employee_profile
        WHERE is_active = 1 AND (role_type = 'DRIVER' OR LOWER(position) LIKE '%driver%' OR LOWER(position) LIKE '%คนขับ%')
        ORDER BY display_name ASC
        '''
      );

      final List<Map<String, dynamic>> drivers = [];
      for (final row in result.rows) {
        final employeeId = row.colAt(0);
        final userId = row.colAt(1);
        drivers.add({
          // Account id is canonical for new S-Link assignments. Keep the
          // employee id so existing assignments and HR records remain valid.
          'id': userId ?? employeeId,
          'employee_id': employeeId,
          'name': row.colAt(2),
          'phone': row.colAt(3),
          'role': row.colAt(4),
        });
      }

      return Response.ok(
        jsonEncode({'drivers': drivers}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch drivers: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
