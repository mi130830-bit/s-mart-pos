import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db_config.dart';
import 'dart:io';

class RewardController {
  Router get router {
    final router = Router();
    router.get('/', _getRewards);
    router.get('/customer/<lineUserId>', _getCustomer);
    router.post('/link-phone', _linkCustomer);
    router.post('/redeem', _redeemReward);
    // Phase 2: History & Coupon
    router.get('/my-history/<lineUserId>', _getMyHistory);
    router.get('/my-coupons/<lineUserId>', _getMyCoupons);
    router.get('/admin/redemptions', _getAdminRedemptions);
    router.patch('/admin/redemptions/<id>/fulfill', _fulfillRedemption);
    router.get('/coupon/<code>', _validateCoupon);
    router.post('/coupon/<code>/use', _useCoupon);
    return router;
  }

  // GET /api/v1/rewards
  Future<Response> _getRewards(Request request) async {
    try {
      final conn = await DbConfig().connection;
      final sql = '''
        SELECT id, name, description, point_price, stock_quantity, image_url,
               COALESCE(reward_type, 'GIFT') as reward_type,
               COALESCE(discount_value, 0) as discount_value
        FROM point_reward 
        WHERE is_active = 1 AND stock_quantity > 0
        ORDER BY point_price ASC
      ''';
      final result = await conn.execute(sql);
      final List<Map<String, dynamic>> rewards = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(rewards), headers: {'content-type': 'application/json'});
    } catch (e) {
      stdout.writeln('❌ API Error (Get Rewards): $e');
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to fetch rewards: $e'}));
    }
  }

  // GET /api/v1/rewards/customer/:lineUserId
  Future<Response> _getCustomer(Request request, String lineUserId) async {
    try {
      stdout.writeln('🔍 RewardAPI: Searching for Customer with LineUID: "$lineUserId"');
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
        stdout.writeln('⚠️ RewardAPI: No customer found for "$lineUserId"');
        return Response.notFound(jsonEncode({'error': 'Customer not found'}));
      }
      var customerMap = result.rows.first.assoc();
      String fName = customerMap['firstName']?.toString() ?? '';
      String lName = customerMap['lastName']?.toString() ?? '';
      String lineName = customerMap['line_display_name']?.toString() ?? '';
      String finalName = '$fName $lName'.trim();
      if (finalName.isEmpty) finalName = lineName;
      if (finalName.isEmpty) finalName = 'Member ${customerMap['memberCode']?.toString() ?? ''}';

      // 🟢 CHANGE: Use accurate ledger sum instead of denormalized column
      final pointSql = '''
        SELECT COALESCE(SUM(points_earned - points_used), 0) as total
        FROM point_ledger 
        WHERE customer_id = :cid AND (expires_at IS NULL OR expires_at > NOW())
      ''';
      final pointRes = await conn.execute(pointSql, {'cid': customerMap['id']});
      final currentPoints = int.tryParse(pointRes.rows.first.colAt(0)?.toString() ?? '0') ?? 0;

      return Response.ok(
        jsonEncode({
          'id': customerMap['id'], 
          'name': finalName, 
          'currentPoints': currentPoints
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      stdout.writeln('❌ API Error (Get Customer): $e');
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to fetch customer: $e'}));
    }
  }

  // POST /api/v1/rewards/link-phone
  Future<Response> _linkCustomer(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final String? phone = data['phone']?.toString().replaceAll(' ', '');
      final String? name = data['name']?.toString().trim();
      final String? lineUserId = data['lineUserId']?.toString();
      final String? lineDisplayName = data['lineDisplayName']?.toString();
      final String? linePictureUrl = data['linePictureUrl']?.toString();

      if (phone == null || lineUserId == null || phone.isEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'Phone and Line ID are required'}));
      }
      final conn = await DbConfig().connection;
      final checkLine = await conn.execute('SELECT id FROM customer WHERE TRIM(line_user_id) = :lineId AND (isDeleted = 0 OR isDeleted IS NULL)', {'lineId': lineUserId.trim()});
      if (checkLine.rows.isNotEmpty) {
        return Response.badRequest(body: jsonEncode({'error': 'บัญชี LINE นี้ถูกเชื่อมต่อกับสมาชิกท่านอื่นแล้ว'}));
      }
      final checkPhone = await conn.execute('SELECT id FROM customer WHERE phone = :phone AND (isDeleted = 0 OR isDeleted IS NULL) LIMIT 1', {'phone': phone});
      if (checkPhone.rows.isNotEmpty) {
        final customerId = checkPhone.rows.first.assoc()['id'];
        await conn.execute('UPDATE customer SET line_user_id = :lineId, line_display_name = :lineName, line_picture_url = :linePic WHERE id = :id',
            {'lineId': lineUserId, 'lineName': lineDisplayName, 'linePic': linePictureUrl, 'id': customerId});
        stdout.writeln('🔗 RewardAPI: Linked Phone $phone to existing customer ID $customerId');
        return Response.ok(jsonEncode({'success': true, 'message': 'เชื่อมต่อสมาชิกเสร็จเรียบร้อย'}));
      } else {
        final firstName = (name != null && name.isNotEmpty) ? name : 'ลูกค้าใหม่';
        await conn.execute(
          'INSERT INTO customer (memberCode, firstName, phone, line_user_id, line_display_name, line_picture_url, currentPoints, isDeleted) VALUES (:code, :fname, :phone, :lineId, :lineName, :linePic, 0, 0)',
          {'code': phone, 'fname': firstName, 'phone': phone, 'lineId': lineUserId, 'lineName': lineDisplayName, 'linePic': linePictureUrl}
        );
        stdout.writeln('🆕 RewardAPI: Registered new customer with Phone $phone');
        return Response.ok(jsonEncode({'success': true, 'message': 'สมัครสมาชิกใหม่เรียบร้อย'}));
      }
    } catch (e) {
      stdout.writeln('❌ API Error (Link Phone): $e');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
    }
  }

  // POST /api/v1/rewards/redeem
  Future<Response> _redeemReward(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final String? lineUserId = data['lineUserId']?.toString();
      final int? rewardId = int.tryParse(data['rewardId']?.toString() ?? '');
      if (lineUserId == null || rewardId == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Missing parameters'}));
      }
      final conn = await DbConfig().connection;
      await conn.execute('START TRANSACTION');
      try {
        final custResult = await conn.execute(
          'SELECT id FROM customer WHERE TRIM(line_user_id) = :lineUserId AND (isDeleted = 0 OR isDeleted IS NULL) FOR UPDATE',
          {'lineUserId': lineUserId.trim()}
        );
        if (custResult.rows.isEmpty) throw Exception('Customer not found');
        final customerId = int.parse(custResult.rows.first.assoc()['id'].toString());

        // 🟢 CHANGE: Calculate current points from ledger for 100% accuracy
        final pointSql = '''
          SELECT COALESCE(SUM(points_earned - points_used), 0) as total
          FROM point_ledger 
          WHERE customer_id = :cid AND (expires_at IS NULL OR expires_at > NOW())
          FOR UPDATE
        ''';
        final pointRes = await conn.execute(pointSql, {'cid': customerId});
        final currentPoints = int.tryParse(pointRes.rows.first.colAt(0)?.toString() ?? '0') ?? 0;

        final rewardResult = await conn.execute(
          '''SELECT point_price, stock_quantity, name,
                    COALESCE(reward_type, 'GIFT') as reward_type,
                    COALESCE(discount_value, 0) as discount_value,
                    COALESCE(coupon_expiry_days, 30) as coupon_expiry_days
             FROM point_reward WHERE id = :rewardId AND is_active = 1 FOR UPDATE''',
          {'rewardId': rewardId}
        );
        if (rewardResult.rows.isEmpty) throw Exception('Reward not found or deactivated');

        final rewardData = rewardResult.rows.first.assoc();
        final pointPrice = int.parse(rewardData['point_price'].toString());
        final stockQuantity = int.parse(rewardData['stock_quantity'].toString());
        final rewardType = rewardData['reward_type']?.toString() ?? 'GIFT';
        final rewardName = rewardData['name']?.toString() ?? 'รางวัล';
        final discountValue = double.tryParse(rewardData['discount_value'].toString()) ?? 0;
        final expiryDays = int.tryParse(rewardData['coupon_expiry_days'].toString()) ?? 30;

        if (currentPoints < pointPrice) throw Exception('Insufficient points (มี $currentPoints แต้ม ใช้ $pointPrice แต้ม)');
        if (stockQuantity <= 0) throw Exception('Out of stock');

        final newPoints = currentPoints - pointPrice;
        
        // 🟢 Update Legacy Column
        await conn.execute('UPDATE customer SET currentPoints = :points WHERE id = :id', {'points': newPoints, 'id': customerId});
        
        // 🟢 Update Ledger (Insert Deduction)
        await conn.execute(
          '''INSERT INTO point_ledger (customer_id, points_earned, points_used, description, expires_at) 
             VALUES (:cid, 0, :used, :desc, NULL)''',
          {'cid': customerId, 'used': pointPrice, 'desc': 'Redeem: $rewardName'}
        );
        
        await conn.execute('UPDATE point_reward SET stock_quantity = :stock WHERE id = :id', {'stock': stockQuantity - 1, 'id': rewardId});

        final redemptionResult = await conn.execute(
          "INSERT INTO reward_redemption (customer_id, reward_id, points_used, status, reward_type) VALUES (:cid, :rid, :pts, 'PENDING', :rtype)",
          {'cid': customerId, 'rid': rewardId, 'pts': pointPrice, 'rtype': rewardType}
        );
        final redemptionId = redemptionResult.lastInsertID.toInt();

        String? couponCode;
        if (rewardType == 'COUPON' && discountValue > 0) {
          couponCode = _generateCouponCode();
          final expiresAt = DateTime.now().add(Duration(days: expiryDays));
          final expiresAtStr = expiresAt.toIso8601String().substring(0, 19).replaceAll('T', ' ');
          await conn.execute(
            "INSERT INTO reward_coupon (coupon_code, customer_id, reward_id, redemption_id, discount_value, expires_at, status) VALUES (:code, :cid, :rid, :rdid, :dv, :exp, 'ACTIVE')",
            {'code': couponCode, 'cid': customerId, 'rid': rewardId, 'rdid': redemptionId, 'dv': discountValue, 'exp': expiresAtStr}
          );
          stdout.writeln('🎟️ Generated Coupon: $couponCode for Customer $customerId');
        }

        await conn.execute('COMMIT');
        stdout.writeln('✅ Customer $customerId redeemed Reward $rewardId (type: $rewardType)');
        return Response.ok(
          jsonEncode({'success': true, 'remainingPoints': newPoints, 'rewardType': rewardType, 'couponCode': couponCode, 'discountValue': discountValue}),
          headers: {'content-type': 'application/json'},
        );
      } catch (txError) {
        await conn.execute('ROLLBACK');
        stdout.writeln('⚠️ Redemption Transaction Failed: $txError');
        return Response.badRequest(body: jsonEncode({'error': txError.toString().replaceAll('Exception: ', '')}));
      }
    } catch (e) {
      stdout.writeln('❌ API Error (Redeem): $e');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
    }
  }

  // GET /api/v1/rewards/my-history/:lineUserId
  Future<Response> _getMyHistory(Request request, String lineUserId) async {
    try {
      final conn = await DbConfig().connection;
      final custResult = await conn.execute('SELECT id FROM customer WHERE TRIM(line_user_id) = :lineUserId AND (isDeleted = 0 OR isDeleted IS NULL) LIMIT 1', {'lineUserId': lineUserId.trim()});
      if (custResult.rows.isEmpty) return Response.notFound(jsonEncode({'error': 'Customer not found'}));
      final customerId = custResult.rows.first.assoc()['id'];
      final result = await conn.execute('''
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
      ''', {'cid': customerId});
      final history = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(history), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
    }
  }

  // GET /api/v1/rewards/my-coupons/:lineUserId
  Future<Response> _getMyCoupons(Request request, String lineUserId) async {
    try {
      final conn = await DbConfig().connection;
      final custResult = await conn.execute('SELECT id FROM customer WHERE TRIM(line_user_id) = :lineUserId AND (isDeleted = 0 OR isDeleted IS NULL) LIMIT 1', {'lineUserId': lineUserId.trim()});
      if (custResult.rows.isEmpty) return Response.notFound(jsonEncode({'error': 'Customer not found'}));
      final customerId = custResult.rows.first.assoc()['id'];
      await conn.execute("UPDATE reward_coupon SET status = 'EXPIRED' WHERE customer_id = :cid AND expires_at < NOW() AND status = 'ACTIVE'", {'cid': customerId});
      final result = await conn.execute('''
        SELECT rc.id, rc.coupon_code, rc.discount_value, rc.expires_at, rc.status, rc.used_at,
               pr.name as reward_name
        FROM reward_coupon rc
        JOIN point_reward pr ON rc.reward_id = pr.id
        WHERE rc.customer_id = :cid
        ORDER BY rc.expires_at ASC
      ''', {'cid': customerId});
      final coupons = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(coupons), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
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
      final list = result.rows.map((row) => row.assoc()).toList();
      return Response.ok(jsonEncode(list), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
    }
  }

  // PATCH /api/v1/rewards/admin/redemptions/:id/fulfill
  Future<Response> _fulfillRedemption(Request request, String id) async {
    try {
      final conn = await DbConfig().connection;
      await conn.execute("UPDATE reward_redemption SET status = 'FULFILLED' WHERE id = :id", {'id': id});
      stdout.writeln('✅ Admin fulfilled redemption #$id');
      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
    }
  }

  // GET /api/v1/rewards/coupon/:code
  Future<Response> _validateCoupon(Request request, String code) async {
    try {
      final conn = await DbConfig().connection;
      await conn.execute("UPDATE reward_coupon SET status = 'EXPIRED' WHERE expires_at < NOW() AND status = 'ACTIVE'");
      final result = await conn.execute('''
        SELECT rc.id, rc.coupon_code, rc.discount_value, rc.expires_at, rc.status,
               pr.name as reward_name,
               c.firstName, c.lastName, c.phone
        FROM reward_coupon rc
        JOIN point_reward pr ON rc.reward_id = pr.id
        JOIN customer c ON rc.customer_id = c.id
        WHERE rc.coupon_code = :code LIMIT 1
      ''', {'code': code.toUpperCase()});
      if (result.rows.isEmpty) return Response.notFound(jsonEncode({'error': 'ไม่พบรหัสคูปองนี้'}));
      return Response.ok(jsonEncode(result.rows.first.assoc()), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
    }
  }

  // POST /api/v1/rewards/coupon/:code/use
  Future<Response> _useCoupon(Request request, String code) async {
    try {
      final conn = await DbConfig().connection;
      final res = await conn.execute("UPDATE reward_coupon SET status = 'USED', used_at = NOW() WHERE coupon_code = :code AND status = 'ACTIVE'", {'code': code.toUpperCase()});
      if (res.affectedRows == BigInt.zero) return Response.badRequest(body: jsonEncode({'error': 'คูปองไม่สามารถใช้งานได้ (อาจถูกใช้ไปแล้ว หรือหมดอายุ)'}));
      return Response.ok(jsonEncode({'success': true}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
    }
  }

  String _generateCouponCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    String code = 'SMR-';
    for (var i = 0; i < 4; i++) {
      code += chars[rnd.nextInt(chars.length)];
    }
    code += '-';
    for (var i = 0; i < 4; i++) {
      code += chars[rnd.nextInt(chars.length)];
    }
    return code;
  }
}
