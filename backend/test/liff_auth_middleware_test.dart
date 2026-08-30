import 'dart:convert';

import 'package:backend/middlewares/liff_auth_middleware.dart';
import 'package:backend/services/line_identity_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  LineIdentityService verifier() => LineIdentityService(
    channelId: 'channel',
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({'sub': 'verified-subject', 'aud': 'channel'}),
        200,
      ),
    ),
  );

  test('required LIFF middleware rejects missing authorization', () async {
    final handler = liffAuthMiddleware(verifier: verifier())(
      (_) => Response.ok('should not run'),
    );

    final response = await handler(
      Request('GET', Uri.parse('http://local/me')),
    );

    expect(response.statusCode, 401);
  });

  test('verified subject wins over spoofed client lineUserId', () async {
    final handler = liffAuthMiddleware(verifier: verifier())((request) {
      final identity = request.context[lineIdentityContextKey] as LineIdentity;
      return Response.ok(identity.subject);
    });
    final request = Request(
      'GET',
      Uri.parse('http://local/me?lineUserId=attacker-controlled'),
      headers: {'authorization': 'Bearer genuine-id-token'},
    );

    final response = await handler(request);

    expect(await response.readAsString(), 'verified-subject');
  });

  test('optional middleware rejects an invalid supplied token', () async {
    final invalidVerifier = LineIdentityService(
      channelId: 'channel',
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    final handler = optionalLiffAuthMiddleware(verifier: invalidVerifier)(
      (_) => Response.ok('guest'),
    );

    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://local/orders'),
        headers: {'authorization': 'Bearer invalid-token'},
      ),
    );

    expect(response.statusCode, 401);
  });
}
