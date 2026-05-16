import 'dart:io';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:dbcrypt/dbcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../db_config.dart';

class AuthController {
  // Secret key for signing JWT (In production, use env variable)
  static const String _jwtSecret = 's_link_pos_secret_key_2026';

  Router get router {
    final router = Router();
    router.post('/login', _login);
    return router;
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
        isMatch = DBCrypt().checkpw(password, dbHash ?? '');
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

      // Generate JWT
      final jwt = JWT({
        'id': row['id'],
        'username': row['username'],
        'role': row['role'],
      }, issuer: 'https://s-link-pos.com');

      final token = jwt.sign(
        SecretKey(_jwtSecret),
        expiresIn: Duration(hours: 24),
      );

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
          'user': {
            'id': row['id'],
            'username': row['username'],
            'role': row['role'],
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
