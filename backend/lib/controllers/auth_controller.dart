import 'dart:io';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:dbcrypt/dbcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../db_config.dart';
import '../env_config.dart';

class AuthController {
  // Secret key for signing JWT (In production, use env variable)
  String get _jwtSecret =>
      EnvConfig()['JWT_ACCESS_SECRET'] ?? 's_link_pos_secret_key_2026';
  String get _refreshSecret =>
      EnvConfig()['JWT_REFRESH_SECRET'] ?? 's_link_pos_refresh_secret_2026';

  Router get router {
    final router = Router();
    router.post('/login', _login);
    router.post('/refresh', _refresh);
    return router;
  }

  String _createAccessToken({
    required Map<String, String?> user,
    required int? employeeId,
    required String? employeeName,
  }) {
    return JWT({
      'id': user['id'],
      'username': user['username'],
      'role': user['role'],
      'employee_id': employeeId,
      'employee_name': employeeName,
      'type': 'access',
    }, issuer: 'https://s-link-pos.com').sign(
      SecretKey(_jwtSecret),
      expiresIn: const Duration(hours: 24),
    );
  }

  String _createRefreshToken(Map<String, String?> user) {
    return JWT(
      {'id': user['id'], 'type': 'refresh'},
      issuer: 'https://s-link-pos.com',
    ).sign(SecretKey(_refreshSecret), expiresIn: const Duration(days: 30));
  }

  Future<Response> _refresh(Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final refreshToken = body['refresh_token']?.toString() ?? '';
      if (refreshToken.isEmpty) {
        return Response.unauthorized(
          jsonEncode({'error': 'Refresh token required'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final verified = JWT.verify(refreshToken, SecretKey(_refreshSecret));
      final payload = verified.payload as Map<String, dynamic>;
      if (payload['type'] != 'refresh' || payload['id'] == null) {
        throw const FormatException('Invalid refresh token type');
      }

      final conn = await DbConfig().connection;
      final result = await conn.execute(
        'SELECT id, username, role FROM user WHERE id = :id LIMIT 1',
        {'id': payload['id']},
      );
      if (result.rows.isEmpty) {
        return Response.unauthorized(
          jsonEncode({'error': 'User no longer exists'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final user = result.rows.first.assoc();
      final empResult = await conn.execute(
        'SELECT id, display_name FROM employee_profile WHERE user_id = :uid LIMIT 1',
        {'uid': user['id']},
      );
      int? employeeId;
      String? employeeName;
      if (empResult.rows.isNotEmpty) {
        employeeId = int.tryParse(
          empResult.rows.first.colAt(0)?.toString() ?? '',
        );
        employeeName = empResult.rows.first.colAt(1)?.toString();
      }

      return Response.ok(
        jsonEncode({
          'token': _createAccessToken(
            user: user,
            employeeId: employeeId,
            employeeName: employeeName,
          ),
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.unauthorized(
        jsonEncode({'error': 'Refresh token rejected'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> _login(Request request) async {
    try {
      final payload = await request.readAsString();
      final Map<String, dynamic> body = jsonDecode(payload);

      final username = body['username'];
      final password = body['password'];

      if (username == null || password == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Username and password required'}),
        );
      }

      final conn = await DbConfig().connection;
      stdout.writeln('🔍 Auth: DB Connected. Querying user $username...');

      // Query user
      // Assuming table 'user' has columns: id, username, passwordHash, ...
      final result = await conn.execute(
        'SELECT * FROM user WHERE username = :u',
        {'u': username},
      );
      stdout.writeln('👤 Auth: User Found? ${result.rows.isNotEmpty}');

      if (result.rows.isEmpty) {
        return Response.forbidden(jsonEncode({'error': 'Invalid credentials'}));
      }

      final row = result.rows.first.assoc();
      stderr.writeln('🔍 Auth Debug: Fetch Row: $row');
      String? dbHash = row['passwordHash'];

      // Fallback: Check for snake_case
      if (dbHash == null || dbHash.isEmpty) {
        dbHash = row['password_hash'];
      }

      // ⚠️ Fallback: If passwordHash is empty, try legacy 'password' column
      if (dbHash == null || dbHash.isEmpty) {
        if (row.containsKey('password')) {
          dbHash = row['password'];
          stderr.writeln('⚠️ Auth: Using legacy "password" column: $dbHash');
        }
      }

      stderr.writeln('🔍 Auth Debug: Final Hash to check: $dbHash');

      // Verify Password (BCrypt)
      bool isMatch = false;
      bool isLegacy = false; // Flag to trigger update

      try {
        final rawHash = dbHash ?? '';
        final normalizedHash =
            (rawHash.startsWith(r'$2b$') || rawHash.startsWith(r'$2y$'))
            ? r'$2a$' + rawHash.substring(4)
            : rawHash;
        isMatch = DBCrypt().checkpw(password, normalizedHash);
        stdout.writeln('🔐 Auth: BCrypt Check Result: $isMatch');
      } catch (e) {
        stderr.writeln(
          '⚠️ Auth: BCrypt Error (Possible legacy plain text?): $e',
        );
        // Fallback: Check plain text
        if (password == dbHash) {
          stderr.writeln('⚠️ Auth: Plain Text Password Match (Legacy Mode).');
          isMatch = true;
          isLegacy = true;
        }
      }

      if (!isMatch) {
        stdout.writeln('❌ Auth: Password mismatch for user $username');
      } else {
        stdout.writeln('✅ Auth: Login Successful for user $username');

        // ✅ Auto-Migrate: If legacy password, hash it and update DB immediately
        if (isLegacy) {
          try {
            final newSalt = DBCrypt().gensalt();
            final newHash = DBCrypt().hashpw(password, newSalt);
            await conn.execute(
              'UPDATE user SET passwordHash = :h WHERE id = :id',
              {'h': newHash, 'id': row['id']},
            );
            stdout.writeln(
              '🔄 Auth: Auto-migrated password to BCrypt for user $username',
            );
          } catch (uptErr) {
            stderr.writeln('❌ Auth: Failed to migrate password: $uptErr');
          }
        }
      }

      if (!isMatch) {
        return Response.forbidden(jsonEncode({'error': 'Invalid credentials'}));
      }

      // Fetch Employee Profile
      final empResult = await conn.execute(
        'SELECT id, display_name FROM employee_profile WHERE user_id = :uid LIMIT 1',
        {'uid': row['id']},
      );

      int? employeeId;
      String? employeeName;
      if (empResult.rows.isNotEmpty) {
        employeeId = int.tryParse(
          empResult.rows.first.colAt(0)?.toString() ?? '',
        );
        employeeName = empResult.rows.first.colAt(1)?.toString();
      }

      // Generate JWT
      final token = _createAccessToken(
        user: row,
        employeeId: employeeId,
        employeeName: employeeName,
      );
      final refreshToken = _createRefreshToken(row);

      // Fetch Permissions
      final permResult = await conn.execute(
        'SELECT permissionKey, isAllowed FROM user_permission WHERE userId = :uid',
        {'uid': row['id']},
      );

      final Map<String, bool> permissions = {};
      for (final pRow in permResult.rows) {
        final p = pRow.assoc();
        permissions[p['permissionKey']!] =
            (int.tryParse(p['isAllowed']!) ?? 0) == 1;
      }

      return Response.ok(
        jsonEncode({
          'token': token,
          'refresh_token': refreshToken,
          'user': {
            'id': row['id'],
            'username': row['username'],
            'role': row['role'],
            'employee_id': employeeId,
            'employee_name': employeeName,
            'permissions': permissions,
          },
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stack) {
      stderr.writeln('🔥 Login Critical Error: $e');
      stderr.writeln(stack);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal Server Error: $e'}),
      );
    }
  }
}
