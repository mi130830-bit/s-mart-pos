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

    return router;
  }

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
