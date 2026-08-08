import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db_config.dart';

/// HR APIs used by S-Link.  MySQL is the source of truth for the POS and the
/// mobile app; Firebase must not be used as a second HR database.
class HrController {
  Router get router {
    final router = Router();
    router.get('/leaves', _listLeaves);
    router.post('/leaves', _createLeave);
    router.post('/leaves/<id>/status', _updateLeaveStatus);
    router.get('/advances', _listAdvances);
    router.post('/advances', _createAdvance);
    router.post('/advances/<id>/status', _updateAdvanceStatus);
    return router;
  }

  Future<Response> _listLeaves(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final rows = await conn.execute('''
        SELECT l.*, COALESCE(NULLIF(e.firebase_uid, ''), CAST(e.user_id AS CHAR)) AS user_id,
               COALESCE(e.display_name, u.displayName) AS employee_name
        FROM leave_request l
        JOIN employee_profile e ON e.id = l.employee_id
        LEFT JOIN user u ON u.id = e.user_id
        ORDER BY l.created_at DESC
      ''');
      return _ok(
        rows.rows
            .map(
              (row) => {
                'id': row.colByName('id')?.toString(),
                'user_id': row.colByName('user_id')?.toString(),
                'employee_name':
                    row.colByName('employee_name')?.toString() ?? '',
                'leave_type':
                    row.colByName('leave_type')?.toString() ?? 'PERSONAL',
                'leave_format':
                    row.colByName('leave_format')?.toString() ?? 'FULL_DAY',
                'start_date': row.colByName('start_date')?.toString(),
                'end_date': row.colByName('end_date')?.toString(),
                'total_days': row.colByName('total_days')?.toString(),
                'reason': row.colByName('reason')?.toString() ?? '',
                'status': row.colByName('status')?.toString() ?? 'PENDING',
              },
            )
            .toList(),
      );
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _createLeave(Request request) async {
    try {
      final data = await _body(request);
      final conn = await DbConfig().connection;
      final employeeId = await _employeeId(conn, data['user_id']);
      if (employeeId == null) {
        return Response.badRequest(body: 'Unknown employee');
      }
      await conn.execute(
        '''
        INSERT INTO leave_request
          (employee_id, leave_type, leave_format, start_date, end_date, total_days, reason, status)
        VALUES (:employeeId, :type, :format, :start, :end, :days, :reason, 'PENDING')
      ''',
        {
          'employeeId': employeeId,
          'type': data['leave_type'] ?? 'PERSONAL',
          'format': data['leave_format'] ?? 'FULL_DAY',
          'start': data['start_date'],
          'end': data['end_date'],
          'days': data['total_days'],
          'reason': data['reason'] ?? '',
        },
      );
      return _ok({'status': 'success'});
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _updateLeaveStatus(Request request, String id) async {
    try {
      final data = await _body(request);
      final status = data['status']?.toString().toUpperCase();
      if (status != 'APPROVED' && status != 'REJECTED') {
        return Response.badRequest(body: 'Invalid leave status');
      }
      final conn = await DbConfig().connection;
      await conn.execute(
        '''
        UPDATE leave_request
        SET status = :status, approved_at = IF(:status = 'APPROVED', NOW(), approved_at)
        WHERE id = :id
      ''',
        {'id': id, 'status': status},
      );
      return _ok({'status': 'success'});
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _listAdvances(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final rows = await conn.execute('''
        SELECT a.*, COALESCE(NULLIF(e.firebase_uid, ''), CAST(e.user_id AS CHAR)) AS user_id,
               COALESCE(e.display_name, u.displayName) AS employee_name
        FROM advance_payment a
        JOIN employee_profile e ON e.id = a.employee_id
        LEFT JOIN user u ON u.id = e.user_id
        ORDER BY a.created_at DESC
      ''');
      return _ok(
        rows.rows
            .map(
              (row) => {
                'id': row.colByName('id')?.toString(),
                'user_id': row.colByName('user_id')?.toString(),
                'employee_name':
                    row.colByName('employee_name')?.toString() ?? '',
                'amount': row.colByName('amount')?.toString(),
                'reason': row.colByName('reason')?.toString() ?? '',
                'installment_amount': row
                    .colByName('installment_amount')
                    ?.toString(),
                'status': row.colByName('status')?.toString() ?? 'PENDING',
                'created_at': row.colByName('created_at')?.toString(),
              },
            )
            .toList(),
      );
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _createAdvance(Request request) async {
    try {
      final data = await _body(request);
      final conn = await DbConfig().connection;
      final employeeId = await _employeeId(conn, data['user_id']);
      if (employeeId == null) {
        return Response.badRequest(body: 'Unknown employee');
      }
      await conn.execute(
        '''
        INSERT INTO advance_payment
          (employee_id, amount, request_date, reason, installment_amount, status)
        VALUES (:employeeId, :amount, CURDATE(), :reason, :installment, 'PENDING')
      ''',
        {
          'employeeId': employeeId,
          'amount': data['amount'],
          'reason': data['reason'] ?? '',
          'installment': data['installment_amount'],
        },
      );
      return _ok({'status': 'success'});
    } catch (e) {
      return _error(e);
    }
  }

  Future<Response> _updateAdvanceStatus(Request request, String id) async {
    try {
      final data = await _body(request);
      final status = data['status']?.toString().toUpperCase();
      if (status != 'APPROVED' && status != 'REJECTED') {
        return Response.badRequest(body: 'Invalid advance status');
      }
      final conn = await DbConfig().connection;
      await conn.execute(
        '''
        UPDATE advance_payment
        SET status = :status,
            approved_at = IF(:status = 'APPROVED', NOW(), approved_at),
            remaining_amount = IF(:status = 'APPROVED', amount, remaining_amount)
        WHERE id = :id
      ''',
        {'id': id, 'status': status},
      );
      return _ok({'status': 'success'});
    } catch (e) {
      return _error(e);
    }
  }

  Future<Map<String, dynamic>> _body(Request request) async =>
      Map<String, dynamic>.from(
        jsonDecode(await request.readAsString()) as Map,
      );

  Future<int?> _employeeId(dynamic conn, dynamic userId) async {
    final result = await conn.execute(
      '''
      SELECT id FROM employee_profile
      WHERE CAST(user_id AS CHAR) = :userId OR firebase_uid = :userId
      LIMIT 1
    ''',
      {'userId': userId?.toString() ?? ''},
    );
    return result.rows.isEmpty
        ? null
        : int.tryParse(result.rows.first.colByName('id')?.toString() ?? '');
  }

  Response _ok(dynamic data) => Response.ok(
    jsonEncode(data),
    headers: {'content-type': 'application/json'},
  );
  Response _error(Object error) => Response.internalServerError(
    body: jsonEncode({'error': error.toString()}),
  );
}
