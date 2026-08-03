import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai/ai_tools_service.dart';
import 'logger_service.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  static const String keyApiKey = 'gemini_api_key';
  
  final AiToolsService _toolsService = AiToolsService();
  
  ChatSession? _currentChat;

  // --- Persona Definitions ---
  final String _analystSystemInstruction = '''
คุณคือ 'สมปอง' นักวิเคราะห์ข้อมูลประจำร้าน S_MartPOS (Data Analyst)
เป้าหมาย: วิเคราะห์ยอดขาย แนะนำเทรนด์สินค้า และช่วยผู้ประกอบการตัดสินใจเรื่องสต็อก
ลักษณะนิสัย: สุภาพ เป็นกันเอง ใช้คำศัพท์เข้าใจง่าย มี emoji ประกอบ
หน้าที่: 
- วิเคราะห์ข้อมูลยอดขายจากระบบ
- ให้คำแนะนำเรื่องสินค้าที่ควรสต็อกเพิ่มหรือระบายออก
- ค้นหาบิลหรือยอดขายเมื่อผู้ใช้ต้องการ
คุณสามารถใช้เครื่องมือ (Tools) ในการค้นหาข้อมูลจากฐานข้อมูลของโปรแกรมได้ (อ่านได้อย่างเดียว ห้ามแก้ไข)
**กฏสำคัญ:** หากผู้ใช้สั่งให้ "วิเคราะห์ร้านค้า" หรือ "สรุปข้อมูล" แบบกว้างๆ ห้ามตอบกลับด้วยคำถามว่าอยากให้ช่วยอะไร แต่ให้คุณเรียกใช้เครื่องมือ `get_sales_summary` และ `get_top_selling_products` ทันที เพื่อดึงข้อมูลภาพรวมมาสรุปและวิเคราะห์ให้ผู้ใช้ฟังเลย
''';

  final String _accountantSystemInstruction = '''
คุณคือ 'สมศรี' นักบัญชีสุดเป๊ะประจำร้าน S_MartPOS (Chief Accountant)
เป้าหมาย: ตรวจสอบความถูกต้องของตัวเลข ดูแลรายรับ-รายจ่าย และติดตามลูกหนี้
ลักษณะนิสัย: จริงจัง รอบคอบ ตรงไปตรงมา รักความถูกต้องของตัวเลข
หน้าที่:
- ตรวจสอบรายจ่ายเปรียบเทียบกับรายรับ
- สรุปยอดลูกหนี้ที่ต้องติดตามทวงถาม
- แจกแจงรายจ่ายแยกตามหมวดหมู่เพื่อดูว่าส่วนไหนใช้เงินเยอะสุด
คุณสามารถใช้เครื่องมือ (Tools) ในการค้นหาข้อมูลจากฐานข้อมูลของโปรแกรมได้ (อ่านได้อย่างเดียว ห้ามแก้ไข)
**กฏสำคัญ:** หากผู้ใช้สั่งให้ "วิเคราะห์ร้านค้า" หรือ "สรุปข้อมูล" แบบกว้างๆ ห้ามตอบกลับด้วยคำถามว่าอยากให้ช่วยอะไร แต่ให้คุณเรียกใช้เครื่องมือ `get_sales_summary`, `get_expenses` และ `get_debtors` ทันที เพื่อดึงข้อมูลภาพรวมการเงินมาสรุปให้ผู้ใช้ฟังเลย
''';

  Future<String> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyApiKey) ?? '';
  }

  Future<void> startChat({required String persona}) async {
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) throw Exception('กรุณาตั้งค่า API Key สำหรับ Gemini ในหน้าตั้งค่าก่อน');

    final systemInstruction = persona == 'accountant' 
        ? _accountantSystemInstruction 
        : _analystSystemInstruction;

    final model = GenerativeModel(
      model: 'gemini-3.0-pro',
      apiKey: apiKey,
      systemInstruction: Content.system(systemInstruction),
      tools: [_toolsService.aiTool],
    );

    _currentChat = model.startChat();
    LoggerService.info('AiService', 'Chat session started with persona: \$persona');
  }

  Future<String> sendMessage(String text) async {
    if (_currentChat == null) {
      return 'กรุณาเริ่มแชทก่อน (Start Chat)';
    }

    try {
      var response = await _currentChat!.sendMessage(Content.text(text));
      
      // Handle Function Calling Loop
      while (response.functionCalls.isNotEmpty) {
        final functionResponses = <FunctionResponse>[];
        
        for (var functionCall in response.functionCalls) {
           final result = await _toolsService.handleFunctionCall(functionCall);
           functionResponses.add(FunctionResponse(functionCall.name, result));
        }
        
        // Send the function response back to the model
        response = await _currentChat!.sendMessage(
          Content.functionResponses(functionResponses)
        );
      }

      return response.text ?? 'ไม่มีคำตอบจาก AI';
    } catch (e) {
      LoggerService.error('AiService', 'SendMessage Exception', e);
      return 'เกิดข้อผิดพลาดในการเชื่อมต่อกับ AI: \$e';
    }
  }

  // Backward compatibility for old single-shot methods
  Future<String> predictSales(String salesCsv) async {
    await startChat(persona: 'analyst');
    return sendMessage('วิเคราะห์ยอดขายจากข้อมูลนี้:\\n\$salesCsv');
  }

  Future<String> optimizeInventory(String inventoryData) async {
    await startChat(persona: 'analyst');
    return sendMessage('วิเคราะห์สต็อกสินค้าจากข้อมูลนี้:\\n\$inventoryData');
  }
}
