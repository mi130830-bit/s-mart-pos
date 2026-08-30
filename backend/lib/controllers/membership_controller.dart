import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middlewares/liff_auth_middleware.dart';
import '../services/line_identity_service.dart';
import '../services/membership_service.dart';

class MembershipController {
  MembershipController({MembershipService? service})
    : _service = service ?? MembershipService();

  final MembershipService _service;

  Router get memberRouter {
    final router = Router();
    router.post('/signup', _signup);
    router.post('/pairing/preview', _previewPairing);
    router.post('/pairing/consume', _consumePairing);
    router.get('/requests/me', _myRequests);
    return router;
  }

  Router get staffRouter {
    final router = Router();
    router.get('/customers/search', _searchCustomers);
    router.post('/customers/quick-create', _quickCreate);
    router.post('/customers/<id>/pairing', _createPairing);
    router.get('/requests', _listRequests);
    router.post('/requests/<uuid>/approve', _approve);
    router.post('/requests/<uuid>/reject', _reject);
    return router;
  }

  Future<Response> _signup(Request request) async {
    return _handle(() async {
      final identity = _identity(request);
      final body = _body(await request.readAsString());
      final result = await _service.selfSignup(
        identity: identity,
        phone: body['phone']?.toString() ?? '',
        name: body['name']?.toString() ?? '',
        address: body['address']?.toString() ?? '',
        shippingAddress: body['shippingAddress']?.toString() ?? '',
        requestUuid: body['requestUuid']?.toString() ?? '',
      );
      return _result(result);
    });
  }

  Future<Response> _consumePairing(Request request) async {
    return _handle(() async {
      final body = _body(await request.readAsString());
      final result = await _service.consumePairing(
        identity: _identity(request),
        token: body['token']?.toString() ?? '',
      );
      return _result(result);
    });
  }

  Future<Response> _previewPairing(Request request) async {
    return _handle(() async {
      _identity(request);
      final body = _body(await request.readAsString());
      final result = await _service.previewPairing(
        token: body['token']?.toString() ?? '',
      );
      return _result(result);
    });
  }

  Future<Response> _myRequests(Request request) async {
    return _handle(() async {
      final data = await _service.myRequests(_identity(request).subject);
      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'content-type': 'application/json'},
      );
    });
  }

  Future<Response> _createPairing(Request request, String id) async {
    return _handle(() async {
      final customerId = int.tryParse(id);
      if (customerId == null || customerId <= 0) {
        throw const MembershipException(
          400,
          'INVALID_CUSTOMER',
          'Invalid customer',
        );
      }
      final body = _body(await request.readAsString());
      final result = await _service.createPairing(
        customerId: customerId,
        requestUuid: body['requestUuid']?.toString() ?? '',
        actor: _actor(request),
      );
      return _result(result);
    });
  }

  Future<Response> _searchCustomers(Request request) async {
    return _handle(() async {
      final data = await _service.searchCustomers(
        request.url.queryParameters['q'] ?? '',
      );
      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'content-type': 'application/json'},
      );
    });
  }

  Future<Response> _quickCreate(Request request) async {
    return _handle(() async {
      final body = _body(await request.readAsString());
      final result = await _service.quickCreate(
        name: body['name']?.toString() ?? '',
        phone: body['phone']?.toString() ?? '',
        address: body['address']?.toString() ?? '',
        shippingAddress: body['shippingAddress']?.toString() ?? '',
        requestUuid: body['requestUuid']?.toString() ?? '',
        actor: _actor(request),
      );
      return _result(result);
    });
  }

  Future<Response> _listRequests(Request request) async {
    return _handle(() async {
      final status =
          request.url.queryParameters['status']?.toUpperCase() ?? 'PENDING';
      if (!{
        'PENDING',
        'APPROVED',
        'REJECTED',
        'EXPIRED',
        'CONSUMED',
      }.contains(status)) {
        throw const MembershipException(
          400,
          'INVALID_STATUS',
          'Invalid status',
        );
      }
      final data = await _service.listRequests(status: status);
      return Response.ok(
        jsonEncode({'success': true, 'data': data}),
        headers: {'content-type': 'application/json'},
      );
    });
  }

  Future<Response> _approve(Request request, String uuid) async {
    return _handle(() async {
      final result = await _service.approve(
        requestUuid: uuid,
        actor: _actor(request),
      );
      return _result(result);
    });
  }

  Future<Response> _reject(Request request, String uuid) async {
    return _handle(() async {
      final raw = await request.readAsString();
      final body = raw.trim().isEmpty ? <String, dynamic>{} : _body(raw);
      final result = await _service.reject(
        requestUuid: uuid,
        actor: _actor(request),
        reason: body['reason']?.toString(),
      );
      return _result(result);
    });
  }

  LineIdentity _identity(Request request) {
    final identity = request.context[lineIdentityContextKey];
    if (identity is! LineIdentity) {
      throw const MembershipException(
        401,
        'UNAUTHORIZED',
        'Authentication required',
      );
    }
    return identity;
  }

  MembershipActor _actor(Request request) {
    final user = request.context['user'];
    if (user is! Map) {
      throw const MembershipException(
        401,
        'UNAUTHORIZED',
        'Authentication required',
      );
    }
    return MembershipActor(
      id: user['id']?.toString() ?? user['username']?.toString() ?? 'unknown',
      role: user['role']?.toString() ?? '',
    );
  }

  Map<String, dynamic> _body(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) {
      throw const MembershipException(
        400,
        'INVALID_BODY',
        'Invalid request body',
      );
    }
    return value;
  }

  Future<Response> _handle(Future<Response> Function() action) async {
    try {
      return await action();
    } on MembershipException catch (e) {
      return Response(
        e.statusCode,
        body: jsonEncode({
          'success': false,
          'code': e.code,
          'error': e.message,
        }),
        headers: {'content-type': 'application/json'},
      );
    } on FormatException {
      return Response.badRequest(
        body: jsonEncode({
          'success': false,
          'code': 'INVALID_BODY',
          'error': 'Invalid request body',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (_) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'code': 'MEMBERSHIP_ERROR',
          'error': 'Membership operation failed',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Response _result(MembershipResult result) => Response(
    result.httpStatus,
    body: jsonEncode(result.data),
    headers: {'content-type': 'application/json'},
  );
}
