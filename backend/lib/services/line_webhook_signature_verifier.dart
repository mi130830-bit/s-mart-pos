import 'dart:convert';

import 'package:crypto/crypto.dart';

class LineWebhookSignatureVerifier {
  const LineWebhookSignatureVerifier();

  bool verify({
    required String rawBody,
    required String? signature,
    required String channelSecret,
  }) {
    if (signature == null ||
        signature.trim().isEmpty ||
        channelSecret.isEmpty) {
      return false;
    }
    final digest = Hmac(
      sha256,
      utf8.encode(channelSecret),
    ).convert(utf8.encode(rawBody));
    final expected = base64Encode(digest.bytes);
    return _constantTimeEquals(expected, signature.trim());
  }

  bool _constantTimeEquals(String left, String right) {
    final a = utf8.encode(left);
    final b = utf8.encode(right);
    var difference = a.length ^ b.length;
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      difference |= av ^ bv;
    }
    return difference == 0;
  }
}
