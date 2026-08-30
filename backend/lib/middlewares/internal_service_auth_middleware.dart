import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../env_config.dart';
import 'jwt_middleware.dart';

class InternalServiceAuth {
  const InternalServiceAuth._();

  static bool constantTimeEquals(String provided, String expected) {
    final left = utf8.encode(provided);
    final right = utf8.encode(expected);
    var difference = left.length ^ right.length;
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final a = index < left.length ? left[index] : 0;
      final b = index < right.length ? right[index] : 0;
      difference |= a ^ b;
    }
    return difference == 0;
  }
}

/// A configured deployment secret is mandatory, including for loopback calls.
/// Without one, local development may use loopback or a valid POS access JWT.
Middleware internalServiceAuthMiddleware({
  String? internalSecret,
  String? jwtAccessSecret,
  int maxBodyBytes = 8 * 1024 * 1024,
}) {
  final expectedSecret =
      internalSecret ?? (EnvConfig()['INTERNAL_API_SECRET'] ?? '').trim();
  return (Handler innerHandler) {
    return (Request request) async {
      final contentLength = int.tryParse(
        request.headers[HttpHeaders.contentLengthHeader] ?? '',
      );
      if (contentLength != null && contentLength > maxBodyBytes) {
        return Response(413, body: 'Request body too large');
      }

      final provided = request.headers['x-internal-secret'] ?? '';
      if (expectedSecret.isNotEmpty) {
        if (InternalServiceAuth.constantTimeEquals(provided, expectedSecret)) {
          return innerHandler(request);
        }
        return Response.unauthorized(
          jsonEncode({'error': 'Internal authorization required'}),
          headers: {'content-type': 'application/json'},
        );
      }

      final connection = request.context['shelf.io.connection_info'];
      if (connection is HttpConnectionInfo &&
          connection.remoteAddress.isLoopback) {
        return innerHandler(request);
      }

      if ((request.headers[HttpHeaders.authorizationHeader] ?? '').startsWith(
        'Bearer ',
      )) {
        return jwtMiddleware(accessSecret: jwtAccessSecret)(innerHandler)(
          request,
        );
      }

      return Response.unauthorized(
        jsonEncode({'error': 'Internal authorization required'}),
        headers: {'content-type': 'application/json'},
      );
    };
  };
}
