import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

class GpsController {
  // ── SSE Broadcast ──────────────────────────────────────────────────
  static final StreamController<String> _sseController =
      StreamController<String>.broadcast();

  // ── Multi-Vehicle State ────────────────────────────────────────────
  // Key = ชื่อรถ (vehicle name จาก ESP32 payload)
  // Value = ข้อมูลล่าสุดของรถคันนั้น
  static final Map<String, Map<String, dynamic>> _vehicles = {};

  // เวลาที่ ping ล่าสุดแยกตามรถ (เพื่อตรวจจับ offline รายคัน)
  static final Map<String, int> _lastPingTimes = {};

  // สถานะงานรถแต่ละคัน
  static final Map<String, String> _vehicleJobs = {};

  // Purge Timer (ลบรถที่ offline เกิน 5 นาที ออกจาก Memory)
  // ignore: unused_field
  static Timer? _purgeTimer;

  static const String telegramToken = '7839145001:AAGYNOWwm1qCZBGpVxXpGza_RhF6pvBtdy8';
  static const String telegramChatId = '5637538985';

  GpsController() {
    _startPurgeTimer();
  }

  /// ตรวจสอบรถแต่ละคันทุก 30 วินาที:
  /// - ถ้าขาดสัญญาณเกิน 2 นาที → เปลี่ยนเป็น OFFLINE + แจ้ง Telegram
  /// - ถ้า offline เกิน 5 นาที → ลบออกจาก Memory (Purge)
  void _startPurgeTimer() {
    _purgeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final toRemove = <String>[];

      _vehicles.forEach((vehicleName, loc) {
        final lastPing = _lastPingTimes[vehicleName] ?? 0;
        final secondsAgo = (now - lastPing) / 1000;

        // เกิน 2 นาที → OFFLINE
        if (secondsAgo > 120 && loc['status'] == 'ONLINE') {
          loc['status'] = 'OFFLINE';
          _sendTelegramAlert('🛑 $vehicleName ดับเครื่อง! สัญญาณ GPS ขาดหาย');
          _sseController.add(jsonEncode(loc));
          developer.log('[GPS] $vehicleName → OFFLINE (no ping for ${secondsAgo.toStringAsFixed(0)}s)');
        }

        // เกิน 5 นาที → Purge ออกจาก Memory
        if (secondsAgo > 300) {
          toRemove.add(vehicleName);
        }
      });

      for (final name in toRemove) {
        _vehicles.remove(name);
        _lastPingTimes.remove(name);
        _vehicleJobs.remove(name);
        developer.log('[GPS] Purged offline vehicle: $name');
      }
    });
  }

  Future<void> _sendTelegramAlert(String message) async {
    final url = Uri.parse('https://api.telegram.org/bot$telegramToken/sendMessage');
    try {
      await http.post(url, body: {
        'chat_id': telegramChatId,
        'text': message,
      });
      developer.log('[Telegram] Sent: $message');
    } catch (e) {
      developer.log('[Telegram] Error: $e');
    }
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0;
    final double dLat = (lat2 - lat1) * (3.1415926535897932 / 180.0);
    final double dLon = (lon2 - lon1) * (3.1415926535897932 / 180.0);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (3.1415926535897932 / 180.0)) * cos(lat2 * (3.1415926535897932 / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Router get router {
    final router = Router();

    // 1. รับข้อมูลจาก ESP32 (POST /api/v1/gps)
    router.post('/', (Request req) async {
      try {
        final payload = await req.readAsString();
        final data = jsonDecode(payload) as Map<String, dynamic>;

        // ── Validate ──
        final String vehicleName = (data['vehicle']?.toString() ?? '').trim();
        if (vehicleName.isEmpty) {
          return Response.badRequest(body: 'Missing vehicle name');
        }
        final double lat = (data['lat'] ?? 0).toDouble();
        final double lng = (data['lng'] ?? 0).toDouble();
        if (lat == 0 && lng == 0) {
          return Response.badRequest(body: 'Invalid coordinates');
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final bool wasOffline = _vehicles[vehicleName]?['status'] != 'ONLINE';

        // แจ้ง Telegram เฉพาะเมื่อรถเพิ่งออนไลน์
        if (wasOffline) {
          _sendTelegramAlert('🟢 $vehicleName สตาร์ทรถแล้ว! ระบบ GPS ออนไลน์');
        }

        _lastPingTimes[vehicleName] = now;

        // ── จัดการสถานะงาน ──
        String currentJob = _vehicleJobs[vehicleName] ?? 'กำลังเตรียมของ';
        if (currentJob == 'กำลังกลับร้าน') {
          final distKm = _haversineDistance(lat, lng, 16.160136, 100.802407);
          if (distKm <= 0.200) {
            _vehicleJobs.remove(vehicleName);
            currentJob = 'กำลังเตรียมของ';
          }
        }

        // ── บันทึกและ Broadcast (Delta Event) ──
        final locationData = {
          'lat': lat,
          'lng': lng,
          'speed': (data['speed'] ?? 0).toDouble(),
          'time': DateTime.now().toIso8601String(),
          'status': 'ONLINE',
          'vehicle': vehicleName,
          'job': currentJob,
        };

        _vehicles[vehicleName] = locationData;
        developer.log('[GPS] $vehicleName → lat:$lat lng:$lng speed:${locationData['speed']}');

        // ส่ง delta event เฉพาะรถคันที่อัปเดต (ไม่ส่ง array ทั้งหมด)
        _sseController.add(jsonEncode(locationData));

        return Response.ok('{"status":"success"}',
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        developer.log('[GPS] POST error: $e');
        return Response.badRequest(body: 'Invalid JSON');
      }
    });

    // 2. รับสถานะงานจาก S-Link (POST /api/v1/gps/update_job)
    router.post('/update_job', (Request req) async {
      try {
        final payload = await req.readAsString();
        final data = jsonDecode(payload) as Map<String, dynamic>;

        final String vehicle = (data['vehicle']?.toString() ?? '').trim();
        final String jobStatus = (data['jobStatus']?.toString() ?? '').trim();

        if (vehicle.isEmpty) {
          return Response.badRequest(body: 'Missing vehicle name');
        }

        if (jobStatus.isEmpty || jobStatus == 'ไม่มีงาน') {
          _vehicleJobs.remove(vehicle);
        } else {
          _vehicleJobs[vehicle] = jobStatus;
        }

        // อัปเดต SSE ให้หน้าเว็บเห็นสถานะงานใหม่ทันที
        if (_vehicles.containsKey(vehicle)) {
          _vehicles[vehicle]!['job'] = jobStatus.isEmpty ? 'ไม่มีงาน' : jobStatus;
          _sseController.add(jsonEncode(_vehicles[vehicle]));
        }

        return Response.ok(jsonEncode({'success': true}),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response.badRequest(body: 'Invalid JSON');
      }
    });

    // 3. ดึงข้อมูลรถทุกคัน (GET /api/v1/gps)
    router.get('/', (Request req) {
      if (_vehicles.isEmpty) return Response(204);
      // ส่งคืน Array ของรถทุกคัน
      return Response.ok(
        jsonEncode(_vehicles.values.toList()),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 3b. ดึงข้อมูลรถคันเดียว (GET /api/v1/gps/vehicle/:name)
    router.get('/vehicle/<name>', (Request req, String name) {
      final v = _vehicles[Uri.decodeComponent(name)];
      if (v == null) return Response(204);
      return Response.ok(jsonEncode(v), headers: {'Content-Type': 'application/json'});
    });

    // 4. SSE Stream สำหรับหน้าเว็บ (GET /api/v1/gps/stream)
    router.get('/stream', (Request req) async {
      req.hijack((streamChannel) {
        final sink = streamChannel.sink;
        sink.add(utf8.encode(
          "HTTP/1.1 200 OK\r\n"
          "Content-Type: text/event-stream\r\n"
          "Cache-Control: no-cache\r\n"
          "Connection: keep-alive\r\n"
          "Access-Control-Allow-Origin: *\r\n"
          "X-Accel-Buffering: no\r\n\r\n"
        ));
        void sendEvent(String data) => sink.add(utf8.encode('data: $data\n\n'));
        if (_vehicles.isNotEmpty) {
          for (final loc in _vehicles.values) {
            sendEvent(jsonEncode(loc));
          }
        } else {
          sendEvent(jsonEncode({'status': 'OFFLINE'}));
        }
        final pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          sink.add(utf8.encode(': ping\n\n'));
        });
        final subscription = _sseController.stream.listen(sendEvent);
        streamChannel.stream.listen((_) {}, onDone: () {
          pingTimer.cancel();
          subscription.cancel();
          sink.close();
        });
      });
    });

    return router;
  }
}
