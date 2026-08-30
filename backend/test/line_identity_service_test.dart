import 'dart:convert';

import 'package:backend/services/line_identity_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
    'posts the ID token and channel id to LINE and trusts verified sub',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'sub': 'verified-line-subject',
            'aud': 'login-channel',
            'name': 'Verified Name',
            'picture': 'https://example.test/picture.jpg',
          }),
          200,
        );
      });
      final service = LineIdentityService(
        channelId: 'login-channel',
        client: client,
      );

      final identity = await service.verify('secret-id-token');

      expect(captured.url, LineIdentityService.verificationEndpoint);
      expect(captured.method, 'POST');
      expect(captured.bodyFields, {
        'id_token': 'secret-id-token',
        'client_id': 'login-channel',
      });
      expect(identity.subject, 'verified-line-subject');
      expect(identity.displayName, 'Verified Name');
    },
  );

  test('fails closed when channel configuration is missing', () async {
    final service = LineIdentityService(
      channelId: '',
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(
      () => service.verify('token'),
      throwsA(isA<LineIdentityVerificationException>()),
    );
  });

  test('rejects a response for another audience', () async {
    final service = LineIdentityService(
      channelId: 'expected-channel',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'sub': 'user', 'aud': 'different-channel'}),
          200,
        ),
      ),
    );

    expect(
      () => service.verify('token'),
      throwsA(isA<LineIdentityVerificationException>()),
    );
  });
}
