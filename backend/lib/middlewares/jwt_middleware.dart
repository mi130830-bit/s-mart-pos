import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/firebase_auth_verifier.dart';

/// Middleware สำหรับตรวจสอบ Firebase ID Token
Middleware jwtMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // ยกเว้น Path ที่ไม่ต้องการการตรวจสอบ (Public endpoints)
      final path = request.url.path;
      if (path == 'auth/login' || path.startsWith('health')) {
        return innerHandler(request);
      }

      // ดึง Header Authorization
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
          jsonEncode({'error': 'Missing or invalid Authorization header'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final token = authHeader.substring(7); // ตัดคำว่า "Bearer " ออก
      
      // ตรวจสอบ JWT
      final verifier = FirebaseAuthVerifier();
      Map<String, dynamic>? payload;
      try {
        payload = await verifier.verify(token);
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ JWT Middleware: Token rejected. Error: $e');
        return Response.forbidden(
          jsonEncode({'error': 'Token Rejected: $e'}),
          headers: {'content-type': 'application/json'},
        );
      }

      if (payload == null) {
        return Response.forbidden(
          jsonEncode({'error': 'Unauthorized or Invalid Token'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // แนบข้อมูลผู้ใช้เข้าไปใน context เพื่อให้ Controller เอาไปใช้ได้
      final updatedRequest = request.change(context: {'user': payload});

      return innerHandler(updatedRequest);
    };
  };
}
