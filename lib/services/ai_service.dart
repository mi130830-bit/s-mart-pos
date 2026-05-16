import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  static const String keyApiKey = 'gemini_api_key';

  Future<String> getResponse(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(keyApiKey) ?? '';

    if (apiKey.isEmpty) {
      return 'กรุณาตั้งค่า API Key สำหรับ Gemini ในหน้าตั้งค่าก่อน';
    }

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ??
            'ไม่มีคำตอบจาก AI';
      } else if (response.statusCode == 429) {
        return '🤖 AI ทำงานหนักเกินไป (Error 429)\nโควต้า API Key ของคุณเต็ม หรือเรียกใช้งานถี่เกินไป กรุณารอสักครู่แล้วลองใหม่ หรือเปลี่ยน API Key ครับ';
      } else {
        debugPrint('Gemini Error: ${response.body}');
        return 'เกิดข้อผิดพลาดในการเรียก AI: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Gemini Exception: $e');
      return 'ไม่สามารถเชื่อมต่อกับ AI ได้: $e';
    }
  }

  Future<String> predictSales(String salesCsv) async {
    final prompt = '''
บทบาท: คุณคือที่ปรึกษากิตติมศักดิ์และผู้เชี่ยวชาญด้านการวางแผนกลยุทธ์การตลาด (Chief Marketing Strategist) ที่มีความน่าเชื่อถือสูง
หน้าที่: วิเคราะห์ข้อมูลยอดขายเชิงลึกจาก CSV ด้านล่าง เพื่อวางแผนกลยุทธ์การตลาดที่แม่นยำและสร้างยอดขายเติบโตอย่างยั่งยืน

ข้อมูลการขาย (CSV):
$salesCsv

สิ่งที่ต้องวิเคราะห์และนำเสนอ (ในรูปแบบมืออาชีพ):
1. 📊 **Executive Summary**: สรุปสถานการณ์ภาพรวมปัจจุบัน แนวโน้มการเติบโต และจุดที่ต้องจับตามองเป็นพิเศษ
2. 🏆 **Hero Product Strategy**: วิเคราะห์สินค้าที่ทำรายได้หลัก และกลยุทธ์ในการรักษาฐานลูกค้ากลุ่มนี้
3. 📦 **Inventory Optimization**: คำแนะนำการบริหารสต็อกเชิงกลยุทธ์ สินค้าใดควรระบายออกเพื่อเพิ่ม Cash Flow
4. 🧠 **SWOT Analysis**: จุดแข็ง จุดอ่อน โอกาส และอุปสรรค ของข้อมูลชุดนี้
5. 🚀 **Strategic Action Plan**: แผนการตลาด 3 ข้อที่โฟกัสผลลัพธ์ (Results-Oriented) สำหรับสัปดาห์ถัดไป

โทนการตอบ: สุภาพ ทางการ น่าเชื่อถือ เหมือนที่ปรึกษามืออาชีพรายงานต่อผู้บริหาร (Professional & Trustworthy) ใช้ศัพท์ธุรกิจฟังก์ชันได้ตามความเหมาะสม
''';
    return getResponse(prompt);
  }

  Future<String> optimizeInventory(String inventoryData) async {
    final prompt = '''
บทบาท: เพื่อนคู่คิดเจ้าของร้าน (Inventory Guru Friend)
หน้าที่: ช่วยวิเคราะห์สุขภาพสต็อกสินค้าจาก CSV ด้านล่างนี้ แล้วแนะนำอย่างตรงไปตรงมา

ข้อมูลสต็อก (รูปแบบ: ชื่อสินค้า, สต็อกปัจจุบัน, จุดสั่งซื้อ, ยอดขาย 30 วันล่าสุด, วันที่ขายล่าสุด):
$inventoryData

สิ่งที่อยากให้ช่วยดู (แยกหัวข้อชัดเจน):
1. 🚨 **ของต้องเติมด่วน (Reorder)**: สินค้าที่สต็อกต่ำกว่าจุดสั่งซื้อ หรือขายดีมากจนของจะขาด (Run Rate สูง)
2. ⚠️ **ของล้นสต็อก (Overstock)**: สินค้าที่สต็อกจม นอนนิ่งมานาน (ขายไม่ออกใน 30 วัน หรือขายได้น้อยมากเมื่อเทียบกับสต็อกที่มี)
3. 💡 **คำแนะนำพิเศษ**: ไอเดียระบายของหรือจัดโปรโมชั่น

โทนการตอบ: เพื่อนคุยกับเพื่อน สนุก เข้าใจง่าย และใช้ Emoji ประกอบ
''';
    return getResponse(prompt);
  }
}
