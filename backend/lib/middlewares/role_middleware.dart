import 'dart:convert';

import 'package:shelf/shelf.dart';

Middleware requireRoles(Set<String> allowedRoles) {
  final normalized = allowedRoles.map((role) => role.toLowerCase()).toSet();
  return (Handler innerHandler) {
    return (Request request) {
      final user = request.context['user'];
      final role = user is Map ? user['role']?.toString().toLowerCase() : null;
      if (role == null || !normalized.contains(role)) {
        return Response.forbidden(
          jsonEncode({'error': 'Insufficient role'}),
          headers: {'content-type': 'application/json'},
        );
      }
      return innerHandler(request);
    };
  };
}
