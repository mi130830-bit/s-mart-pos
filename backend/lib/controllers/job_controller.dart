import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import 'dart:io';

/// POST /jobs/complete — เรียกจาก S-Link เมื่อพนักงานส่งของเสร็จ
/// POST /jobs/list     — ดูประวัติจาก MySQL (สำหรับตรวจสอบ)
class JobController {
  Router get router {
    final router = Router();
    router.post('/complete', _completeJob);
    router.get('/list', _listJobs);
    router.get('/stats', _getStats);
    return router;
  }

  /// POST /jobs/complete
  /// Body: {
  ///   "orderId": 123,
  ///   "firebaseJobId": "abc123",
  ///   "driverName": "สมชาย",
  ///   "vehiclePlate": "กก 1234",
  ///   "customerName": "ลูกค้า",
  ///   "customerPhone": "0812345678",
  ///   "customerAddress": "123 ถ.ท่าข้าม",
  ///   "totalAmount": 500.0,
  ///   "jobType": "delivery",
  ///   "note": "",
  ///   "latitude": 13.736717,
  ///   "longitude": 100.523186
  /// }
  Future<Response> _completeJob(Request request) async {
    try {
      final body = await request.readAsString();
      stdout.writeln('📦 [JobController] complete request: $body');

      final Map<String, dynamic> payload = jsonDecode(body);

      final int orderId =
          int.tryParse(payload['orderId']?.toString() ?? '0') ?? 0;
      final String firebaseJobId = payload['firebaseJobId']?.toString() ?? '';
      final String driverName = payload['driverName']?.toString() ?? '';
      final String vehiclePlate = payload['vehiclePlate']?.toString() ?? '';
      final String customerName = payload['customerName']?.toString() ?? '';
      final String customerPhone = payload['customerPhone']?.toString() ?? '';
      final String customerAddress =
          payload['customerAddress']?.toString() ?? '';
      final double totalAmount =
          double.tryParse(payload['totalAmount']?.toString() ?? '0') ?? 0.0;
      final String jobType = payload['jobType']?.toString() ?? 'delivery';
      final String note = payload['note']?.toString() ?? '';

      // Build GPS URL if coordinates given
      String locationUrl = '';
      final lat = payload['latitude'];
      final lng = payload['longitude'];
      if (lat != null && lng != null) {
        locationUrl =
            'https://maps.google.com/?q=${lat.toString()},${lng.toString()}';
      }

      final conn = await DbConfig().connection;

      // ── ป้องกัน duplicate (กรณี S-Link ส่งซ้ำ) ──────────────
      if (firebaseJobId.isNotEmpty) {
        final dupCheck = await conn.execute(
          'SELECT id FROM delivery_history WHERE firebaseJobId = :fid LIMIT 1',
          {'fid': firebaseJobId},
        );
        if (dupCheck.numOfRows > 0) {
          stdout.writeln(
              '⏭️ [JobController] Duplicate skip: $firebaseJobId');
          return Response.ok(
            jsonEncode({
              'success': true,
              'message': 'Already recorded',
              'id': dupCheck.rows.first.colAt(0)
            }),
            headers: {'content-type': 'application/json'},
          );
        }
      }

      // ── Insert delivery_history ───────────────────────────────
      final result = await conn.execute('''
        INSERT INTO delivery_history (
          orderId, firebaseJobId, driverName, vehiclePlate,
          customerName, customerPhone, customerAddress,
          totalAmount, status, jobType, note, locationUrl,
          completedAt
        ) VALUES (
          :oid, :fid, :driver, :vehicle,
          :cname, :cphone, :caddr,
          :total, 'completed', :jtype, :note, :locUrl,
          NOW()
        )
      ''', {
        'oid': orderId,
        'fid': firebaseJobId.isEmpty ? null : firebaseJobId,
        'driver': driverName,
        'vehicle': vehiclePlate,
        'cname': customerName,
        'cphone': customerPhone,
        'caddr': customerAddress,
        'total': totalAmount,
        'jtype': jobType,
        'note': note,
        'locUrl': locationUrl.isEmpty ? null : locationUrl,
      });

      final insertId = result.lastInsertID.toInt();

      // ── Update delivery_jobs status ───────────────────────────
      if (orderId > 0) {
        try {
          await conn.execute(
            "UPDATE delivery_jobs SET status = 'COMPLETED' WHERE orderId = :oid",
            {'oid': orderId},
          );
        } catch (e) {
          stderr.writeln('⚠️ [JobController] delivery_jobs update error: $e');
        }
      }

      stdout.writeln(
          '✅ [JobController] Archived delivery job #$orderId → delivery_history id=$insertId');

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Delivery job recorded',
          'id': insertId,
          'orderId': orderId,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('❌ [JobController] completeJob error: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to record job: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// GET /jobs/list?start=2026-03-01&end=2026-03-31&vehicle=กก1234
  Future<Response> _listJobs(Request request) async {
    try {
      final params = request.url.queryParameters;
      final String start = params['start'] ?? '';
      final String end = params['end'] ?? '';
      final String? vehicle = params['vehicle'];

      final conn = await DbConfig().connection;

      String sql;
      Map<String, dynamic> sqlParams = {};

      if (start.isNotEmpty && end.isNotEmpty) {
        if (vehicle != null && vehicle.isNotEmpty) {
          sql = '''
            SELECT * FROM delivery_history
            WHERE DATE(completedAt) >= :start AND DATE(completedAt) <= :end
              AND vehiclePlate = :vehicle
            ORDER BY completedAt DESC
            LIMIT 500
          ''';
          sqlParams = {'start': start, 'end': end, 'vehicle': vehicle};
        } else {
          sql = '''
            SELECT * FROM delivery_history
            WHERE DATE(completedAt) >= :start AND DATE(completedAt) <= :end
            ORDER BY completedAt DESC
            LIMIT 500
          ''';
          sqlParams = {'start': start, 'end': end};
        }
      } else {
        sql = '''
          SELECT * FROM delivery_history
          ORDER BY completedAt DESC
          LIMIT 100
        ''';
      }

      final result = await conn.execute(sql, sqlParams);
      final rows = result.rows.map((r) => r.assoc()).toList();

      return Response.ok(
        jsonEncode({'success': true, 'data': rows, 'count': rows.length}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('❌ [JobController] listJobs error: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to list jobs: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// GET /jobs/stats
  Future<Response> _getStats(Request request) async {
    try {
      final conn = await DbConfig().connection;

      // 1. Total Jobs
      final totalRes = await conn.execute(
          "SELECT COUNT(*) as total FROM delivery_history WHERE status = 'completed'");
      final int totalCount =
          int.tryParse(totalRes.rows.first.colAt(0) ?? '0') ?? 0;

      // 2. Stats by Driver
      final driverRes = await conn.execute('''
        SELECT driverName as name, COUNT(*) as count 
        FROM delivery_history 
        WHERE status = 'completed' AND driverName IS NOT NULL AND driverName != ''
        GROUP BY driverName
        ORDER BY count DESC
      ''');
      final driverStats = driverRes.rows.map((r) {
        final count = int.tryParse(r.colAt(1) ?? '0') ?? 0;
        return {
          'name': r.colAt(0),
          'count': count,
          'percentage': totalCount > 0 ? (count / totalCount * 100) : 0
        };
      }).toList();

      // 3. Stats by Vehicle
      final vehicleRes = await conn.execute('''
        SELECT vehiclePlate as name, COUNT(*) as count 
        FROM delivery_history 
        WHERE status = 'completed' AND vehiclePlate IS NOT NULL AND vehiclePlate != ''
        GROUP BY vehiclePlate
        ORDER BY count DESC
      ''');
      final vehicleStats = vehicleRes.rows.map((r) {
        final count = int.tryParse(r.colAt(1) ?? '0') ?? 0;
        return {
          'name': r.colAt(0),
          'count': count,
          'percentage': totalCount > 0 ? (count / totalCount * 100) : 0
        };
      }).toList();

      return Response.ok(
        jsonEncode({
          'success': true,
          'totalJobs': totalCount,
          'drivers': driverStats,
          'vehicles': vehicleStats,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('❌ [JobController] getStats error: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to get stats: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
