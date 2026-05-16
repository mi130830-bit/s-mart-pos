import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/verification_service.dart';

class PaymentController {
  final VerificationService _verifier = VerificationService();

  Router get router {
    final router = Router();
    router.post('/verify-slip', _handleVerifySlip);
    return router;
  }

  Future<Response> _handleVerifySlip(Request request) async {
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);

      final String? base64Image = body['image'];
      final double amount = double.tryParse(body['amount'].toString()) ?? 0.0;

      if (base64Image == null || base64Image.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'No image provided'}),
        );
      }

      // Call Service
      final result = await _verifier.verifySlip(
        fileBase64: base64Image,
        amount: amount,
      );

      // Check Mock Result
      if (result['status'] == 200) {
        final data = result['data'];
        // Simple validation: Check amount
        final slipAmount = double.tryParse(data['amount'].toString()) ?? 0.0;

        if ((slipAmount - amount).abs() < 0.01) {
          return Response.ok(
            jsonEncode({
              'success': true,
              'message': 'ตรวจสอบสลิปสำเร็จ',
              'data': data,
            }),
          );
        } else {
          return Response.ok(
            jsonEncode({
              'success': false,
              'message': 'ยอดเงินไม่ตรง (Slip: $slipAmount, Bill: $amount)',
            }),
          );
        }
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Verification failed'}),
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Server Error: $e'}),
      );
    }
  }
}
