import 'dart:convert';
import 'dart:io';

import 'package:backend/middlewares/role_middleware.dart';
import 'package:backend/middlewares/jwt_middleware.dart';
import 'package:backend/middlewares/internal_service_auth_middleware.dart';
import 'package:backend/services/line_webhook_signature_verifier.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _TestConnectionInfo implements HttpConnectionInfo {
  _TestConnectionInfo(this.remoteAddress);

  @override
  final InternetAddress remoteAddress;

  @override
  int get localPort => 8080;

  @override
  int get remotePort => 443;
}

void main() {
  test('role guard permits only configured staff roles', () async {
    final handler = requireRoles({'admin', 'cashier'})(
      (_) => Response.ok('allowed'),
    );

    final denied = await handler(
      Request(
        'GET',
        Uri.parse('http://local/admin'),
        context: {
          'user': {'role': 'driver'},
        },
      ),
    );
    final allowed = await handler(
      Request(
        'GET',
        Uri.parse('http://local/admin'),
        context: {
          'user': {'role': 'CASHIER'},
        },
      ),
    );

    expect(denied.statusCode, 403);
    expect(allowed.statusCode, 200);
  });

  group('JWT access guard', () {
    const secret = 'test-access-secret';

    String token({required String type, required String issuer}) => JWT({
      'id': '1',
      'role': 'ADMIN',
      'type': type,
    }, issuer: issuer).sign(SecretKey(secret));

    final handler = jwtMiddleware(accessSecret: secret)((request) {
      final user = request.context['user'] as Map<String, dynamic>;
      return Response.ok(user['id'].toString());
    });

    test('accepts POS-issued access token', () async {
      final response = await handler(
        Request(
          'GET',
          Uri.parse('http://local/orders'),
          headers: {
            'authorization':
                'Bearer ${token(type: 'access', issuer: 'https://s-link-pos.com')}',
          },
        ),
      );
      expect(response.statusCode, 200);
      expect(await response.readAsString(), '1');
    });

    test('rejects refresh token and wrong issuer generically', () async {
      for (final invalid in [
        token(type: 'refresh', issuer: 'https://s-link-pos.com'),
        token(type: 'access', issuer: 'https://attacker.invalid'),
      ]) {
        final response = await handler(
          Request(
            'GET',
            Uri.parse('http://local/orders'),
            headers: {'authorization': 'Bearer $invalid'},
          ),
        );
        expect(response.statusCode, 401);
        expect(
          await response.readAsString(),
          jsonEncode({'error': 'Token rejected'}),
        );
      }
    });
  });

  group('internal service guard', () {
    final handler = internalServiceAuthMiddleware(
      internalSecret: 'internal-test-secret',
      jwtAccessSecret: 'jwt-test-secret',
      maxBodyBytes: 32,
    )((_) => Response.ok('allowed'));

    test('accepts configured secret and rejects missing credentials', () async {
      final allowed = await handler(
        Request(
          'POST',
          Uri.parse('http://local/line-internal/push-message'),
          headers: {'x-internal-secret': 'internal-test-secret'},
        ),
      );
      final denied = await handler(
        Request('POST', Uri.parse('http://local/line-internal/push-message')),
      );
      expect(allowed.statusCode, 200);
      expect(denied.statusCode, 401);
    });

    test('configured secret rejects a loopback request without it', () async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://local/line-internal/push-message'),
          context: {
            'shelf.io.connection_info': _TestConnectionInfo(
              InternetAddress.loopbackIPv4,
            ),
          },
        ),
      );
      expect(response.statusCode, 401);
    });

    test('loopback remains available for local dev without a secret', () async {
      final localHandler = internalServiceAuthMiddleware(
        internalSecret: '',
        jwtAccessSecret: 'jwt-test-secret',
      )((_) => Response.ok('allowed'));
      final response = await localHandler(
        Request(
          'POST',
          Uri.parse('http://local/line-internal/push-message'),
          context: {
            'shelf.io.connection_info': _TestConnectionInfo(
              InternetAddress.loopbackIPv4,
            ),
          },
        ),
      );
      expect(response.statusCode, 200);
    });

    test(
      'rejects declared oversized bodies before controller parsing',
      () async {
        final response = await handler(
          Request(
            'POST',
            Uri.parse('http://local/line-internal/push-receipt-image'),
            headers: {
              'x-internal-secret': 'internal-test-secret',
              'content-length': '33',
            },
          ),
        );
        expect(response.statusCode, 413);
      },
    );

    test('secret comparison handles different lengths safely', () {
      expect(InternalServiceAuth.constantTimeEquals('same', 'same'), isTrue);
      expect(
        InternalServiceAuth.constantTimeEquals('short', 'longer'),
        isFalse,
      );
    });
  });

  test('LINE webhook signature verifies the exact raw UTF-8 body', () {
    const body = '{"events":[{"type":"follow"}]}';
    const secret = 'channel-secret';
    final signature = base64Encode(
      Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(body)).bytes,
    );
    const verifier = LineWebhookSignatureVerifier();

    expect(
      verifier.verify(
        rawBody: body,
        signature: signature,
        channelSecret: secret,
      ),
      isTrue,
    );
    expect(
      verifier.verify(
        rawBody: '$body ',
        signature: signature,
        channelSecret: secret,
      ),
      isFalse,
    );
    expect(
      verifier.verify(rawBody: body, signature: signature, channelSecret: ''),
      isFalse,
    );
  });
}
