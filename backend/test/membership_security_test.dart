import 'dart:math';

import 'package:backend/services/membership_service.dart';
import 'package:backend/controllers/membership_controller.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('Thai phone normalization', () {
    test('normalizes local and +66 formats', () {
      expect(
        MembershipSecurity.normalizeThaiPhone('081-234-5678'),
        '0812345678',
      );
      expect(
        MembershipSecurity.normalizeThaiPhone('+66 81 234 5678'),
        '0812345678',
      );
    });

    test('rejects invalid contact values', () {
      expect(
        () => MembershipSecurity.normalizeThaiPhone('1234'),
        throwsA(isA<MembershipException>()),
      );
    });
  });

  test('pairing token has at least 128 bits and hashes deterministically', () {
    final secret = MembershipSecurity.createPairingSecret(random: Random(7));
    expect(secret.token.length, greaterThanOrEqualTo(22));
    expect(secret.hash, hasLength(64));
    expect(MembershipSecurity.hashToken(secret.token), secret.hash);
    expect(
      MembershipSecurity.hashToken('${secret.token}x'),
      isNot(secret.hash),
    );
  });

  test('expiry boundary is fail closed', () {
    final now = DateTime.utc(2026, 8, 25, 12);
    expect(MembershipSecurity.isExpired(now, now), isTrue);
    expect(
      MembershipSecurity.isExpired(now.add(const Duration(seconds: 1)), now),
      isFalse,
    );
  });

  test('pairing preview is pending-only, unexpired, and masks phone', () {
    final now = DateTime.utc(2026, 8, 25, 12);
    expect(
      MembershipSecurity.pairingPreviewAvailable(
        status: 'PENDING',
        expiresAt: now.add(const Duration(minutes: 1)),
        now: now,
      ),
      isTrue,
    );
    expect(
      MembershipSecurity.pairingPreviewAvailable(
        status: 'CONSUMED',
        expiresAt: now.add(const Duration(minutes: 1)),
        now: now,
      ),
      isFalse,
    );
    expect(
      MembershipSecurity.pairingPreviewAvailable(
        status: 'PENDING',
        expiresAt: now,
        now: now,
      ),
      isFalse,
    );
    expect(MembershipSecurity.maskPhone('0812345678'), '***-***-5678');
    expect(MembershipSecurity.maskPhone('123'), '***');
    expect(MembershipSecurity.maskMemberCode('SM-ABCDEF1234'), '••••-1234');
    expect(MembershipSecurity.maskMemberCode('1234'), '••••');
    expect(MembershipSecurity.maskName('Somchai Jai Dee'), 'S•••• J•• D••');
    expect(MembershipSecurity.maskName('สมชาย ใจดี'), 'ส•••• ใ•••');
    expect(MembershipSecurity.maskName('A'), '•');
    expect(MembershipSecurity.maskName('  '), '•••');
  });

  test('quick-create validates input and matches only the same replay', () {
    const requestUuid = '123e4567-e89b-42d3-a456-426614174000';
    expect(
      MembershipSecurity.validateStrictRequestUuid(requestUuid),
      requestUuid,
    );
    expect(
      MembershipSecurity.validateMemberName('  Somchai   Jai Dee  '),
      'Somchai Jai Dee',
    );
    const row = <String, String?>{
      'request_type': 'SELF_SIGNUP',
      'line_subject': '',
      'normalized_phone': '0812345678',
      'line_display_name': 'Somchai Jai Dee',
      'candidate_customer_id': '12',
    };
    expect(
      MembershipSecurity.quickCreateReplayMatches(
        row,
        normalizedPhone: '0812345678',
        name: 'Somchai Jai Dee',
      ),
      isTrue,
    );
    expect(
      MembershipSecurity.quickCreateReplayMatches(
        row,
        normalizedPhone: '0899999999',
        name: 'Somchai Jai Dee',
      ),
      isFalse,
    );
    expect(
      MembershipSecurity.quickCreateReplayMatches(
        {...row, 'candidate_customer_id': null},
        normalizedPhone: '0812345678',
        name: 'Somchai Jai Dee',
      ),
      isFalse,
    );
    expect(
      () => MembershipSecurity.validateStrictRequestUuid('request-123'),
      throwsA(isA<MembershipException>()),
    );
  });

  test('optional member text cleans addresses safely', () {
    expect(MembershipSecurity.cleanOptionalText('  12/3   Main Road  ', 100), '12/3 Main Road');
    expect(MembershipSecurity.cleanOptionalText('   ', 100), isNull);
    expect(
      () => MembershipSecurity.cleanOptionalText('bad\u0001value', 100),
      throwsA(isA<MembershipException>()),
    );
    expect(
      () => MembershipSecurity.cleanOptionalText('abcd', 3),
      throwsA(isA<MembershipException>()),
    );
  });

  test('request UUID helper creates valid unique idempotency keys', () {
    final first = MembershipSecurity.newRequestUuid(random: Random(1));
    final second = MembershipSecurity.newRequestUuid(random: Random(2));
    expect(MembershipSecurity.validateRequestUuid(first), first);
    expect(first, isNot(second));
    expect(
      () => MembershipSecurity.validateRequestUuid('short'),
      throwsA(isA<MembershipException>()),
    );
  });

  test('cashier may operate queue but cannot approve recovery conflicts', () {
    expect(MembershipSecurity.canApproveRole('cashier'), isFalse);
    expect(MembershipSecurity.canApproveRole('manager'), isTrue);
    expect(MembershipSecurity.canApproveRole('OWNER'), isTrue);
  });

  test('approval guard accepts only recovery with verified LINE subject', () {
    expect(
      MembershipSecurity.canApproveRequest(
        requestType: 'RECOVERY',
        lineSubject: 'U123',
      ),
      isTrue,
    );
    expect(
      MembershipSecurity.canApproveRequest(
        requestType: 'PAIRING',
        lineSubject: 'U123',
      ),
      isFalse,
    );
    expect(
      MembershipSecurity.canApproveRequest(
        requestType: 'RECOVERY',
        lineSubject: '  ',
      ),
      isFalse,
    );
  });

  test('membership member route requires verified LIFF context', () async {
    final response = await MembershipController().memberRouter.call(
      Request('POST', Uri.parse('http://local/signup'), body: '{}'),
    );
    expect(response.statusCode, 401);
  });

  test('pairing preview route requires verified LIFF context', () async {
    final response = await MembershipController().memberRouter.call(
      Request(
        'POST',
        Uri.parse('http://local/pairing/preview'),
        body: '{"token":"not-authoritative"}',
      ),
    );
    expect(response.statusCode, 401);
  });

  test('cashier cannot approve a recovery request', () async {
    final response = await MembershipController().staffRouter.call(
      Request(
        'POST',
        Uri.parse('http://local/requests/request-123/approve'),
        context: {
          'user': {'id': '9', 'role': 'cashier'},
        },
      ),
    );
    expect(response.statusCode, 403);
  });
}
