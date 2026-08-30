import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;
import '../env_config.dart';

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

  /// Returns only the latest point for one canonical vehicle key. Customer
  /// tracking uses this narrow accessor instead of the all-vehicles endpoint.
  static Map<String, dynamic>? latestVehicle(String vehicleKey) {
    final location = _vehicles[vehicleKey];
    return location == null ? null : Map<String, dynamic>.from(location);
  }

  // สถานะงานรถแต่ละคัน
  static final Map<String, String> _vehicleJobs = {};

  // Purge Timer (ลบรถที่ offline เกิน 5 นาที ออกจาก Memory)
  // ignore: unused_field
  static Timer? _purgeTimer;

  static const String telegramToken =
      '8410912861:AAF70xuj0NglZcXo55E3tuLIJBRSdj0Uu-8';
  static const String telegramChatId = '-5507041706';

  GpsController() {
    _startPurgeTimer();
  }

  /// ตรวจสอบรถแต่ละคันทุก 10 วินาที:
  /// - ถ้าขาดสัญญาณเกิน 120 วินาที (2 นาที) → เปลี่ยนเป็น OFFLINE + แจ้ง Telegram
  /// - ถ้า offline เกิน 600 วินาที (10 นาที) → ลบออกจาก Memory (Purge)
  ///   (เพิ่มเป็น 10 นาทีเพื่อให้รถยังแสดงบนแผนที่ระหว่างขับกลับร้านได้)
  void _startPurgeTimer() {
    if (_purgeTimer != null) return;
    _purgeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final toRemove = <String>[];

      _vehicles.forEach((vehicleName, loc) {
        final lastPing = _lastPingTimes[vehicleName] ?? 0;
        final secondsAgo = (now - lastPing) / 1000;

        // ขาดสัญญาณเกิน 120 วินาที (2 นาที) → แจ้งเตือน OFFLINE ดับเครื่อง
        if (secondsAgo > 120 && loc['status'] == 'ONLINE') {
          loc['status'] = 'OFFLINE';
          _sendTelegramAlert('🛑 $vehicleName ดับเครื่อง! สัญญาณ GPS ขาดหาย');
          _sseController.add(jsonEncode(loc));
          developer.log(
            '[GPS] $vehicleName → OFFLINE (no ping for ${secondsAgo.toStringAsFixed(0)}s)',
          );
        }

        // ขาดสัญญาณเกิน 10 นาที (600 วินาที) → Purge ออกจาก Memory
        if (secondsAgo > 600) {
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
    final url = Uri.parse(
      'https://api.telegram.org/bot$telegramToken/sendMessage',
    );
    try {
      await http.post(url, body: {'chat_id': telegramChatId, 'text': message});
      developer.log('[Telegram] Sent: $message');
    } catch (e) {
      developer.log('[Telegram] Error: $e');
    }
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371.0;
    final double dLat = (lat2 - lat1) * (3.1415926535897932 / 180.0);
    final double dLon = (lon2 - lon1) * (3.1415926535897932 / 180.0);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (3.1415926535897932 / 180.0)) *
            cos(lat2 * (3.1415926535897932 / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  bool _hasValidDeviceKey(Request req) {
    final configuredKey = EnvConfig()['GPS_DEVICE_KEY']?.trim() ?? '';
    final suppliedKey = req.headers['x-gps-device-key']?.trim() ?? '';
    return configuredKey.isNotEmpty && suppliedKey == configuredKey;
  }

  static String normalizeVehicleKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.contains('เครน') || trimmed.contains('82-0686')) return 'รถเครน';
    if (trimmed.contains('ดั้มเล็ก') || trimmed.contains('81-2812')) return 'ดั้มเล็ก';
    if (trimmed.contains('ดั้มใหญ่') || trimmed.contains('81-3250')) return 'ดั้มใหญ่';
    return trimmed;
  }

  Router get publicRouter {
    final router = Router();

    // 1. รับข้อมูลจาก ESP32 (POST /api/v1/gps)
    router.post('/', (Request req) async {
      if (!_hasValidDeviceKey(req)) {
        return Response.unauthorized(
          jsonEncode({'error': 'Invalid GPS device key'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      try {
        final payload = await req.readAsString();
        final data = jsonDecode(payload) as Map<String, dynamic>;

        // ── Validate ──
        final String rawVehicleName = (data['vehicle']?.toString() ?? '').trim();
        if (rawVehicleName.isEmpty) {
          return Response.badRequest(body: 'Missing vehicle name');
        }
        final String vehicleName = normalizeVehicleKey(rawVehicleName);
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
        String currentJob = _vehicleJobs[vehicleName] ??
            _vehicleJobs[rawVehicleName] ??
            'กำลังเตรียมของ';
        if (currentJob == 'กำลังกลับร้าน') {
          final distKm = _haversineDistance(lat, lng, 16.160136, 100.802407);
          if (distKm <= 0.100) {
            _vehicleJobs.remove(vehicleName);
            _vehicleJobs.remove(rawVehicleName);
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
        developer.log(
          '[GPS] $vehicleName → lat:$lat lng:$lng speed:${locationData['speed']}',
        );

        // ส่ง delta event เฉพาะรถคันที่อัปเดต (ไม่ส่ง array ทั้งหมด)
        _sseController.add(jsonEncode(locationData));

        return Response.ok(
          '{"status":"success"}',
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        developer.log('[GPS] POST error: $e');
        return Response.badRequest(body: 'Invalid JSON');
      }
    });

    // 2. ดึงข้อมูลรถทุกคัน (GET /api/v1/gps)
    router.get('/', (Request req) {
      if (_vehicles.isEmpty) return Response(204);
      return Response.ok(
        jsonEncode(_vehicles.values.toList()),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 3. ดึงข้อมูลรถคันเดียว (GET /api/v1/gps/vehicle/:name)
    router.get('/vehicle/<name>', (Request req, String name) {
      final v = _vehicles[Uri.decodeComponent(name)];
      if (v == null) return Response(204);
      return Response.ok(
        jsonEncode(v),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 4. SSE Stream สำหรับหน้าเว็บ (GET /api/v1/gps/stream)
    router.get('/stream', (Request req) async {
      req.hijack((streamChannel) {
        final sink = streamChannel.sink;
        sink.add(
          utf8.encode(
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: text/event-stream\r\n"
            "Cache-Control: no-cache\r\n"
            "Connection: keep-alive\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "X-Accel-Buffering: no\r\n\r\n",
          ),
        );
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
        streamChannel.stream.listen(
          (_) {},
          onDone: () {
            pingTimer.cancel();
            subscription.cancel();
            sink.close();
          },
        );
      });
    });

    return router;
  }

  Router get jobRouter {
    final router = Router();
    router.post('/', (Request req) async {
      try {
        final payload = await req.readAsString();
        final data = jsonDecode(payload) as Map<String, dynamic>;

        final String rawVehicle = (data['vehicle']?.toString() ?? '').trim();
        final String vehicle = normalizeVehicleKey(rawVehicle);
        final String jobStatus = (data['jobStatus']?.toString() ?? '').trim();

        if (vehicle.isEmpty) {
          return Response.badRequest(body: 'Missing vehicle name');
        }

        if (jobStatus.isEmpty || jobStatus == 'ไม่มีงาน') {
          _vehicleJobs.remove(vehicle);
          _vehicleJobs.remove(rawVehicle);
        } else {
          _vehicleJobs[vehicle] = jobStatus;
          if (rawVehicle != vehicle) _vehicleJobs[rawVehicle] = jobStatus;
        }

        // อัปเดต SSE ให้หน้าเว็บเห็นสถานะงานใหม่ทันที
        final targetKey = _vehicles.containsKey(vehicle)
            ? vehicle
            : (_vehicles.containsKey(rawVehicle) ? rawVehicle : null);
        if (targetKey != null) {
          _vehicles[targetKey]!['job'] =
              jobStatus.isEmpty ? 'ไม่มีงาน' : jobStatus;
          _sseController.add(jsonEncode(_vehicles[targetKey]));
        }

        return Response.ok(
          jsonEncode({'success': true}),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.badRequest(body: 'Invalid JSON');
      }
    });

    return router;
  }
}
