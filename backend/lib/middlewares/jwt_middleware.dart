import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
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
      
      // ตรวจสอบ JWT (Custom JWT by POS Desktop)
      Map<String, dynamic>? payload;
      try {
        final jwt = JWT.verify(token, SecretKey('s_link_pos_secret_key_2026'));
        payload = jwt.payload as Map<String, dynamic>;
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ JWT Middleware: Token rejected. Error: $e');
        return Response.forbidden(
          jsonEncode({'error': 'Token Rejected: $e'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // แนบข้อมูลผู้ใช้เข้าไปใน context เพื่อให้ Controller เอาไปใช้ได้
      final updatedRequest = request.change(context: {'user': payload});

      return innerHandler(updatedRequest);
    };
  };
}
