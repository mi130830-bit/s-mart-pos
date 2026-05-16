import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AIOfficeService {
  // ใส่ Port ที่ Star-Office-UI ของคุณรันอยู่ (ตอนนี้น่าจะรันที่ 19000 ตามรูป)
  static const String _baseUrl = 'http://127.0.0.1:19000/api/update';
  static bool _enabled = true; // เปิด/ปิดใช้งานระบบ AI Dashboard

  static void setEnabled(bool isEnabled) {
    _enabled = isEnabled;
  }

  /// เปลี่ยนสถานะตัวละครใน AI Dashboard
  ///
  /// [agentId]: ชื่อตัวละคร (เช่น 'Dev_Agent', 'Cashier_Bot', 'Stock_Manager')
  /// [action]: ท่าทางที่ต้องการ (ต้องตรงกับที่ Star-Office-UI รองรับ เช่น 'thinking', 'coding', 'resting', 'error')
  static Future<void> updateAgentStatus(String agentId, String action) async {
    if (!_enabled) return;

    try {
      final url = Uri.parse(_baseUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': agentId,
          'action': action,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ AI Office: [$agentId] is now [$action]');
      } else {
        debugPrint(
            '⚠️ AI Office Warning: Server responded with ${response.statusCode}');
      }
    } catch (e) {
      debugPrint(
          '❌ AI Office Error: Cannot connect to $_baseUrl. Is the server running? ($e)');
      // You might want to auto-disable if it fails consistently
      // _enabled = false;
    }
  }

  // --- Helper Methods สำหรับใช้งานง่ายๆ ---

  /// ให้ AI ทำท่าคิดวิเคราะห์/ค้นข้อมูล
  static Future<void> startThinking({String agentId = 'System'}) {
    return updateAgentStatus(agentId, 'thinking');
  }

  /// ให้ AI ทำท่าเขียนโค้ด/บันทึกข้อมล
  static Future<void> startWorking({String agentId = 'System'}) {
    return updateAgentStatus(agentId, 'coding');
  }

  /// ให้ AI กลับไปพักผ่อน/รองานต่อไป
  static Future<void> backToRest({String agentId = 'System'}) {
    return updateAgentStatus(agentId, 'resting');
  }

  /// ให้ AI ทำท่าพัง/เกิดเออเร่อ
  static Future<void> reportError({String agentId = 'System'}) {
    // ลองใช้ action ที่ตัวละครอาจจะตกใจ หรือใช้ action error ถ้ามี
    return updateAgentStatus(
        agentId, 'listening'); // บางธีมอาจจะใช้ sleeping/listening
  }
}
