// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final url = Uri.parse('http://localhost:8080/api/v1/line/push-message');
  print('Testing connection to: $url');

  // Replace with a valid Line User ID if possible, or use a dummy that won't crash backend
  // If backend checks DB for existence, this might fail unless ID exists.
  // LineController.pushMessage calls LineService which hits Line API.
  // If ID is invalid, Line API returns 400, but our Backend returns 200 OK (catch block prints error).
  final testUserId = 'U85429xxxxxxxxxxxxxxxxxxxxxx'; // Dummy

  final testCases = [
    {
      'title': '1. Preparing (รับออเดอร์)',
      'msg':
          '🛒 ร้าน ส.บริการ ท่าข้าม ได้รับรายการสั่งซื้อของท่านแล้ว (#1001) \nกำลังดำเนินการจัดเตรียมสินค้าครับ... \n(เมื่อรถออกจากร้าน จะมีข้อความแจ้งเตือนอีกครั้งครับ)'
    },
    {
      'title': '2. Shipping (รถออก)',
      'msg': '🚚 รายการสั่งซื้อ #1001 \nสินค้ากำลังเดินทางไปส่งครับ'
    },
    {
      'title': '3. Completed (ส่งสำเร็จ)',
      'msg':
          'สินค้าจัดส่งถึงมือท่านเรียบร้อยแล้ว 📦 ขอบคุณที่ไว้วางใจใช้บริการ ส.บริการ ท่าข้าม ครับ 🙏 โอกาสหน้าเชิญใหม่นะครับ'
    }
  ];

  for (final test in testCases) {
    print('\n--- Testing: ${test['title']} ---');
    try {
      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'lineUserId': testUserId,
        'message': test['msg'],
      }));
      final response = await request.close();

      print('Response Status: ${response.statusCode}');
      final body = await response.transform(utf8.decoder).join();
      print('Response Body: $body');

      if (response.statusCode == 200) {
        print('✅ Success');
      } else {
        print('❌ Failed');
      }
    } catch (e) {
      print('❌ Connection Error: $e');
    }
    // Wait a bit
    await Future.delayed(Duration(seconds: 1));
  }
}
