import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';

/// ConfigController — ดึง Config จาก MySQL (system_settings) ของ POS Desktop
/// S-Link เรียกใช้เพื่อให้ QR / Payment settings เป็น Single Source of Truth
/// เดียวกับที่ Admin ตั้งไว้ใน POS Desktop ไม่ต้องตั้งซ้ำในมือถือ
class ConfigController {
  Router get router {
    final router = Router();

    // GET /api/v1/config/promptpay
    // ดึง PromptPay ID + QR Mode + Static QR Image (base64) จาก MySQL
    router.get('/promptpay', _handleGetPromptPay);
    router.get('/stock-check-template', _getStockCheckTemplate);
    router.post('/stock-check-template', _saveStockCheckTemplate);

    return router;
  }

  static const _templateKey = 'stock_check_template_v1';
  static const _defaultTemplate = [
    {'id': 'pole-7m', 'name': 'เสาไฟฟ้า 7ม.', 'unit': 'หน่วย', 'enabled': true, 'order': 0},
    {'id': 'fence-post', 'name': 'เสารั้ว', 'unit': 'หน่วย', 'enabled': true, 'order': 1},
    {'id': 'fence-post-hole', 'name': 'เสารั้วมีรู', 'unit': 'หน่วย', 'enabled': true, 'order': 2},
    {'id': 'support-pole', 'name': 'เสาค้ำ', 'unit': 'หน่วย', 'enabled': true, 'order': 3},
    {'id': 'boundary-pole', 'name': 'เสาหลักแดน', 'unit': 'หน่วย', 'enabled': true, 'order': 4},
    {'id': 'well-cover-60-solid', 'name': 'ฝาวงบ่อ60ซม. ตัน', 'unit': 'หน่วย', 'enabled': true, 'order': 5},
    {'id': 'well-cover-60-small-hole', 'name': 'ฝาวงบ่อ60ซม.รูเล็ก', 'unit': 'หน่วย', 'enabled': true, 'order': 6},
    {'id': 'well-cover-80-solid', 'name': 'ฝาวงบ่อ80ซม. ตัน', 'unit': 'หน่วย', 'enabled': true, 'order': 7},
    {'id': 'well-cover-80-small-hole', 'name': 'ฝาวงบ่อ80ซม. รูเล็ก', 'unit': 'หน่วย', 'enabled': true, 'order': 8},
    {'id': 'well-cover-100-solid', 'name': 'ฝาวงบ่อ100ซม. ตัน', 'unit': 'หน่วย', 'enabled': true, 'order': 9},
    {'id': 'well-cover-100-small-hole', 'name': 'ฝาวงบ่อ100ซม.รูเล็ก', 'unit': 'หน่วย', 'enabled': true, 'order': 10},
    {'id': 'well-cover-120-solid', 'name': 'ฝาวงบ่อ120ซม. ตัน', 'unit': 'หน่วย', 'enabled': true, 'order': 11},
    {'id': 'well-cover-120-small-hole', 'name': 'ฝาวงบ่อ120ซม. รูเล็ก', 'unit': 'หน่วย', 'enabled': true, 'order': 12},
  ];

  Future<Response> _getStockCheckTemplate(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final result = await conn.execute(
        'SELECT setting_value FROM system_settings WHERE setting_key = :key LIMIT 1',
        {'key': _templateKey},
      );
      if (result.rows.isEmpty) return _templateResponse(0, _defaultTemplate);
      final value = result.rows.first.colAt(0) ?? '';
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return _templateResponse(
        (decoded['revision'] as num?)?.toInt() ?? 0,
        List<Map<String, dynamic>>.from(decoded['items'] as List? ?? const []),
      );
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _saveStockCheckTemplate(Request request) async {
    final contextUser = request.context['user'];
    final role = contextUser is Map ? contextUser['role']?.toString().toUpperCase() : '';
    if (role != 'ADMIN' && role != 'HR') return Response.forbidden(jsonEncode({'error': 'ADMIN or HR role required'}));
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final expected = body['expected_revision'];
      if (expected is! num) return Response.badRequest(body: jsonEncode({'error': 'expected_revision required'}));
      final items = _validateTemplate(body['items']);
      final conn = await DbConfig().connection;
      await conn.execute('START TRANSACTION');
      try {
        final current = await conn.execute(
          'SELECT setting_value FROM system_settings WHERE setting_key = :key FOR UPDATE',
          {'key': _templateKey},
        );
        final currentRevision = current.rows.isEmpty
            ? 0
            : ((jsonDecode(current.rows.first.colAt(0) ?? '{}') as Map)['revision'] as num?)?.toInt() ?? 0;
        if (currentRevision != expected.toInt()) {
          await conn.execute('ROLLBACK');
          return Response(409, body: jsonEncode({'error': 'stale_revision', 'revision': currentRevision}));
        }
        final nextRevision = currentRevision + 1;
        final value = jsonEncode({'revision': nextRevision, 'items': items});
        await conn.execute(
          'INSERT INTO system_settings (setting_key, setting_value) VALUES (:key, :value) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)',
          {'key': _templateKey, 'value': value},
        );
        await conn.execute('COMMIT');
        return _templateResponse(nextRevision, items);
      } catch (_) {
        await conn.execute('ROLLBACK');
        rethrow;
      }
    } on FormatException catch (e) {
      return Response.badRequest(body: jsonEncode({'error': e.message}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  List<Map<String, dynamic>> _validateTemplate(dynamic raw) {
    if (raw is! List) throw const FormatException('items must be a list');
    final labels = <String>{};
    final ids = <String>{};
    final items = <Map<String, dynamic>>[];
    for (var index = 0; index < raw.length; index++) {
      final item = raw[index];
      if (item is! Map) throw const FormatException('invalid item');
      final id = item['id']?.toString().trim() ?? '';
      final name = item['name']?.toString().trim() ?? '';
      final unit = item['unit']?.toString().trim() ?? '';
      final enabled = item['enabled'];
      final order = item['order'];
      final normalized = name.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      if (id.isEmpty || name.isEmpty || unit.isEmpty || id.length > 255 || name.length > 255 || unit.length > 255 || enabled is! bool || order is! num || !ids.add(id) || !labels.add(normalized)) {
        throw const FormatException('invalid, duplicate, or oversized template item');
      }
      items.add({'id': id, 'name': name, 'unit': unit, 'enabled': enabled, 'order': order.toInt()});
    }
    return items;
  }

  Response _templateResponse(int revision, List<Map<String, dynamic>> items) => Response.ok(
        jsonEncode({'revision': revision, 'items': items}),
        headers: {'content-type': 'application/json'},
      );

  Future<Response> _handleGetPromptPay(Request request) async {
    try {
      final conn = await DbConfig().connection;

      // ดึงทุก key ที่เกี่ยวกับ payment ในคราวเดียว
      final keys = [
        'promptpay_id',
        'payment_qr_mode',
        'payment_qr_image_base64',
      ];

      final placeholders = keys.map((k) => "'$k'").join(', ');
      final results = await conn.execute(
        'SELECT setting_key, setting_value FROM system_settings WHERE setting_key IN ($placeholders)',
      );

      // แปลงผลลัพธ์เป็น Map
      final Map<String, String> settings = {};
      for (final row in results.rows) {
        final key = row.colAt(0) ?? '';
        final value = row.colAt(1) ?? '';
        if (key.isNotEmpty) settings[key] = value;
      }

      final promptPayId = settings['promptpay_id'] ?? '';
      final qrMode = settings['payment_qr_mode'] ?? 'dynamic';
      final staticQrBase64 = settings['payment_qr_image_base64'];

      // ถ้าไม่มี PromptPay ID และไม่มีรูป Static QR → ยังไม่ได้ตั้งค่า
      if (promptPayId.isEmpty && (staticQrBase64 == null || staticQrBase64.isEmpty)) {
        return Response.notFound(
          jsonEncode({
            'success': false,
            'message': 'ยังไม่ได้ตั้งค่า PromptPay ในระบบ POS Desktop',
          }),
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'promptpay_id': promptPayId,
          'qr_mode': qrMode,             // 'dynamic' | 'static'
          // ส่ง static_qr_base64 เสมอ (ถ้ามี) เพื่อให้ S-Link ใช้เป็น Smart Fallback ได้
          if (staticQrBase64 != null && staticQrBase64.isNotEmpty)
            'static_qr_base64': staticQrBase64,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Server Error: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
