import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/member_tier_service.dart';

class TierSettingsController {
  TierSettingsController({MemberTierService? service})
    : _service = service ?? MemberTierService();

  final MemberTierService _service;

  Router get router {
    final router = Router();
    router.get('/', _get);
    router.put('/', _put);
    return router;
  }

  Future<Response> _get(Request request) async {
    try {
      final settings = await _service.getSettings();
      return _json(200, {'status': 'success', 'data': settings});
    } catch (error) {
      stderr.writeln('Tier settings read failed: $error');
      return _json(500, {
        'status': 'error',
        'code': 'TIER_SETTINGS_UNAVAILABLE',
        'message': 'Tier settings are unavailable',
      });
    }
  }

  Future<Response> _put(Request request) async {
    final user = request.context['user'];
    final role = user is Map ? user['role']?.toString().toLowerCase() : null;
    if (!{'admin', 'manager', 'owner'}.contains(role)) {
      return _json(403, {
        'status': 'error',
        'code': 'INSUFFICIENT_ROLE',
        'message': 'Insufficient role',
      });
    }
    final actorId = user is Map ? user['id']?.toString().trim() : null;
    if (actorId == null || actorId.isEmpty) {
      return _json(401, {
        'status': 'error',
        'code': 'AUTH_REQUIRED',
        'message': 'Authentication required',
      });
    }

    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const MemberTierValidationException(
          'INVALID_TIER_SETTINGS',
          'Invalid tier settings',
        );
      }
      final update = MemberTierRules.validateSettingsUpdate(decoded);
      final settings = await _service.updateSettings(
        update: update,
        actorId: actorId,
      );
      return _json(200, {'status': 'success', 'data': settings});
    } on MemberTierValidationException catch (error) {
      return _json(400, {
        'status': 'error',
        'code': error.code,
        'message': error.message,
      });
    } on TierSettingsConflictException {
      return _json(409, {
        'status': 'error',
        'code': 'SETTINGS_VERSION_CONFLICT',
        'message': 'Tier settings changed; reload and try again',
      });
    } on FormatException {
      return _json(400, {
        'status': 'error',
        'code': 'INVALID_TIER_SETTINGS',
        'message': 'Invalid tier settings',
      });
    } catch (error) {
      stderr.writeln('Tier settings update failed: $error');
      return _json(500, {
        'status': 'error',
        'code': 'TIER_SETTINGS_UPDATE_FAILED',
        'message': 'Unable to update tier settings',
      });
    }
  }

  Response _json(int statusCode, Map<String, dynamic> body) => Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
