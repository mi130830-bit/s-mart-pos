class VerificationService {
  // ⚠️ Mock Implementation for now.
  // Later replace with actual API call to EasySlip/SlipOK

  static const String apiKey = 'YOUR_API_KEY';
  static const String apiUrl = 'https://developer.easyslip.com/api/v1/verify';

  Future<Map<String, dynamic>> verifySlip({
    required String fileBase64,
    required double amount,
  }) async {
    // ------------------------------------------------------------------
    // 🚧 MOCK LOGIC (Simulation)
    // ------------------------------------------------------------------
    // Simulate network delay
    await Future.delayed(Duration(seconds: 2));

    // Always return success for now
    return {
      'status': 200,
      'data': {
        'success': true,
        'message': 'Slip Verified (Mock)',
        'amount': amount,
        'transRef': 'MOCK-${DateTime.now().millisecondsSinceEpoch}',
        'sender': {
          'bank': {'name': 'Mock Bank', 'short': 'MOCK'},
          'account': {'name': 'นาย ทดสอบ', 'bank': 'KBANK'},
        },
        'receiver': {
          'account': {'name': 'ร้านค้าตัวอย่าง'},
        },
      },
    };
    // ------------------------------------------------------------------

    /*
    // Real Implementation Example:
    try {
      final response = await http.post(
        Uri.parse(API_URL),
        headers: {
          'Authorization': 'Bearer $API_KEY',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': fileBase64, // or ensure format matches API requirements
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
         return {'status': response.statusCode, 'error': 'API Error'};
      }
    } catch (e) {
      return {'status': 500, 'error': e.toString()};
    }
    */
  }
}
