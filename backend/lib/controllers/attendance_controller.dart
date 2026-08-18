import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';

class AttendanceController {
  Router get router {
    final router = Router();
    router.get('/today', _getTodayAttendance);
    router.get('/list', _listAttendance);
    router.post('/sync', _syncAttendance);
    router.post('/cleanup', _cleanupOldAttendance);
    return router;
  }

  // GET /attendance/list?date=yyyy-MM-dd
  Future<Response> _listAttendance(Request request) async {
    try {
      final date =
          request.url.queryParameters['date'] ??
          DateTime.now().toIso8601String().split('T').first;
      final conn = await DbConfig().connection;
      final rows = await conn.execute(
        '''
        SELECT a.*,
               COALESCE(NULLIF(e.firebase_uid, ''), CAST(e.user_id AS CHAR)) AS user_id,
               COALESCE(e.display_name, u.displayName) AS employee_name
        FROM attendance_log a
        JOIN employee_profile e ON e.id = a.employee_id
        LEFT JOIN user u ON u.id = e.user_id
        WHERE DATE(a.date) = :date
        ORDER BY a.clock_in ASC
      ''',
        {'date': date},
      );

      final data = rows.rows
          .map(
            (row) => {
              'id': row.colByName('id')?.toString(),
              'user_id': row.colByName('user_id')?.toString(),
              'employee_name': row.colByName('employee_name')?.toString() ?? '',
              'date': date,
              'check_in_time': row.colByName('clock_in')?.toString(),
              'check_out_time': row.colByName('clock_out')?.toString(),
              'temp_out_time': row.colByName('temp_out')?.toString(),
              'back_to_work_time': row.colByName('back_to_work')?.toString(),
              'status': row.colByName('status')?.toString() ?? 'PRESENT',
              'method': row.colByName('method')?.toString(),
              'note': row.colByName('note')?.toString(),
            },
          )
          .toList();
      return Response.ok(
        jsonEncode(data),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // GET /attendance/today
  Future<Response> _getTodayAttendance(Request request) async {
    try {
      final userId = request.url.queryParameters['user_id'];
      stdout.writeln(
        '🔍 [AttendanceController] /today called with user_id: $userId, url: ${request.url}',
      );
      if (userId == null || userId.isEmpty) {
        stderr.writeln('❌ [AttendanceController] Missing user_id parameter');
        return Response.badRequest(
          body: jsonEncode({'error': 'Missing user_id parameter'}),
        );
      }

      final dateStr =
          request.url.queryParameters['date'] ??
          DateTime.now().toIso8601String().split('T')[0];
      stdout.writeln('🔍 [AttendanceController] date: $dateStr');

      final conn = await DbConfig().connection;
      final empId = await _resolveEmployeeId(conn, userId);
      if (empId == null) {
        return Response.ok(jsonEncode(null));
      }

      final result = await conn.execute(
        '''
        SELECT a.*, e.user_id as employee_user_id
        FROM attendance_log a
        JOIN employee_profile e ON a.employee_id = e.id
        WHERE a.employee_id = :empId AND DATE(a.date) = :date
        ORDER BY a.clock_in DESC
        LIMIT 1
        ''',
        {'empId': empId, 'date': dateStr},
      );

      if (result.rows.isEmpty) {
        return Response.ok(jsonEncode(null));
      }

      final row = result.rows.first;
      final String? clockInStr = row.colByName('clock_in')?.toString();
      String? clockOutStr = row.colByName('clock_out')?.toString();

      if (clockInStr != null && clockOutStr != null) {
        try {
          final cin = DateTime.parse(clockInStr);
          final cout = DateTime.parse(clockOutStr);
          if (cout.isBefore(cin)) {
            clockOutStr = null; // Ignore stale check out from prior session
          }
        } catch (_) {}
      }

      // We need to return it in the format Mobile expects (AttendanceLog model)
      final responseData = {
        'id': row.colByName('id')?.toString(),
        'user_id': row.colByName('employee_user_id')?.toString(),
        'date': dateStr,
        'check_in_time': clockInStr,
        'check_out_time': clockOutStr,
        // Map the latest temp out logic. (For S-Link, it mostly cares about latest).
        // Since backend might store tempOut1, 2, 3... we need to find the latest active.
        // Actually, for simple integration, returning what we have is good.
        // Let's assume Mobile only handles 1 temp out at a time, or the latest one.
        'temp_out_time':
            (row.colByName('temp_out_3') ??
                    row.colByName('temp_out_2') ??
                    row.colByName('temp_out'))
                ?.toString(),
        'back_to_work_time':
            (row.colByName('back_to_work_3') ??
                    row.colByName('back_to_work_2') ??
                    row.colByName('back_to_work'))
                ?.toString(),
        'check_in_lat': row.colByName('latitude'),
        'check_in_lng': row.colByName('longitude'),
        'status': row.colByName('status'),
        'method': row.colByName('method'),
        'note': row.colByName('note'),
      };

      return Response.ok(
        jsonEncode(responseData),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
      );
    }
  }

  // POST /attendance/sync
  // Receives an array of logs from Isar and processes them.
  Future<Response> _syncAttendance(Request request) async {
    try {
      final payload = await request.readAsString();
      if (payload.isEmpty) return Response.badRequest(body: 'Empty payload');

      final data = jsonDecode(payload);
      final List<dynamic> logs = data['logs'] ?? [];

      if (logs.isEmpty) {
        return Response.ok(
          jsonEncode({'status': 'success', 'synced_count': 0}),
        );
      }

      final conn = await DbConfig().connection;
      await conn.execute('START TRANSACTION');

      try {
        for (var logData in logs) {
          final userId = logData['user_id'];
          final dateStr = logData['date'];

          if (userId == null || dateStr == null) {
            throw StateError('Attendance log is missing user_id or date');
          }

          // Find employee_id from user_id or username (prioritize active profile)
          final empId = await _resolveEmployeeId(
            conn,
            logData['user_id'] ?? logData['username'],
          );
          if (empId == null) {
            throw StateError(
              'Employee mapping not found for user_id=${logData['user_id']}',
            );
          }

          // Check if we already have an attendance record for this day
          final existResult = await conn.execute(
            'SELECT * FROM attendance_log WHERE employee_id = :empId AND DATE(date) = :date LIMIT 1',
            {'empId': empId, 'date': dateStr},
          );

          if (existResult.rows.isEmpty) {
            // INSERT
            await conn.execute(
              '''
                INSERT INTO attendance_log 
                (employee_id, date, clock_in, clock_out, temp_out, back_to_work, method, status, latitude, longitude, note, created_at)
                VALUES 
                (:empId, :date, :clockIn, :clockOut, :tempOut, :backToWork, :method, :status, :lat, :lng, :note, NOW())
                ''',
              {
                'empId': empId,
                'date': dateStr,
                'clockIn': logData['check_in_time'],
                'clockOut': logData['check_out_time'],
                'tempOut': logData['temp_out_time'],
                'backToWork': logData['back_to_work_time'],
                'method': logData['status'] == 'PRESENT_OVERRIDE'
                    ? 'HR_OVERRIDE'
                    : 'MOBILE_GPS',
                'status': logData['status'] ?? 'PRESENT',
                'lat': logData['check_in_lat'],
                'lng': logData['check_in_lng'],
                'note': logData['note'],
              },
            );
          } else {
            // UPDATE
            // We only update fields if they are provided, or we can just blindly update if the mobile app sends the full state.
            // S-Link Isar will have the complete state for that day.
            final row = existResult.rows.first;

            // The backend logic for temp_out/back_to_work rounds:
            // To simplify, we will update the latest active round.
            // Since S-Link only supports 1 active temp leave, we will map it to temp_out/back_to_work or find the open one.

            // For safety, we use the same logic as syncAttendance in AttendanceRepository.
            // But it's easier to just call the same repository logic if we had access to it,
            // however, in backend, we deal with direct MySQL calls.

            // Let's implement a smart update based on what's provided from mobile.

            final clockIn = logData['check_in_time'];
            final clockOut = logData['check_out_time'];
            final tempOut = logData['temp_out_time'];
            final backToWork = logData['back_to_work_time'];
            final note = logData['note'];
            final status = logData['status'];
            final lat = logData['check_in_lat'];
            final lng = logData['check_in_lng'];

            // Check which temp leave round is currently open or if we need to start a new one.
            // This is a simplified version.

            String updateSql = 'UPDATE attendance_log SET ';
            Map<String, dynamic> updateParams = {
              'empId': empId,
              'date': dateStr,
            };
            List<String> setClauses = [];

            if (clockIn != null) {
              // Clock-in is monotonic: an old/offline client may contribute an
              // earlier real scan, but must never erase a later event.
              setClauses.add(
                'clock_in = CASE WHEN clock_in IS NULL OR clock_in > :clockIn '
                'THEN :clockIn ELSE clock_in END',
              );
              updateParams['clockIn'] = clockIn;
            }
            if (clockOut != null) {
              // Never turn a completed day back into an active day. Keep the
              // latest checkout when POS and mobile arrive out of order.
              setClauses.add(
                'clock_out = CASE WHEN clock_out IS NULL OR clock_out < :clockOut '
                'THEN :clockOut ELSE clock_out END',
              );
              updateParams['clockOut'] = clockOut;
            }

            // Idempotent temp-out merge. A full-state retry from S-Link must
            // update its original round, not create round 2/3 repeatedly.
            if (tempOut != null) {
              const rounds = [
                ('temp_out', 'back_to_work'),
                ('temp_out_2', 'back_to_work_2'),
                ('temp_out_3', 'back_to_work_3'),
              ];
              var roundIndex = rounds.indexWhere(
                (round) => _sameTimestamp(row.colByName(round.$1), tempOut),
              );
              roundIndex = roundIndex >= 0
                  ? roundIndex
                  : rounds.indexWhere(
                      (round) => row.colByName(round.$1) == null,
                    );

              if (roundIndex < 0) {
                throw StateError(
                  'All temporary-leave rounds are already occupied for employee_id=$empId',
                );
              }

              final tempColumn = rounds[roundIndex].$1;
              final backColumn = rounds[roundIndex].$2;
              if (row.colByName(tempColumn) == null) {
                setClauses.add('$tempColumn = :tempOut');
                updateParams['tempOut'] = tempOut;
              }
              if (backToWork != null) {
                setClauses.add(
                  '$backColumn = CASE WHEN $backColumn IS NULL OR '
                  '$backColumn < :backToWork THEN :backToWork '
                  'ELSE $backColumn END',
                );
                updateParams['backToWork'] = backToWork;
              }
            }

            if (note != null) {
              setClauses.add('note = :note');
              updateParams['note'] = note;
            }

            // Normal mobile PRESENT must not overwrite POS-calculated states
            // such as LATE. Only an explicit HR override owns the status.
            if (status == 'PRESENT_OVERRIDE') {
              setClauses.add('status = :status');
              updateParams['status'] = status;
              setClauses.add("method = 'HR_OVERRIDE'");
            }

            if (lat != null && row.colByName('latitude') == null) {
              setClauses.add('latitude = :lat');
              updateParams['lat'] = lat;
            }
            if (lng != null && row.colByName('longitude') == null) {
              setClauses.add('longitude = :lng');
              updateParams['lng'] = lng;
            }

            if (setClauses.isNotEmpty) {
              updateSql +=
                  '${setClauses.join(', ')} WHERE employee_id = :empId AND DATE(date) = :date';
              await conn.execute(updateSql, updateParams);
            }
          }
        }
        await conn.execute('COMMIT');
        return Response.ok(
          jsonEncode({'status': 'success', 'synced_count': logs.length}),
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

  // POST /attendance/cleanup
  // Called periodically to cleanup old logs (if needed)
  Future<Response> _cleanupOldAttendance(Request request) async {
    // MySQL handles long-term storage, we probably don't need to delete anything here.
    // The "self-cleanup" is for Mobile Isar DB.
    return Response.ok(
      jsonEncode({
        'status': 'success',
        'message': 'Cleanup handled locally on mobile.',
      }),
    );
  }

  Future<int?> _resolveEmployeeId(dynamic conn, dynamic userIdInput) async {
    if (userIdInput == null) return null;
    final inputStr = userIdInput.toString().trim();
    if (inputStr.isEmpty) return null;

    // S-Link sends its authenticated account ID (or username), not a POS
    // employee-profile primary key. Resolve those identities first so a
    // numeric account ID cannot be mistaken for an unrelated employee ID.
    final accountResult = await conn.execute(
      '''
      SELECT e.id
      FROM employee_profile e
      LEFT JOIN user u ON e.user_id = u.id
      WHERE (u.username = :val
        OR CAST(u.id AS CHAR) = :val
        OR CAST(e.user_id AS CHAR) = :val
        OR e.firebase_uid = :val)
      ORDER BY e.is_active DESC, e.id DESC
      LIMIT 1
      ''',
      {'val': inputStr},
    );

    if (accountResult.rows.isNotEmpty) {
      return int.tryParse(
        accountResult.rows.first.colByName('id')?.toString() ?? '',
      );
    }

    // Keep direct POS employee-ID lookup only as a legacy fallback for
    // trusted callers that explicitly supply an employee-profile ID.
    final employeeResult = await conn.execute(
      '''
      SELECT e.id
      FROM employee_profile e
      WHERE CAST(e.id AS CHAR) = :val
      ORDER BY e.is_active DESC, e.id DESC
      LIMIT 1
      ''',
      {'val': inputStr},
    );

    if (employeeResult.rows.isNotEmpty) {
      return int.tryParse(
        employeeResult.rows.first.colByName('id')?.toString() ?? '',
      );
    }

    return null;
  }

  bool _sameTimestamp(dynamic databaseValue, dynamic incomingValue) {
    if (databaseValue == null || incomingValue == null) return false;
    final databaseTime = DateTime.tryParse(databaseValue.toString());
    final incomingTime = DateTime.tryParse(incomingValue.toString());
    if (databaseTime == null || incomingTime == null) return false;
    return databaseTime.difference(incomingTime).inSeconds.abs() <= 1;
  }
}
