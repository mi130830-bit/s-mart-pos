import 'dart:convert';

import 'package:http/http.dart' as http;

class LineIdentity {
  const LineIdentity({
    required this.subject,
    this.displayName,
    this.pictureUrl,
  });

  final String subject;
  final String? displayName;
  final String? pictureUrl;
}

class LineIdentityVerificationException implements Exception {
  const LineIdentityVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Verifies a LIFF ID token with LINE and derives the customer identity only
/// from LINE's verified response. The token and response body are never logged.
class LineIdentityService {
  LineIdentityService({required String channelId, http.Client? client})
    : _channelId = channelId.trim(),
      _client = client ?? http.Client();

  final String _channelId;
  final http.Client _client;

  static final Uri verificationEndpoint = Uri.parse(
    'https://api.line.me/oauth2/v2.1/verify',
  );

  Future<LineIdentity> verify(String idToken) async {
    if (_channelId.isEmpty) {
      throw const LineIdentityVerificationException(
        'LINE Login verification is not configured',
      );
    }
    if (idToken.trim().isEmpty) {
      throw const LineIdentityVerificationException('Missing LIFF ID token');
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            verificationEndpoint,
            body: {'id_token': idToken, 'client_id': _channelId},
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const LineIdentityVerificationException(
        'LINE identity verification is unavailable',
      );
    }

    if (response.statusCode != 200) {
      throw const LineIdentityVerificationException('Invalid LIFF ID token');
    }

    try {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final subject = data['sub']?.toString().trim() ?? '';
      final audience = data['aud']?.toString().trim();
      if (subject.isEmpty || (audience != null && audience != _channelId)) {
        throw const FormatException();
      }
      return LineIdentity(
        subject: subject,
        displayName: _cleanOptional(data['name']),
        pictureUrl: _cleanOptional(data['picture']),
      );
    } catch (_) {
      throw const LineIdentityVerificationException(
        'Invalid LINE identity response',
      );
    }
  }

  static String? _cleanOptional(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
