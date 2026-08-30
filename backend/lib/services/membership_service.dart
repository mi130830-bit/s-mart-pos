import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mysql_client_plus/exception.dart';

import '../db_config.dart';
import 'line_identity_service.dart';

class MembershipException implements Exception {
  const MembershipException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;
}

class MembershipActor {
  const MembershipActor({required this.id, required this.role});
  final String id;
  final String role;
}

class MembershipResult {
  const MembershipResult(this.httpStatus, this.data);
  final int httpStatus;
  final Map<String, dynamic> data;
}

class PairingSecret {
  const PairingSecret({required this.token, required this.hash});
  final String token;
  final String hash;
}

class MembershipSecurity {
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  static String normalizeThaiPhone(String input) {
    var phone = input.replaceAll(RegExp(r'[\s\-().]'), '');
    if (phone.startsWith('+66')) phone = '0${phone.substring(3)}';
    if (phone.startsWith('66') && phone.length >= 10) {
      phone = '0${phone.substring(2)}';
    }
    if (!RegExp(r'^0[0-9]{8,9}$').hasMatch(phone)) {
      throw const MembershipException(
        400,
        'INVALID_PHONE',
        'Invalid Thai phone number',
      );
    }
    return phone;
  }

  static String validateRequestUuid(String input) {
    final value = input.trim();
    if (!RegExp(r'^[A-Za-z0-9._:-]{8,100}$').hasMatch(value)) {
      throw const MembershipException(
        400,
        'INVALID_REQUEST_ID',
        'Invalid request id',
      );
    }
    return value;
  }

  static String validateStrictRequestUuid(String input) {
    final value = input.trim().toLowerCase();
    if (!_uuid.hasMatch(value)) {
      throw const MembershipException(
        400,
        'INVALID_REQUEST_ID',
        'A valid requestUuid UUID is required',
      );
    }
    return value;
  }

  static String validateMemberName(String input) {
    final value = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty ||
        value.length > 255 ||
        value.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
      throw const MembershipException(
        400,
        'INVALID_NAME',
        'Invalid member name',
      );
    }
    return value;
  }

  static String? cleanOptionalText(String input, int maxLength) {
    final value = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return null;
    if (value.length > maxLength ||
        value.contains(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'))) {
      throw const MembershipException(
        400,
        'INVALID_TEXT',
        'Invalid member text field',
      );
    }
    return value;
  }

  static String maskPhone(String? phone) {
    final value = phone?.trim() ?? '';
    if (value.length < 4) return '***';
    return '***-***-${value.substring(value.length - 4)}';
  }

  static String maskMemberCode(String? memberCode) {
    final value = memberCode?.trim() ?? '';
    if (value.length <= 4) return '••••';
    return '••••-${value.substring(value.length - 4)}';
  }

  static String maskName(String? name) {
    final words = (name?.trim() ?? '')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    if (words.isEmpty) return '•••';
    return words
        .map((word) {
          final runes = word.runes.toList();
          if (runes.length <= 1) return '•';
          final first = String.fromCharCode(runes.first);
          final hiddenLength = (runes.length - 1).clamp(1, 4);
          return '$first${List.filled(hiddenLength, '•').join()}';
        })
        .join(' ');
  }

  static bool pairingPreviewAvailable({
    required String status,
    required DateTime? expiresAt,
    required DateTime now,
  }) => status == 'PENDING' && expiresAt != null && expiresAt.isAfter(now);

  static bool quickCreateReplayMatches(
    Map<String, String?> row, {
    required String normalizedPhone,
    required String name,
  }) {
    final customerId = int.tryParse(row['candidate_customer_id'] ?? '');
    return row['request_type'] == 'SELF_SIGNUP' &&
        (row['line_subject']?.isEmpty ?? true) &&
        row['normalized_phone'] == normalizedPhone &&
        row['line_display_name'] == name &&
        customerId != null &&
        customerId > 0;
  }

  static PairingSecret createPairingSecret({Random? random}) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(24, (_) => source.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    return PairingSecret(token: token, hash: hashToken(token));
  }

  static String hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  static bool isExpired(DateTime expiresAt, DateTime now) =>
      !expiresAt.isAfter(now);

  static bool canApproveRole(String role) =>
      {'admin', 'manager', 'owner'}.contains(role.toLowerCase());

  static bool canApproveRequest({
    required String? requestType,
    required String? lineSubject,
  }) => requestType == 'RECOVERY' && (lineSubject?.trim().isNotEmpty ?? false);

  static String newRequestUuid({Random? random}) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => source.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class MembershipService {
  Future<MembershipResult> selfSignup({
    required LineIdentity identity,
    required String phone,
    required String name,
    required String requestUuid,
    String address = '',
    String shippingAddress = '',
  }) async {
    final normalizedPhone = MembershipSecurity.normalizeThaiPhone(phone);
    final requestId = MembershipSecurity.validateRequestUuid(requestUuid);
    final cleanAddress = MembershipSecurity.cleanOptionalText(address, 2000);
    final cleanShippingAddress =
        MembershipSecurity.cleanOptionalText(shippingAddress, 2000) ??
        cleanAddress;
    final conn = await DbConfig().connection;
    await conn.execute('START TRANSACTION');
    try {
      final prior = await conn.execute(
        'SELECT status, line_subject, normalized_phone, candidate_customer_id FROM customer_line_link_request WHERE request_uuid = :uuid LIMIT 1 FOR UPDATE',
        {'uuid': requestId},
      );
      if (prior.rows.isNotEmpty) {
        final row = prior.rows.first.assoc();
        if (row['line_subject'] != identity.subject ||
            row['normalized_phone'] != normalizedPhone) {
          throw const MembershipException(
            409,
            'IDEMPOTENCY_CONFLICT',
            'Request id was reused',
          );
        }
        await conn.execute('COMMIT');
        return _requestReplay(row, requestId);
      }

      final owner = await _owner(conn, identity.subject);
      if (owner != null) {
        final ownedCustomer = await conn.execute(
          'SELECT phone FROM customer WHERE id = :id LIMIT 1 FOR UPDATE',
          {'id': owner},
        );
        final ownedPhone = ownedCustomer.rows.isEmpty
            ? ''
            : _normalizeStoredPhone(ownedCustomer.rows.first.assoc()['phone']);
        if (ownedPhone != normalizedPhone) {
          throw const MembershipException(
            409,
            'LINE_CONFLICT',
            'LINE identity is already linked to another member',
          );
        }
        await conn.execute('COMMIT');
        return MembershipResult(200, {
          'success': true,
          'outcome': 'LINKED',
          'customerId': owner,
          'requestUuid': requestId,
          'existing': true,
        });
      }

      final legacy = await conn.execute(
        'SELECT id, phone FROM customer WHERE TRIM(line_user_id) = :subject AND (isDeleted = 0 OR isDeleted IS NULL) LIMIT 2 FOR UPDATE',
        {'subject': identity.subject},
      );
      if (legacy.rows.length > 1) {
        throw const MembershipException(
          409,
          'LINE_CONFLICT',
          'LINE identity needs admin resolution',
        );
      }
      if (legacy.rows.length == 1) {
        if (_normalizeStoredPhone(legacy.rows.first.assoc()['phone']) !=
            normalizedPhone) {
          throw const MembershipException(
            409,
            'LINE_CONFLICT',
            'LINE identity is already linked to another member',
          );
        }
        final customerId = int.parse(
          legacy.rows.first.assoc()['id'].toString(),
        );
        await _activateOwner(
          conn,
          identity: identity,
          customerId: customerId,
          method: 'SELF_SIGNUP',
          actorType: 'CUSTOMER',
          actorId: identity.subject,
          requestUuid: requestId,
        );
        await conn.execute('COMMIT');
        return MembershipResult(200, {
          'success': true,
          'outcome': 'LINKED',
          'customerId': customerId,
          'requestUuid': requestId,
          'existing': true,
        });
      }

      await _lockPhoneCreation(conn, normalizedPhone);
      // Recheck the idempotency record after waiting on the phone guard. A
      // concurrent self-signup may have completed while this request waited.
      final committedPrior = await conn.execute(
        '''SELECT status, line_subject, normalized_phone,
                  candidate_customer_id
           FROM customer_line_link_request
           WHERE request_uuid = :uuid LIMIT 1 FOR UPDATE''',
        {'uuid': requestId},
      );
      if (committedPrior.rows.isNotEmpty) {
        final row = committedPrior.rows.first.assoc();
        if (row['line_subject'] != identity.subject ||
            row['normalized_phone'] != normalizedPhone) {
          throw const MembershipException(
            409,
            'IDEMPOTENCY_CONFLICT',
            'Request id was reused',
          );
        }
        await conn.execute('COMMIT');
        return _requestReplay(row, requestId);
      }
      final phoneMatches = await conn.execute(
        '''SELECT id FROM customer
           WHERE (
             REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', '') = :phone
             OR CONCAT('0', SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', ''), 4)) = :phone
             OR CONCAT('0', SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', ''), 3)) = :phone
           ) AND (isDeleted = 0 OR isDeleted IS NULL)
           LIMIT 2 FOR UPDATE''',
        {'phone': normalizedPhone},
      );
      if (phoneMatches.rows.isNotEmpty) {
        final candidate = phoneMatches.rows.length == 1
            ? int.parse(phoneMatches.rows.first.assoc()['id'].toString())
            : null;
        if (candidate != null) {
          final candidateOwner = await conn.execute(
            '''SELECT subject FROM customer_identity_owner
               WHERE provider = 'LINE' AND customer_id = :customer
               LIMIT 1 FOR UPDATE''',
            {'customer': candidate},
          );
          final candidateLegacy = await conn.execute(
            '''SELECT line_user_id FROM customer
               WHERE id = :customer LIMIT 1 FOR UPDATE''',
            {'customer': candidate},
          );
          final legacySubject = candidateLegacy.rows.isEmpty
              ? ''
              : (candidateLegacy.rows.first.assoc()['line_user_id']?.trim() ??
                    '');
          if (candidateOwner.rows.isEmpty && legacySubject.isEmpty) {
            await _activateOwner(
              conn,
              identity: identity,
              customerId: candidate,
              method: 'SELF_SIGNUP_PHONE_MATCH',
              actorType: 'CUSTOMER',
              actorId: identity.subject,
              requestUuid: requestId,
            );
            await conn.execute(
              '''UPDATE customer
                 SET line_user_id = :subject,
                     line_display_name = :lineName,
                     line_picture_url = :picture,
                     address = COALESCE(:address, address),
                     shippingAddress = COALESCE(:shippingAddress, shippingAddress)
                 WHERE id = :customer''',
              {
                'subject': identity.subject,
                'lineName': identity.displayName,
                'picture': identity.pictureUrl,
                'address': cleanAddress,
                'shippingAddress': cleanShippingAddress,
                'customer': candidate,
              },
            );
            await conn.execute(
              '''INSERT INTO customer_line_link_request
                 (request_uuid, normalized_phone, candidate_customer_id,
                  line_subject, line_display_name, line_picture_url,
                  request_type, status, decided_at, consumed_at)
                 VALUES (:uuid, :phone, :customer, :subject, :name, :picture,
                         'SELF_SIGNUP_PHONE_MATCH', 'CONSUMED', NOW(), NOW())''',
              {
                'uuid': requestId,
                'phone': normalizedPhone,
                'customer': candidate,
                'subject': identity.subject,
                'name': identity.displayName,
                'picture': identity.pictureUrl,
              },
            );
            await conn.execute('COMMIT');
            return MembershipResult(200, {
              'success': true,
              'outcome': 'LINKED',
              'customerId': candidate,
              'requestUuid': requestId,
              'existing': true,
            });
          }
        }
        await conn.execute(
          '''INSERT INTO customer_line_link_request
             (request_uuid, normalized_phone, candidate_customer_id, line_subject,
              line_display_name, line_picture_url, request_type, status, expires_at)
             VALUES (:uuid, :phone, :candidate, :subject, :name, :picture,
                     'RECOVERY', 'PENDING', DATE_ADD(NOW(), INTERVAL 7 DAY))''',
          {
            'uuid': requestId,
            'phone': normalizedPhone,
            'candidate': candidate,
            'subject': identity.subject,
            'name': identity.displayName,
            'picture': identity.pictureUrl,
          },
        );
        await conn.execute('COMMIT');
        return MembershipResult(202, {
          'success': true,
          'outcome': 'PENDING',
          'requestUuid': requestId,
          'message': 'คำขอถูกส่งให้พนักงานตรวจสอบแล้ว',
        });
      }

      final memberCode = _memberCode();
      final insert = await conn.execute(
        '''INSERT INTO customer
           (memberCode, firstName, phone, line_user_id, line_display_name,
            line_picture_url, address, shippingAddress, currentPoints, isDeleted)
           VALUES (:code, :name, :phone, :subject, :lineName, :picture,
                   :address, :shippingAddress, 0, 0)''',
        {
          'code': memberCode,
          'name': name.trim().isEmpty ? 'ลูกค้าใหม่' : name.trim(),
          'phone': normalizedPhone,
          'subject': identity.subject,
          'lineName': identity.displayName,
          'picture': identity.pictureUrl,
          'address': cleanAddress,
          'shippingAddress': cleanShippingAddress,
        },
      );
      final customerId = insert.lastInsertID.toInt();
      await _activateOwner(
        conn,
        identity: identity,
        customerId: customerId,
        method: 'SELF_SIGNUP',
        actorType: 'CUSTOMER',
        actorId: identity.subject,
        requestUuid: requestId,
      );
      await conn.execute(
        '''INSERT INTO customer_line_link_request
           (request_uuid, normalized_phone, candidate_customer_id, line_subject,
            line_display_name, line_picture_url, request_type, status,
            decided_at, consumed_at)
           VALUES (:uuid, :phone, :customer, :subject, :name, :picture,
                   'SELF_SIGNUP', 'CONSUMED', NOW(), NOW())''',
        {
          'uuid': requestId,
          'phone': normalizedPhone,
          'customer': customerId,
          'subject': identity.subject,
          'name': identity.displayName,
          'picture': identity.pictureUrl,
        },
      );
      await conn.execute('COMMIT');
      return MembershipResult(200, {
        'success': true,
        'outcome': 'CREATED',
        'customerId': customerId,
        'requestUuid': requestId,
        'existing': false,
      });
    } catch (_) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<MembershipResult> createPairing({
    required int customerId,
    required String requestUuid,
    required MembershipActor actor,
  }) async {
    final requestId = MembershipSecurity.validateRequestUuid(requestUuid);
    final secret = MembershipSecurity.createPairingSecret();
    final conn = await DbConfig().connection;
    await conn.execute('START TRANSACTION');
    try {
      final replay = await conn.execute(
        'SELECT status, candidate_customer_id, expires_at FROM customer_line_link_request WHERE request_uuid = :uuid LIMIT 1 FOR UPDATE',
        {'uuid': requestId},
      );
      if (replay.rows.isNotEmpty) {
        final row = replay.rows.first.assoc();
        if (row['candidate_customer_id']?.toString() != customerId.toString()) {
          throw const MembershipException(
            409,
            'IDEMPOTENCY_CONFLICT',
            'Request id was reused',
          );
        }
        await conn.execute('COMMIT');
        return MembershipResult(200, {
          'success': true,
          'outcome': row['status'],
          'requestUuid': requestId,
          'tokenAvailable': false,
        });
      }
      final customer = await conn.execute(
        'SELECT id, line_user_id FROM customer WHERE id = :id AND (isDeleted = 0 OR isDeleted IS NULL) LIMIT 1 FOR UPDATE',
        {'id': customerId},
      );
      if (customer.rows.isEmpty) {
        throw const MembershipException(
          404,
          'CUSTOMER_NOT_FOUND',
          'Customer not found',
        );
      }
      if ((customer.rows.first.assoc()['line_user_id']?.trim() ?? '')
          .isNotEmpty) {
        throw const MembershipException(
          409,
          'CUSTOMER_ALREADY_LINKED',
          'Customer already has LINE',
        );
      }
      final existing = await conn.execute(
        "SELECT subject FROM customer_identity_owner WHERE provider = 'LINE' AND customer_id = :id LIMIT 1 FOR UPDATE",
        {'id': customerId},
      );
      if (existing.rows.isNotEmpty) {
        throw const MembershipException(
          409,
          'CUSTOMER_ALREADY_LINKED',
          'Customer already has LINE',
        );
      }
      await conn.execute(
        '''INSERT INTO customer_line_link_request
           (request_uuid, candidate_customer_id, line_subject, request_type,
            token_hash, status, expires_at, staff_actor_id, staff_actor_role)
           VALUES (:uuid, :customer, '', 'PAIRING', :hash, 'PENDING',
                   DATE_ADD(NOW(), INTERVAL 5 MINUTE), :actor, :role)''',
        {
          'uuid': requestId,
          'customer': customerId,
          'hash': secret.hash,
          'actor': actor.id,
          'role': actor.role,
        },
      );
      await conn.execute('COMMIT');
      return MembershipResult(201, {
        'success': true,
        'outcome': 'PENDING',
        'requestUuid': requestId,
        'pairingToken': secret.token,
        'expiresInSeconds': 300,
      });
    } catch (_) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<MembershipResult> consumePairing({
    required LineIdentity identity,
    required String token,
  }) async {
    if (token.trim().isEmpty || token.length > 256) {
      throw const MembershipException(
        400,
        'INVALID_PAIRING',
        'Invalid pairing token',
      );
    }
    final hash = MembershipSecurity.hashToken(token.trim());
    final conn = await DbConfig().connection;
    await conn.execute('START TRANSACTION');
    try {
      final request = await conn.execute(
        '''SELECT request_uuid, candidate_customer_id, status, expires_at,
                  staff_actor_id
           FROM customer_line_link_request
           WHERE token_hash = :hash AND request_type = 'PAIRING'
           LIMIT 1 FOR UPDATE''',
        {'hash': hash},
      );
      if (request.rows.isEmpty) {
        throw const MembershipException(
          404,
          'PAIRING_NOT_FOUND',
          'Pairing token not found',
        );
      }
      final row = request.rows.first.assoc();
      final requestId = row['request_uuid']!;
      final customerId = int.parse(row['candidate_customer_id']!);
      if (row['status'] == 'CONSUMED') {
        final owner = await _owner(conn, identity.subject);
        if (owner == customerId) {
          await conn.execute('COMMIT');
          return MembershipResult(200, {
            'success': true,
            'outcome': 'LINKED',
            'customerId': customerId,
            'requestUuid': requestId,
            'existing': true,
          });
        }
        throw const MembershipException(
          409,
          'PAIRING_CONSUMED',
          'Pairing token was already used',
        );
      }
      if (row['status'] != 'PENDING') {
        throw const MembershipException(
          409,
          'PAIRING_UNAVAILABLE',
          'Pairing token is unavailable',
        );
      }
      final expiresAt = DateTime.parse(row['expires_at']!);
      if (MembershipSecurity.isExpired(expiresAt, DateTime.now())) {
        await conn.execute(
          "UPDATE customer_line_link_request SET status = 'EXPIRED', decided_at = NOW() WHERE request_uuid = :uuid",
          {'uuid': requestId},
        );
        await conn.execute('COMMIT');
        return const MembershipResult(410, {
          'success': false,
          'code': 'PAIRING_EXPIRED',
          'error': 'Pairing token expired',
        });
      }
      final owner = await _owner(conn, identity.subject);
      if (owner != null && owner != customerId) {
        throw const MembershipException(
          409,
          'LINE_CONFLICT',
          'LINE is linked to another customer',
        );
      }
      final targetOwner = await conn.execute(
        "SELECT subject FROM customer_identity_owner WHERE provider = 'LINE' AND customer_id = :id LIMIT 1 FOR UPDATE",
        {'id': customerId},
      );
      if (targetOwner.rows.isNotEmpty &&
          targetOwner.rows.first.assoc()['subject'] != identity.subject) {
        throw const MembershipException(
          409,
          'CUSTOMER_ALREADY_LINKED',
          'Customer already has another LINE',
        );
      }
      final legacy = await conn.execute(
        'SELECT line_user_id FROM customer WHERE id = :id LIMIT 1 FOR UPDATE',
        {'id': customerId},
      );
      if (legacy.rows.isEmpty) {
        throw const MembershipException(
          404,
          'CUSTOMER_NOT_FOUND',
          'Customer not found',
        );
      }
      final legacySubject =
          legacy.rows.first.assoc()['line_user_id']?.trim() ?? '';
      if (legacySubject.isNotEmpty && legacySubject != identity.subject) {
        throw const MembershipException(
          409,
          'CUSTOMER_ALREADY_LINKED',
          'Customer has another LINE identity',
        );
      }
      if (owner == null) {
        await _activateOwner(
          conn,
          identity: identity,
          customerId: customerId,
          method: 'STAFF_QR',
          actorType: 'STAFF',
          actorId: row['staff_actor_id'] ?? 'unknown',
          requestUuid: requestId,
        );
      }
      await conn.execute(
        '''UPDATE customer SET line_user_id = :subject,
             line_display_name = :name, line_picture_url = :picture
           WHERE id = :id''',
        {
          'subject': identity.subject,
          'name': identity.displayName,
          'picture': identity.pictureUrl,
          'id': customerId,
        },
      );
      await conn.execute(
        '''UPDATE customer_line_link_request SET status = 'CONSUMED',
             consumed_at = NOW(), decided_at = COALESCE(decided_at, NOW()),
             line_subject = :subject, line_display_name = :name,
             line_picture_url = :picture WHERE request_uuid = :uuid''',
        {
          'subject': identity.subject,
          'name': identity.displayName,
          'picture': identity.pictureUrl,
          'uuid': requestId,
        },
      );
      await conn.execute('COMMIT');
      return MembershipResult(200, {
        'success': true,
        'outcome': 'LINKED',
        'customerId': customerId,
        'requestUuid': requestId,
      });
    } catch (_) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<MembershipResult> previewPairing({required String token}) async {
    if (token.trim().isEmpty || token.length > 256) {
      throw const MembershipException(
        400,
        'INVALID_PAIRING',
        'Invalid pairing token',
      );
    }
    final conn = await DbConfig().connection;
    final result = await conn.execute(
      '''SELECT r.status, r.expires_at,
                c.memberCode, c.firstName, c.lastName, c.phone
         FROM customer_line_link_request r
         JOIN customer c ON c.id = r.candidate_customer_id
         WHERE r.token_hash = :hash AND r.request_type = 'PAIRING'
           AND (c.isDeleted = 0 OR c.isDeleted IS NULL)
         LIMIT 1''',
      {'hash': MembershipSecurity.hashToken(token.trim())},
    );
    if (result.rows.isEmpty) {
      throw const MembershipException(
        404,
        'PAIRING_NOT_FOUND',
        'Pairing token not found',
      );
    }
    final row = result.rows.first.assoc();
    final expiresAt = DateTime.tryParse(row['expires_at'] ?? '');
    if (!MembershipSecurity.pairingPreviewAvailable(
      status: row['status'] ?? '',
      expiresAt: expiresAt,
      now: DateTime.now(),
    )) {
      throw const MembershipException(
        410,
        'PAIRING_UNAVAILABLE',
        'Pairing token is expired or unavailable',
      );
    }
    final name = '${row['firstName'] ?? ''} ${row['lastName'] ?? ''}'.trim();
    return MembershipResult(200, {
      'success': true,
      'outcome': 'PREVIEW',
      'customer': {
        'memberCode': MembershipSecurity.maskMemberCode(row['memberCode']),
        'name': MembershipSecurity.maskName(name.isEmpty ? null : name),
        'phoneMasked': MembershipSecurity.maskPhone(row['phone']),
      },
      'expiresAt': expiresAt!.toIso8601String(),
      'explicitConsumeRequired': true,
    });
  }

  Future<List<Map<String, dynamic>>> myRequests(String subject) async {
    final conn = await DbConfig().connection;
    await conn.execute(
      "UPDATE customer_line_link_request SET status = 'EXPIRED' WHERE line_subject = :subject AND status = 'PENDING' AND expires_at < NOW()",
      {'subject': subject},
    );
    final rows = await conn.execute(
      '''SELECT request_uuid, request_type, status, expires_at, created_at,
                decided_at, consumed_at
         FROM customer_line_link_request WHERE line_subject = :subject
         ORDER BY id DESC LIMIT 20''',
      {'subject': subject},
    );
    return rows.rows.map((row) => _dates(row.assoc())).toList();
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final value = query.trim();
    if (value.length < 2 || value.length > 100) {
      throw const MembershipException(
        400,
        'INVALID_SEARCH',
        'Search requires 2 to 100 characters',
      );
    }
    String? normalizedPhone;
    try {
      normalizedPhone = MembershipSecurity.normalizeThaiPhone(value);
    } on MembershipException {
      normalizedPhone = null;
    }
    final conn = await DbConfig().connection;
    final rows = await conn.execute(
      '''SELECT c.id, c.memberCode, c.firstName, c.lastName, c.phone,
                COALESCE(c.currentDebt, 0) AS current_debt,
                EXISTS(
                  SELECT 1 FROM customer_identity_owner o
                  WHERE o.provider = 'LINE' AND o.customer_id = c.id
                ) AS is_linked,
                COALESCE((
                  SELECT SUM(pl.points_earned - pl.points_used)
                  FROM point_ledger pl
                  WHERE pl.customer_id = c.id
                    AND (pl.expires_at IS NULL OR pl.expires_at > NOW())
                ), 0) AS ledger_points
         FROM customer c
         WHERE (c.isDeleted = 0 OR c.isDeleted IS NULL)
           AND (
             LOCATE(:query, COALESCE(c.firstName, '')) > 0
             OR LOCATE(:query, COALESCE(c.lastName, '')) > 0
             OR LOCATE(:query, COALESCE(c.memberCode, '')) > 0
             OR LOCATE(:query, COALESCE(c.phone, '')) > 0
             OR (:phone IS NOT NULL AND (
               REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', '') = :phone
               OR CONCAT('0', SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', ''), 4)) = :phone
               OR CONCAT('0', SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', ''), 3)) = :phone
             ))
           )
         ORDER BY c.id DESC LIMIT 20''',
      {'query': value, 'phone': normalizedPhone},
    );
    return rows.rows.map((row) => _staffCustomer(row.assoc())).toList();
  }

  Future<MembershipResult> quickCreate({
    required String name,
    required String phone,
    required String requestUuid,
    required MembershipActor actor,
    String address = '',
    String shippingAddress = '',
  }) async {
    final memberName = MembershipSecurity.validateMemberName(name);
    final normalizedPhone = MembershipSecurity.normalizeThaiPhone(phone);
    final requestId = MembershipSecurity.validateStrictRequestUuid(requestUuid);
    final cleanAddress = MembershipSecurity.cleanOptionalText(address, 2000);
    final cleanShippingAddress =
        MembershipSecurity.cleanOptionalText(shippingAddress, 2000) ??
        cleanAddress;
    final conn = await DbConfig().connection;
    await conn.execute('START TRANSACTION');
    try {
      final replay = await conn.execute(
        '''SELECT request_type, line_subject, normalized_phone,
                  line_display_name, candidate_customer_id
           FROM customer_line_link_request
           WHERE request_uuid = :uuid LIMIT 1 FOR UPDATE''',
        {'uuid': requestId},
      );
      if (replay.rows.isNotEmpty) {
        final row = replay.rows.first.assoc();
        if (!MembershipSecurity.quickCreateReplayMatches(
          row,
          normalizedPhone: normalizedPhone,
          name: memberName,
        )) {
          throw const MembershipException(
            409,
            'IDEMPOTENCY_CONFLICT',
            'requestUuid was already used',
          );
        }
        await conn.execute('COMMIT');
        return MembershipResult(200, {
          'success': true,
          'outcome': 'CREATED',
          'customerId': int.parse(row['candidate_customer_id']!),
          'requestUuid': requestId,
          'idempotentReplay': true,
        });
      }

      await _lockPhoneCreation(conn, normalizedPhone);
      // A concurrent replay with the same phone may have committed while this
      // transaction waited on the durable phone guard row.
      final committedReplay = await conn.execute(
        '''SELECT request_type, line_subject, normalized_phone,
                  line_display_name, candidate_customer_id
           FROM customer_line_link_request
           WHERE request_uuid = :uuid LIMIT 1 FOR UPDATE''',
        {'uuid': requestId},
      );
      if (committedReplay.rows.isNotEmpty) {
        final row = committedReplay.rows.first.assoc();
        if (!MembershipSecurity.quickCreateReplayMatches(
          row,
          normalizedPhone: normalizedPhone,
          name: memberName,
        )) {
          throw const MembershipException(
            409,
            'IDEMPOTENCY_CONFLICT',
            'requestUuid was already used',
          );
        }
        await conn.execute('COMMIT');
        return MembershipResult(200, {
          'success': true,
          'outcome': 'CREATED',
          'customerId': int.parse(row['candidate_customer_id']!),
          'requestUuid': requestId,
          'idempotentReplay': true,
        });
      }
      final matches = await _phoneMatches(conn, normalizedPhone);
      if (matches.isNotEmpty) {
        await conn.execute('COMMIT');
        return MembershipResult(409, {
          'success': false,
          'code': 'PHONE_MATCHES_EXISTING',
          'error': 'Existing member candidates require staff review',
          'candidates': matches,
        });
      }

      final insert = await conn.execute(
        '''INSERT INTO customer
           (memberCode, firstName, phone, address, shippingAddress,
            currentPoints, isDeleted)
           VALUES (:memberCode, :name, :phone, :address, :shippingAddress,
                   0, 0)''',
        {
          'memberCode': _memberCode(),
          'name': memberName,
          'phone': normalizedPhone,
          'address': cleanAddress,
          'shippingAddress': cleanShippingAddress,
        },
      );
      final customerId = insert.lastInsertID.toInt();
      await conn.execute(
        '''INSERT INTO customer_line_link_request
           (request_uuid, normalized_phone, candidate_customer_id,
            line_subject, line_display_name, request_type, status,
            decided_at, consumed_at, staff_actor_id, staff_actor_role)
           VALUES (:uuid, :phone, :customerId, '', :name, 'SELF_SIGNUP',
                   'CONSUMED', NOW(), NOW(), :actorId, :actorRole)''',
        {
          'uuid': requestId,
          'phone': normalizedPhone,
          'customerId': customerId,
          'name': memberName,
          'actorId': actor.id,
          'actorRole': actor.role,
        },
      );
      await conn.execute('COMMIT');
      return MembershipResult(201, {
        'success': true,
        'outcome': 'CREATED',
        'customerId': customerId,
        'requestUuid': requestId,
        'idempotentReplay': false,
      });
    } catch (error) {
      await conn.execute('ROLLBACK');
      if (error is MySQLServerException && error.errorCode == 1062) {
        final replay = await conn.execute(
          '''SELECT request_type, line_subject, normalized_phone,
                    line_display_name, candidate_customer_id
             FROM customer_line_link_request
             WHERE request_uuid = :uuid LIMIT 1''',
          {'uuid': requestId},
        );
        if (replay.rows.isNotEmpty &&
            MembershipSecurity.quickCreateReplayMatches(
              replay.rows.first.assoc(),
              normalizedPhone: normalizedPhone,
              name: memberName,
            )) {
          return MembershipResult(200, {
            'success': true,
            'outcome': 'CREATED',
            'customerId': int.parse(
              replay.rows.first.assoc()['candidate_customer_id']!,
            ),
            'requestUuid': requestId,
            'idempotentReplay': true,
          });
        }
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listRequests({
    String status = 'PENDING',
  }) async {
    final conn = await DbConfig().connection;
    await conn.execute(
      "UPDATE customer_line_link_request SET status = 'EXPIRED' WHERE status = 'PENDING' AND expires_at < NOW()",
    );
    final rows = await conn.execute(
      '''SELECT r.request_uuid, r.candidate_customer_id, r.normalized_phone,
                r.line_display_name, r.line_picture_url, r.request_type,
                r.status, r.expires_at, r.created_at,
                c.memberCode AS candidate_member_code,
                c.firstName AS candidate_first_name,
                c.lastName AS candidate_last_name,
                c.phone AS candidate_phone,
                COALESCE(c.currentDebt, 0) AS candidate_debt,
                EXISTS(
                  SELECT 1 FROM customer_identity_owner o
                  WHERE o.provider = 'LINE' AND o.customer_id = c.id
                ) AS candidate_is_linked,
                COALESCE((
                  SELECT SUM(pl.points_earned - pl.points_used)
                  FROM point_ledger pl
                  WHERE pl.customer_id = c.id
                    AND (pl.expires_at IS NULL OR pl.expires_at > NOW())
                ), 0) AS candidate_points
         FROM customer_line_link_request r
         LEFT JOIN customer c ON c.id = r.candidate_customer_id
           AND (c.isDeleted = 0 OR c.isDeleted IS NULL)
         WHERE r.status = :status ORDER BY r.id ASC LIMIT 200''',
      {'status': status},
    );
    return rows.rows.map((row) {
      final data = _dates(row.assoc());
      final candidateName = [
        data.remove('candidate_first_name'),
        data.remove('candidate_last_name'),
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      final candidatePhone = data.remove('candidate_phone')?.toString();
      final requestPhone = data.remove('normalized_phone')?.toString();
      final debt =
          double.tryParse(data.remove('candidate_debt')?.toString() ?? '0') ??
          0;
      data['phoneMasked'] = MembershipSecurity.maskPhone(
        candidatePhone ?? requestPhone,
      );
      data['candidateName'] = candidateName;
      data['candidateMemberCode'] = data.remove('candidate_member_code');
      data['candidatePoints'] =
          int.tryParse(data.remove('candidate_points')?.toString() ?? '0') ?? 0;
      data['candidateHasDebt'] = debt > 0;
      data['candidateLinkedStatus'] =
          data.remove('candidate_is_linked')?.toString() == '1'
          ? 'LINKED'
          : 'UNLINKED';
      return data;
    }).toList();
  }

  Future<MembershipResult> approve({
    required String requestUuid,
    required MembershipActor actor,
  }) async {
    if (!MembershipSecurity.canApproveRole(actor.role)) {
      throw const MembershipException(
        403,
        'ELEVATED_ROLE_REQUIRED',
        'Manager approval required',
      );
    }
    final requestId = MembershipSecurity.validateRequestUuid(requestUuid);
    final conn = await DbConfig().connection;
    await conn.execute('START TRANSACTION');
    try {
      final request = await conn.execute(
        '''SELECT candidate_customer_id, line_subject, line_display_name,
                  line_picture_url, status, request_type, expires_at
           FROM customer_line_link_request WHERE request_uuid = :uuid
           LIMIT 1 FOR UPDATE''',
        {'uuid': requestId},
      );
      if (request.rows.isEmpty) {
        throw const MembershipException(
          404,
          'REQUEST_NOT_FOUND',
          'Request not found',
        );
      }
      final row = request.rows.first.assoc();
      if (!MembershipSecurity.canApproveRequest(
        requestType: row['request_type'],
        lineSubject: row['line_subject'],
      )) {
        throw const MembershipException(
          409,
          'REQUEST_NOT_APPROVABLE',
          'Only verified LINE recovery requests can be approved',
        );
      }
      if (row['status'] == 'APPROVED' || row['status'] == 'CONSUMED') {
        await conn.execute('COMMIT');
        return MembershipResult(200, {
          'success': true,
          'outcome': row['status'],
        });
      }
      final expiresAt = row['expires_at'];
      if (expiresAt != null &&
          MembershipSecurity.isExpired(
            DateTime.parse(expiresAt),
            DateTime.now(),
          )) {
        throw const MembershipException(
          410,
          'REQUEST_EXPIRED',
          'Request expired',
        );
      }
      if (row['status'] != 'PENDING' || row['candidate_customer_id'] == null) {
        throw const MembershipException(
          409,
          'REQUEST_UNAVAILABLE',
          'Request cannot be approved',
        );
      }
      final customerId = int.parse(row['candidate_customer_id']!);
      final subject = row['line_subject']!;
      final owner = await _owner(conn, subject);
      if (owner != null && owner != customerId) {
        throw const MembershipException(
          409,
          'TRANSFER_NOT_ALLOWED',
          'LINE transfer is not allowed',
        );
      }
      final target = await conn.execute(
        'SELECT line_user_id FROM customer WHERE id = :id AND (isDeleted = 0 OR isDeleted IS NULL) LIMIT 1 FOR UPDATE',
        {'id': customerId},
      );
      if (target.rows.isEmpty) {
        throw const MembershipException(
          404,
          'CUSTOMER_NOT_FOUND',
          'Customer not found',
        );
      }
      final current = target.rows.first.assoc()['line_user_id']?.trim() ?? '';
      if (current.isNotEmpty && current != subject) {
        throw const MembershipException(
          409,
          'TRANSFER_NOT_ALLOWED',
          'Existing LINE cannot be overwritten',
        );
      }
      if (owner == null) {
        await _activateOwner(
          conn,
          identity: LineIdentity(
            subject: subject,
            displayName: row['line_display_name'],
            pictureUrl: row['line_picture_url'],
          ),
          customerId: customerId,
          method: 'ADMIN_APPROVAL',
          actorType: 'STAFF',
          actorId: actor.id,
          requestUuid: requestId,
        );
      }
      await conn.execute(
        '''UPDATE customer SET line_user_id = :subject,
             line_display_name = :name, line_picture_url = :picture WHERE id = :id''',
        {
          'subject': subject,
          'name': row['line_display_name'],
          'picture': row['line_picture_url'],
          'id': customerId,
        },
      );
      await conn.execute(
        '''UPDATE customer_line_link_request SET status = 'APPROVED',
             decided_at = NOW(), staff_actor_id = :actor,
             staff_actor_role = :role WHERE request_uuid = :uuid''',
        {'actor': actor.id, 'role': actor.role, 'uuid': requestId},
      );
      await conn.execute('COMMIT');
      return MembershipResult(200, {
        'success': true,
        'outcome': 'APPROVED',
        'customerId': customerId,
        'requestUuid': requestId,
      });
    } catch (_) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<MembershipResult> reject({
    required String requestUuid,
    required MembershipActor actor,
    String? reason,
  }) async {
    final requestId = MembershipSecurity.validateRequestUuid(requestUuid);
    final conn = await DbConfig().connection;
    await conn.execute('START TRANSACTION');
    try {
      final request = await conn.execute(
        'SELECT status FROM customer_line_link_request WHERE request_uuid = :uuid LIMIT 1 FOR UPDATE',
        {'uuid': requestId},
      );
      if (request.rows.isEmpty ||
          request.rows.first.assoc()['status'] != 'PENDING') {
        throw const MembershipException(
          409,
          'REQUEST_UNAVAILABLE',
          'Request cannot be rejected',
        );
      }
      await conn.execute(
        '''UPDATE customer_line_link_request SET status = 'REJECTED',
             decided_at = NOW(), staff_actor_id = :actor, staff_actor_role = :role,
             decision_reason = :reason WHERE request_uuid = :uuid''',
        {
          'actor': actor.id,
          'role': actor.role,
          'reason': reason?.trim(),
          'uuid': requestId,
        },
      );
      await conn.execute('COMMIT');
    } catch (_) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
    return MembershipResult(200, {
      'success': true,
      'outcome': 'REJECTED',
      'requestUuid': requestId,
    });
  }

  Future<int?> _owner(dynamic conn, String subject) async {
    final result = await conn.execute(
      "SELECT customer_id FROM customer_identity_owner WHERE provider = 'LINE' AND subject = :subject LIMIT 1 FOR UPDATE",
      {'subject': subject},
    );
    if (result.rows.isEmpty) return null;
    return int.parse(result.rows.first.assoc()['customer_id'].toString());
  }

  Future<void> _lockPhoneCreation(dynamic conn, String normalizedPhone) async {
    // This durable row is the lock target. It serializes all application-level
    // creates for the same phone without changing legacy customer.phone rules.
    await conn.execute(
      '''INSERT IGNORE INTO customer_phone_creation_guard
         (normalized_phone) VALUES (:phone)''',
      {'phone': normalizedPhone},
    );
    await conn.execute(
      '''SELECT normalized_phone FROM customer_phone_creation_guard
         WHERE normalized_phone = :phone LIMIT 1 FOR UPDATE''',
      {'phone': normalizedPhone},
    );
  }

  Future<List<Map<String, dynamic>>> _phoneMatches(
    dynamic conn,
    String normalizedPhone,
  ) async {
    final rows = await conn.execute(
      '''SELECT c.id, c.memberCode, c.firstName, c.lastName, c.phone,
                COALESCE(c.currentDebt, 0) AS current_debt,
                EXISTS(
                  SELECT 1 FROM customer_identity_owner o
                  WHERE o.provider = 'LINE' AND o.customer_id = c.id
                ) AS is_linked,
                COALESCE((
                  SELECT SUM(pl.points_earned - pl.points_used)
                  FROM point_ledger pl
                  WHERE pl.customer_id = c.id
                    AND (pl.expires_at IS NULL OR pl.expires_at > NOW())
                ), 0) AS ledger_points
         FROM customer c
         WHERE (
           REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', '') = :phone
           OR CONCAT('0', SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', ''), 4)) = :phone
           OR CONCAT('0', SUBSTRING(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(c.phone, '-', ''), ' ', ''), '(', ''), ')', ''), '.', ''), 3)) = :phone
         ) AND (c.isDeleted = 0 OR c.isDeleted IS NULL)
         ORDER BY c.id ASC LIMIT 20 FOR UPDATE''',
      {'phone': normalizedPhone},
    );
    return rows.rows.map((row) => _staffCustomer(row.assoc())).toList();
  }

  Map<String, dynamic> _staffCustomer(Map<String, String?> row) {
    final name = [
      row['firstName'],
      row['lastName'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    final normalizedPhone = _normalizeStoredPhone(row['phone']);
    final debt = double.tryParse(row['current_debt'] ?? '0') ?? 0;
    return {
      'id': int.parse(row['id']!),
      'memberCode': row['memberCode'] ?? '',
      'name': name,
      'normalizedPhone': normalizedPhone,
      'phoneMasked': MembershipSecurity.maskPhone(normalizedPhone),
      'linkedStatus': row['is_linked'] == '1' ? 'LINKED' : 'UNLINKED',
      'currentPoints': int.tryParse(row['ledger_points'] ?? '0') ?? 0,
      'hasDebt': debt > 0,
    };
  }

  Future<void> _activateOwner(
    dynamic conn, {
    required LineIdentity identity,
    required int customerId,
    required String method,
    required String actorType,
    required String actorId,
    required String requestUuid,
  }) async {
    final legacyOwners = await conn.execute(
      '''SELECT id FROM customer
         WHERE TRIM(line_user_id) = :subject
           AND (isDeleted = 0 OR isDeleted IS NULL)
         LIMIT 2 FOR UPDATE''',
      {'subject': identity.subject},
    );
    if (legacyOwners.rows.any(
      (row) => row.assoc()['id']?.toString() != customerId.toString(),
    )) {
      throw const MembershipException(
        409,
        'LINE_CONFLICT',
        'LINE identity needs admin resolution',
      );
    }
    final targetOwner = await conn.execute(
      "SELECT subject FROM customer_identity_owner WHERE provider = 'LINE' AND customer_id = :customer LIMIT 1 FOR UPDATE",
      {'customer': customerId},
    );
    if (targetOwner.rows.isNotEmpty &&
        targetOwner.rows.first.assoc()['subject'] != identity.subject) {
      throw const MembershipException(
        409,
        'CUSTOMER_ALREADY_LINKED',
        'Customer already has another LINE',
      );
    }
    await conn.execute(
      "INSERT INTO customer_identity_owner (provider, subject, customer_id) VALUES ('LINE', :subject, :customer)",
      {'subject': identity.subject, 'customer': customerId},
    );
    await conn.execute(
      '''INSERT INTO customer_identity_link
         (provider, subject, customer_id, status, method, actor_type, actor_id,
          request_uuid)
         VALUES ('LINE', :subject, :customer, 'ACTIVE', :method, :actorType,
                 :actorId, :uuid)''',
      {
        'subject': identity.subject,
        'customer': customerId,
        'method': method,
        'actorType': actorType,
        'actorId': actorId,
        'uuid': requestUuid,
      },
    );
  }

  MembershipResult _requestReplay(Map<String, dynamic> row, String requestId) {
    final status = row['status'] ?? 'PENDING';
    return MembershipResult(status == 'PENDING' ? 202 : 200, {
      'success': true,
      'outcome': status,
      'requestUuid': requestId,
      if (row['candidate_customer_id'] != null && status != 'PENDING')
        'customerId': row['candidate_customer_id'],
      'idempotentReplay': true,
    });
  }

  Map<String, dynamic> _dates(Map<String, dynamic> data) {
    data.forEach((key, value) {
      if (value is DateTime) data[key] = value.toIso8601String();
    });
    return data;
  }

  String _normalizeStoredPhone(String? phone) {
    if (phone == null) return '';
    try {
      return MembershipSecurity.normalizeThaiPhone(phone);
    } on MembershipException {
      return '';
    }
  }

  String _memberCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return 'SM-${List.generate(10, (_) => chars[random.nextInt(chars.length)]).join()}';
  }
}
