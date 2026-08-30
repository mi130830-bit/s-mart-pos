import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import '../middlewares/liff_auth_middleware.dart';
import '../services/line_identity_service.dart';
import '../services/membership_service.dart';
import '../services/member_tier_service.dart';
import '../services/reward_redemption_service.dart';
import 'dart:io';

class RewardController {
  final MembershipService _membershipService = MembershipService();
  final MemberTierService _memberTierService = MemberTierService();
  final RewardRedemptionService _redemptionService = RewardRedemptionService();
  Router get publicRouter {
    final router = Router();
    router.get('/', _getRewards);
    return router;
  }

  Router get memberRouter {
    final router = Router();
    router.get('/me', _getCustomer);
    router.post('/link-phone', _linkCustomer);
    router.post('/redeem', _redeemReward);
    router.post('/claim', _claimFreeReward);
    router.get('/my-history', _getMyHistory);
    router.get('/my-coupons', _getMyCoupons);
    return router;
  }

  Router get staffRouter {
    final router = Router();
    router.get('/rewards', _getAdminRewards);
    router.post('/rewards', _createReward);
    router.put('/rewards/<id>', _updateReward);
    router.delete('/rewards/<id>', _deleteReward);
    router.get('/redemptions', _getAdminRedemptions);
    router.patch('/redemptions/<id>/fulfill', _fulfillRedemption);
    router.get('/coupon/<code>', _validateCoupon);
    router.post('/coupon/<code>/use', _useCoupon);
    return router;
  }

  Map<String, dynamic> _safeMap(Map<String, dynamic> data) {
    data.forEach((key, value) {
      if (value is DateTime) {
        data[key] = value.toIso8601String();
      }
    });
    return data;
  }

  // GET /api/v1/rewards
  Future<Response> _getRewards(Request request) async {
    try {
      final conn = await DbConfig().connection;
      // ดึง LINE identity เพื่อเช็คโควตาต่อคน (optional — ไม่ block ถ้าไม่มี)
      int? currentCustomerId;
      final identity = request.context[lineIdentityContextKey];
      if (identity is LineIdentity) {
        final ownerRes = await conn.execute(
          '''SELECT o.customer_id FROM customer_identity_owner o
             JOIN customer c ON c.id = o.customer_id
             WHERE o.provider = 'LINE' AND o.subject = :subject
               AND (c.isDeleted = 0 OR c.isDeleted IS NULL) LIMIT 1''',
          {'subject': identity.subject},
        );
        if (ownerRes.rows.isNotEmpty) {
          currentCustomerId = int.tryParse(
            ownerRes.rows.first.assoc()['customer_id']?.toString() ?? '',
          );
        }
      }

      final sql = '''
        SELECT id, name, description, point_price, stock_quantity, image_url,
               COALESCE(reward_type, 'GIFT') as reward_type,
               COALESCE(discount_value, 0) as discount_value,
               COALESCE(claim_type, 'POINTS_REDEEM') as claim_type,
               COALESCE(claim_limit_per_user, 1) as claim_limit_per_user
        FROM point_reward 
        WHERE is_active = 1 AND stock_quantity > 0
        ORDER BY claim_type ASC, point_price ASC
      ''';
      final result = await conn.execute(sql);
      final List<Map<String, dynamic>> rewards = [];
      for (final row in result.rows) {
        final r = Map<String, dynamic>.from(row.assoc());
        // เช็คโควตาต่อคนสำหรับ FREE_CLAIM
        if (currentCustomerId != null) {
          final limitPerUser = int.tryParse(r['claim_limit_per_user']?.toString() ?? '0') ?? 0;
          if (limitPerUser > 0) {
            final claimedRes = await conn.execute(
              '''SELECT COUNT(*) AS cnt FROM reward_redemption
                 WHERE customer_id = :cid AND reward_id = :rid''',
              {'cid': currentCustomerId, 'rid': r['id']},
            );
            final cnt = int.tryParse(
              claimedRes.rows.first.assoc()['cnt']?.toString() ?? '0',
            ) ?? 0;
            r['user_claimed_count'] = cnt;
            r['is_claim_limit_reached'] = cnt >= limitPerUser;
          } else {
            r['user_claimed_count'] = 0;
            r['is_claim_limit_reached'] = false;
          }
        } else {
          r['user_claimed_count'] = 0;
          r['is_claim_limit_reached'] = false;
        }
        rewards.add(r);
      }
      return Response.ok(
        jsonEncode(rewards),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stdout.writeln('❌ API Error (Get Rewards): $e');
      return _codedError(500, 'REWARDS_FETCH_ERROR', 'Unable to fetch rewards');
    }
  }

  // GET /api/v1/rewards-member/me
  Future<Response> _getCustomer(Request request) async {
    try {
      final identity = request.context[lineIdentityContextKey];
      if (identity is! LineIdentity) {
        return Response.unauthorized('Unauthorized');
      }
      final lineUserId = identity.subject;
      final conn = await DbConfig().connection;
      final sql = '''
        SELECT id, memberCode, firstName, lastName, line_display_name, isDeleted
        FROM customer 
        WHERE TRIM(line_user_id) = :lineUserId 
        AND (isDeleted = 0 OR isDeleted IS NULL)
        LIMIT 1
      ''';
      final result = await conn.execute(sql, {'lineUserId': lineUserId.trim()});
      if (result.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Customer not found'}));
      }
      var customerMap = result.rows.first.assoc();
      String fName = customerMap['firstName']?.toString() ?? '';
      String lName = customerMap['lastName']?.toString() ?? '';
      String lineName = customerMap['line_display_name']?.toString() ?? '';
      String finalName = '$fName $lName'.trim();
      if (finalName.isEmpty) finalName = lineName;
      if (finalName.isEmpty) {
        finalName = 'Member ${customerMap['memberCode']?.toString() ?? ''}';
      }

      // 🟢 CHANGE: Use accurate ledger sum instead of denormalized column
      final pointSql = '''
        SELECT COALESCE(SUM(points_earned - points_used), 0) as total
        FROM point_ledger 
        WHERE customer_id = :cid AND (expires_at IS NULL OR expires_at > NOW())
      ''';
      final pointRes = await conn.execute(pointSql, {'cid': customerMap['id']});
      final currentPoints =
          int.tryParse(pointRes.rows.first.colAt(0)?.toString() ?? '0') ?? 0;

      return Response.ok(
        jsonEncode({
          'id': customerMap['id'],
          'name': finalName,
          'currentPoints': currentPoints,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stdout.writeln('❌ API Error (Get Customer): $e');
      return _codedError(500, 'MEMBER_FETCH_ERROR', 'Unable to fetch member');
    }
  }

  // POST /api/v1/rewards/link-phone
  Future<Response> _linkCustomer(Request request) async {
    final identity = request.context[lineIdentityContextKey];
    if (identity is! LineIdentity) return Response.unauthorized('Unauthorized');
    try {
      final data = jsonDecode(await request.readAsString());
      final requestUuid = data['requestUuid']?.toString().trim();
      final result = await _membershipService.selfSignup(
        identity: identity,
        phone: data['phone']?.toString() ?? '',
        name: data['name']?.toString() ?? '',
        requestUuid: requestUuid == null || requestUuid.isEmpty
            ? MembershipSecurity.newRequestUuid()
            : requestUuid,
      );
      return Response(
        result.httpStatus,
        body: jsonEncode(result.data),
        headers: {'content-type': 'application/json'},
      );
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
    } catch (_) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unable to register member'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // POST /api/v1/rewards/redeem
  Future<Response> _redeemReward(Request request) async {
    final identity = request.context[lineIdentityContextKey];
    if (identity is! LineIdentity) {
      return _codedError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return _codedError(400, 'INVALID_BODY', 'Invalid request body');
      }
      final rewardId = int.tryParse(decoded['rewardId']?.toString() ?? '');
      if (rewardId == null) {
        return _codedError(400, 'INVALID_REWARD', 'Invalid reward');
      }
      final result = await _redemptionService.redeem(
        lineSubject: identity.subject,
        rewardId: rewardId,
        clientRequestId: decoded['clientRequestId']?.toString() ?? '',
      );
      return Response.ok(
        jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } on RewardRedemptionException catch (error) {
      return _codedError(error.statusCode, error.code, error.message);
    } on FormatException {
      return _codedError(400, 'INVALID_BODY', 'Invalid request body');
    } catch (_) {
      return _codedError(500, 'REDEMPTION_ERROR', 'Unable to redeem reward');
    }
  }

  // POST /api/v1/rewards-member/claim
  Future<Response> _claimFreeReward(Request request) async {
    final identity = request.context[lineIdentityContextKey];
    if (identity is! LineIdentity) {
      return _codedError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    try {
      final decoded = jsonDecode(await request.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return _codedError(400, 'INVALID_BODY', 'Invalid request body');
      }
      final rewardId = int.tryParse(decoded['rewardId']?.toString() ?? '');
      if (rewardId == null) {
        return _codedError(400, 'INVALID_REWARD', 'Invalid reward');
      }
      final result = await _redemptionService.claimFreeCoupon(
        lineSubject: identity.subject,
        rewardId: rewardId,
        clientRequestId: decoded['clientRequestId']?.toString() ?? '',
      );
      return Response.ok(
        jsonEncode(result),
        headers: {'content-type': 'application/json'},
      );
    } on RewardRedemptionException catch (error) {
      return _codedError(error.statusCode, error.code, error.message);
    } on FormatException {
      return _codedError(400, 'INVALID_BODY', 'Invalid request body');
    } catch (_) {
      return _codedError(500, 'CLAIM_ERROR', 'Unable to claim coupon');
    }
  }

  Response _codedError(int status, String code, String message) => Response(
    status,
    body: jsonEncode({'success': false, 'code': code, 'error': message}),
    headers: {'content-type': 'application/json'},
  );
  // GET /api/v1/rewards-member/my-history
  Future<Response> _getMyHistory(Request request) async {
    try {
      final identity = request.context[lineIdentityContextKey];
      if (identity is! LineIdentity) {
        return Response.unauthorized('Unauthorized');
      }
      final lineUserId = identity.subject;
      final conn = await DbConfig().connection;
      final custResult = await conn.execute(
        'SELECT id FROM customer WHERE TRIM(line_user_id) = :lineUserId AND (isDeleted = 0 OR isDeleted IS NULL) LIMIT 1',
        {'lineUserId': lineUserId.trim()},
      );
      if (custResult.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Customer not found'}));
      }
      final customerId = custResult.rows.first.assoc()['id'];
      final result = await conn.execute(
        '''
        SELECT rr.id, rr.points_used, rr.redeemed_at,
               COALESCE(rr.status, 'PENDING') as status,
               COALESCE(rr.reward_type, 'GIFT') as reward_type,
               pr.name as reward_name, pr.image_url,
               rc.coupon_code, rc.discount_value, rc.expires_at, rc.used_at,
               COALESCE(rc.status, '') as coupon_status
        FROM reward_redemption rr
        JOIN point_reward pr ON rr.reward_id = pr.id
        LEFT JOIN reward_coupon rc ON rc.redemption_id = rr.id
        WHERE rr.customer_id = :cid
        ORDER BY rr.redeemed_at DESC LIMIT 30
      ''',
        {'cid': customerId},
      );
      final history = result.rows.map((row) => _safeMap(row.assoc())).toList();
      return Response.ok(
        jsonEncode(history),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('Member reward history fetch failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unable to load reward history'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // GET /api/v1/rewards-member/my-coupons
  Future<Response> _getMyCoupons(Request request) async {
    try {
      final identity = request.context[lineIdentityContextKey];
      if (identity is! LineIdentity) {
        return Response.unauthorized(
          jsonEncode({'error': 'Authentication required'}),
          headers: {'content-type': 'application/json'},
        );
      }
      final conn = await DbConfig().connection;
      final customerId = await _memberTierService.resolveCustomerId(
        conn,
        identity.subject,
      );
      if (customerId == null) {
        return Response.notFound(jsonEncode({'error': 'Member not found'}));
      }
      await conn.execute(
        '''UPDATE reward_coupon
           SET status = CASE WHEN expires_at > NOW() THEN 'ACTIVE' ELSE 'EXPIRED' END,
               reserved_online_order_id = NULL, reserved_until = NULL
           WHERE customer_id = :cid AND status = 'RESERVED'
             AND (reserved_until IS NULL OR reserved_until <= NOW())''',
        {'cid': customerId},
      );
      await conn.execute(
        "UPDATE reward_coupon SET status = 'EXPIRED' WHERE customer_id = :cid AND expires_at < NOW() AND status = 'ACTIVE'",
        {'cid': customerId},
      );
      final result = await conn.execute(
        '''
        SELECT rc.id, rc.coupon_code, rc.discount_value, rc.expires_at,
               rc.status, rc.used_at, rc.reserved_until,
               pr.name as reward_name
        FROM reward_coupon rc
        JOIN point_reward pr ON rc.reward_id = pr.id
        WHERE rc.customer_id = :cid
        ORDER BY rc.expires_at ASC
      ''',
        {'cid': customerId},
      );
      final coupons = result.rows.map((row) => _safeMap(row.assoc())).toList();
      return Response.ok(
        jsonEncode(coupons),
        headers: {'content-type': 'application/json'},
      );
    } catch (error) {
      stderr.writeln('Member coupon fetch failed: $error');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unable to load member coupons'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // GET /api/v1/rewards/admin/redemptions
  Future<Response> _getAdminRedemptions(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final result = await conn.execute('''
        SELECT rr.id, rr.points_used, rr.redeemed_at,
               COALESCE(rr.status, 'PENDING') as status,
               COALESCE(rr.reward_type, 'GIFT') as reward_type,
               pr.name as reward_name, pr.image_url,
               c.firstName, c.lastName, c.phone,
               rc.coupon_code, rc.discount_value, rc.used_at, COALESCE(rc.status,'') as coupon_status
        FROM reward_redemption rr
        JOIN point_reward pr ON rr.reward_id = pr.id
        JOIN customer c ON rr.customer_id = c.id
        LEFT JOIN reward_coupon rc ON rc.redemption_id = rr.id
        ORDER BY rr.redeemed_at DESC LIMIT 200
      ''');
      final list = result.rows.map((row) => _safeMap(row.assoc())).toList();
      return Response.ok(
        jsonEncode(list),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('Admin redemption fetch failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unable to load redemptions'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // PATCH /api/v1/rewards/admin/redemptions/:id/fulfill
  Future<Response> _fulfillRedemption(Request request, String id) async {
    try {
      final conn = await DbConfig().connection;
      await conn.execute(
        "UPDATE reward_redemption SET status = 'FULFILLED' WHERE id = :id",
        {'id': id},
      );
      stdout.writeln('✅ Admin fulfilled redemption #$id');
      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      stderr.writeln('Redemption fulfillment failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unable to fulfill redemption'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // GET /api/v1/rewards/coupon/:code
  Future<Response> _validateCoupon(Request request, String code) async {
    try {
      final conn = await DbConfig().connection;
      await conn.execute(
        "UPDATE reward_coupon SET status = 'EXPIRED' WHERE expires_at < NOW() AND status = 'ACTIVE'",
      );
      final result = await conn.execute(
        '''
        SELECT rc.id, rc.coupon_code, rc.discount_value, rc.expires_at, rc.status,
               pr.name as reward_name,
               c.firstName, c.lastName, c.phone
        FROM reward_coupon rc
        JOIN point_reward pr ON rc.reward_id = pr.id
        JOIN customer c ON rc.customer_id = c.id
        WHERE rc.coupon_code = :code LIMIT 1
      ''',
        {'code': code.toUpperCase()},
      );
      if (result.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'ไม่พบรหัสคูปองนี้'}));
      }
      return Response.ok(
        jsonEncode(_safeMap(result.rows.first.assoc())),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('Coupon validation failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unable to validate coupon'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // POST /api/v1/rewards/coupon/:code/use
  Future<Response> _useCoupon(Request request, String code) async {
    try {
      final conn = await DbConfig().connection;
      final res = await conn.execute(
        "UPDATE reward_coupon SET status = 'USED', used_at = NOW() WHERE coupon_code = :code AND status = 'ACTIVE'",
        {'code': code.toUpperCase()},
      );
      if (res.affectedRows == BigInt.zero) {
        return Response.badRequest(
          body: jsonEncode({
            'error': 'คูปองไม่สามารถใช้งานได้ (อาจถูกใช้ไปแล้ว หรือหมดอายุ)',
          }),
        );
      }
      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      stderr.writeln('Coupon use failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unable to use coupon'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // GET /api/v1/rewards-admin/rewards
  Future<Response> _getAdminRewards(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final sql = '''
        SELECT id, name, description, point_price, stock_quantity, image_url,
               COALESCE(reward_type, 'GIFT') as reward_type,
               COALESCE(discount_value, 0) as discount_value,
               COALESCE(claim_type, 'POINTS_REDEEM') as claim_type,
               COALESCE(claim_limit_per_user, 1) as claim_limit_per_user,
               COALESCE(is_active, 1) as is_active
        FROM point_reward 
        ORDER BY is_active DESC, claim_type ASC, point_price ASC
      ''';
      final result = await conn.execute(sql);
      final list = result.rows.map((row) => _safeMap(row.assoc())).toList();
      return Response.ok(
        jsonEncode(list),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('Admin reward fetch failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Unable to load rewards'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // POST /api/v1/rewards-admin/rewards
  Future<Response> _createReward(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final name = body['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'กรุณาระบุชื่อของรางวัล/คูปอง'}),
          headers: {'content-type': 'application/json'},
        );
      }
      final desc = body['description']?.toString().trim() ?? '';
      final pointPrice = int.tryParse(body['point_price']?.toString() ?? '0') ?? 0;
      final stock = int.tryParse(body['stock_quantity']?.toString() ?? '0') ?? 0;
      final imageUrl = body['image_url']?.toString().trim() ?? '';
      final rewardType = body['reward_type']?.toString().trim() ?? 'GIFT';
      final discountValue = double.tryParse(body['discount_value']?.toString() ?? '0') ?? 0.0;
      final claimType = body['claim_type']?.toString().trim() ?? 'POINTS_REDEEM';
      final claimLimitPerUser = int.tryParse(body['claim_limit_per_user']?.toString() ?? '1') ?? 1;
      final isActive = body['is_active'] == true || body['is_active'] == 1 || body['is_active'] == '1' ? 1 : 0;

      final conn = await DbConfig().connection;
      final sql = '''
        INSERT INTO point_reward
        (name, description, point_price, stock_quantity, image_url, reward_type, discount_value, claim_type, claim_limit_per_user, is_active)
        VALUES
        (:name, :desc, :pointPrice, :stock, :imageUrl, :rewardType, :discountVal, :claimType, :claimLimit, :isActive)
      ''';
      final res = await conn.execute(sql, {
        'name': name,
        'desc': desc,
        'pointPrice': pointPrice,
        'stock': stock,
        'imageUrl': imageUrl,
        'rewardType': rewardType,
        'discountVal': discountValue,
        'claimType': claimType,
        'claimLimit': claimLimitPerUser,
        'isActive': isActive,
      });

      return Response.ok(
        jsonEncode({
          'success': true,
          'id': res.lastInsertID.toInt(),
          'message': 'สร้างรางวัลสำเร็จ',
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('Create reward failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'ไม่สามารถสร้างรางวัลได้: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // PUT /api/v1/rewards-admin/rewards/<id>
  Future<Response> _updateReward(Request request, String id) async {
    try {
      final rewardId = int.tryParse(id);
      if (rewardId == null) {
        return Response.badRequest(body: jsonEncode({'error': 'รหัสรางวัลไม่ถูกต้อง'}));
      }
      final body = jsonDecode(await request.readAsString());
      final name = body['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'กรุณาระบุชื่อของรางวัล/คูปอง'}),
          headers: {'content-type': 'application/json'},
        );
      }
      final desc = body['description']?.toString().trim() ?? '';
      final pointPrice = int.tryParse(body['point_price']?.toString() ?? '0') ?? 0;
      final stock = int.tryParse(body['stock_quantity']?.toString() ?? '0') ?? 0;
      final imageUrl = body['image_url']?.toString().trim() ?? '';
      final rewardType = body['reward_type']?.toString().trim() ?? 'GIFT';
      final discountValue = double.tryParse(body['discount_value']?.toString() ?? '0') ?? 0.0;
      final claimType = body['claim_type']?.toString().trim() ?? 'POINTS_REDEEM';
      final claimLimitPerUser = int.tryParse(body['claim_limit_per_user']?.toString() ?? '1') ?? 1;
      final isActive = body['is_active'] == true || body['is_active'] == 1 || body['is_active'] == '1' ? 1 : 0;

      final conn = await DbConfig().connection;
      final sql = '''
        UPDATE point_reward
        SET name = :name, description = :desc, point_price = :pointPrice,
            stock_quantity = :stock, image_url = :imageUrl, reward_type = :rewardType,
            discount_value = :discountVal, claim_type = :claimType,
            claim_limit_per_user = :claimLimit, is_active = :isActive
        WHERE id = :id
      ''';
      await conn.execute(sql, {
        'id': rewardId,
        'name': name,
        'desc': desc,
        'pointPrice': pointPrice,
        'stock': stock,
        'imageUrl': imageUrl,
        'rewardType': rewardType,
        'discountVal': discountValue,
        'claimType': claimType,
        'claimLimit': claimLimitPerUser,
        'isActive': isActive,
      });

      return Response.ok(
        jsonEncode({'success': true, 'message': 'อัปเดตรางวัลสำเร็จ'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('Update reward failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'ไม่สามารถแก้ไขรางวัลได้: $e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  // DELETE /api/v1/rewards-admin/rewards/<id>
  Future<Response> _deleteReward(Request request, String id) async {
    try {
      final rewardId = int.tryParse(id);
      if (rewardId == null) {
        return Response.badRequest(body: jsonEncode({'error': 'รหัสรางวัลไม่ถูกต้อง'}));
      }
      final conn = await DbConfig().connection;
      await conn.execute(
        "UPDATE point_reward SET is_active = 0 WHERE id = :id",
        {'id': rewardId},
      );
      return Response.ok(
        jsonEncode({'success': true, 'message': 'ปิดใช้งานรางวัลสำเร็จ'}),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stderr.writeln('Delete reward failed: $e');
      return Response.internalServerError(
        body: jsonEncode({'error': 'ไม่สามารถลบรางวัลได้'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
