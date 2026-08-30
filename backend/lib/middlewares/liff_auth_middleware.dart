import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../env_config.dart';
import '../services/line_identity_service.dart';

const lineIdentityContextKey = 'lineIdentity';

Middleware liffAuthMiddleware({LineIdentityService? verifier}) {
  final identityVerifier =
      verifier ??
      LineIdentityService(channelId: EnvConfig().lineLoginChannelId);

  return (Handler innerHandler) {
    return (Request request) async {
      final token = bearerToken(request.headers['authorization']);
      if (token == null) return _unauthorized('LIFF authentication required');

      try {
        final identity = await identityVerifier.verify(token);
        return innerHandler(
          request.change(
            context: {...request.context, lineIdentityContextKey: identity},
          ),
        );
      } on LineIdentityVerificationException {
        return _unauthorized('Invalid LIFF authentication');
      } catch (_) {
        return _unauthorized('Invalid LIFF authentication');
      }
    };
  };
}

/// Guest requests continue without identity. If a Bearer value is present it
/// must verify; an invalid token never silently downgrades to a guest.
Middleware optionalLiffAuthMiddleware({LineIdentityService? verifier}) {
  final identityVerifier =
      verifier ??
      LineIdentityService(channelId: EnvConfig().lineLoginChannelId);
  return (Handler innerHandler) {
    return (Request request) async {
      final header = request.headers['authorization'];
      if (header == null || header.trim().isEmpty) return innerHandler(request);
      final token = bearerToken(header);
      if (token == null) return _unauthorized('Invalid LIFF authentication');
      try {
        final identity = await identityVerifier.verify(token);
        return innerHandler(
          request.change(
            context: {...request.context, lineIdentityContextKey: identity},
          ),
        );
      } catch (_) {
        return _unauthorized('Invalid LIFF authentication');
      }
    };
  };
}

String? bearerToken(String? header) {
  if (header == null) return null;
  final match = RegExp(
    r'^Bearer\s+([^\s]+)$',
    caseSensitive: false,
  ).firstMatch(header.trim());
  return match?.group(1);
}

Response _unauthorized(String message) => Response.unauthorized(
  jsonEncode({'error': message}),
  headers: {'content-type': 'application/json'},
);
