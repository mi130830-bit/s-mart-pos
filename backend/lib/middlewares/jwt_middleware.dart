import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../env_config.dart';

const _trustedIssuer = 'https://s-link-pos.com';

/// Middleware for POS-issued S-Link access tokens.
Middleware jwtMiddleware({String? accessSecret}) {
  final secret = accessSecret ?? (EnvConfig()['JWT_ACCESS_SECRET'] ?? '');
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
        return Response.unauthorized(
          jsonEncode({'error': 'Missing or invalid Authorization header'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final token = authHeader.substring(7); // ตัดคำว่า "Bearer " ออก

      Map<String, dynamic> payload;
      try {
        if (secret.isEmpty) throw const FormatException('Missing JWT secret');
        final jwt = JWT.verify(
          token,
          SecretKey(secret),
          issuer: _trustedIssuer,
        );
        payload = jwt.payload as Map<String, dynamic>;
        if (payload['type'] != 'access') {
          throw const FormatException('Invalid JWT type');
        }
      } catch (_) {
        return Response.unauthorized(
          jsonEncode({'error': 'Token rejected'}),
          headers: {'content-type': 'application/json'},
        );
      }

      // แนบข้อมูลผู้ใช้เข้าไปใน context เพื่อให้ Controller เอาไปใช้ได้
      final updatedRequest = request.change(
        context: {...request.context, 'user': payload},
      );

      return innerHandler(updatedRequest);
    };
  };
}
