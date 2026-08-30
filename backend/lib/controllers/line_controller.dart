import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:io';
import '../db_config.dart';
import '../env_config.dart';
import '../services/line_service.dart';
import '../services/line_webhook_signature_verifier.dart';
import 'customer_tracking_controller.dart';

class LineController {
  final LineService _lineService = LineService();
  final LineWebhookSignatureVerifier _webhookSignatureVerifier =
      const LineWebhookSignatureVerifier();

  Router get publicRouter {
    final router = Router();
    router.post('/webhook', _handleWebhook);
    return router;
  }

  Router get internalRouter {
    stdout.writeln('✅ Registering protected LINE internal routes');
    final router = Router();
    router.post('/push-receipt', _handlePushReceipt);
    router.post('/push-receipt-image', _handlePushReceiptImage); // ✅ New
    router.post('/push-message', _handlePushMessage);
    router.post('/push-image', _handlePushImage);
    router.post('/push-scenario', _handlePushScenario); // ✅ New Phase 8
    router.post('/notify-stage2/<orderId>', _handleNotifyStage2);
    router.post('/notify-stage3/<orderId>', _handleNotifyStage3);
    return router;
  }

  // POST /api/v1/line/push-scenario
  // Body: { "lineUserId", "scenario", "orderId", "customerName", "grandTotal", "received", "debtAmount", "totalDebt", "points", "items": [...] }
  Future<Response> _handlePushScenario(Request request) async {
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);

      final String? lineUserId = body['lineUserId'];
      final int? scenario = body['scenario'];
      final String? orderIdStr = body['orderId'];

      if (lineUserId == null || scenario == null || orderIdStr == null) {
        return Response.badRequest(
          body: 'Missing lineUserId, scenario, or orderId',
        );
      }

      final String customerName = body['customerName'] ?? 'ลูกค้า';
      final double grandTotal =
          double.tryParse(body['grandTotal']?.toString() ?? '0') ?? 0.0;
      final double received =
          double.tryParse(body['received']?.toString() ?? '0') ?? 0.0;
      final double totalDebt =
          double.tryParse(body['totalDebt']?.toString() ?? '0') ?? 0.0;
      final int points =
          int.tryParse(body['pointsEarned']?.toString() ?? '0') ?? 0;
      final int frontStoreCount =
          int.tryParse(body['frontStoreItemsCount']?.toString() ?? '0') ??
          0; // ✅ Feature Front Store Item
      final List<dynamic> rawItems = body['items'] ?? [];

      // Generate Item List String
      final itemBuffer = StringBuffer();
      for (final item in rawItems) {
        final name = item['productName'] ?? '';
        final qtyStr = item['quantity']?.toString() ?? '0';
        final priceStr = item['price']?.toString() ?? '0';

        final qty = double.tryParse(qtyStr) ?? 0;
        final price = double.tryParse(priceStr) ?? 0;

        final qtyFmt = qty % 1 == 0
            ? qty.toInt().toString()
            : qty.toStringAsFixed(1);
        final priceFmt = price % 1 == 0
            ? price.toInt().toString()
            : price.toStringAsFixed(2);
        itemBuffer.writeln('  • $name x$qtyFmt (฿$priceFmt)');
      }

      final totalFmt = grandTotal % 1 == 0
          ? grandTotal.toInt().toString()
          : grandTotal.toStringAsFixed(2);

      // Check current points from DB
      int currentPoints = 0;
      try {
        final conn = await DbConfig().connection;
        final res = await conn.execute(
          '''SELECT COALESCE((SELECT SUM(points_earned - points_used) 
                       FROM point_ledger pl 
                       WHERE pl.customer_id = customer.id 
                         AND points_earned > points_used 
                         AND (expires_at IS NULL OR expires_at > NOW())), 0) as currentPoints
             FROM customer WHERE line_user_id = :uid''',
          {'uid': lineUserId},
        );
        if (res.numOfRows > 0) {
          currentPoints =
              int.tryParse(res.rows.first.colAt(0)?.toString() ?? '0') ?? 0;
        }
      } catch (_) {}

      final pointLine = points > 0
          ? '\n⭐ แต้มที่ได้รับ: +$points (รวมสะสม: $currentPoints คะแนน)'
          : '';

      String message = '';

      switch (scenario) {
        case 1:
          // Case 1: Cash Only (Thank you + Bill Summary) (Attach Receipt)
          message =
              '🧾 *ขอบคุณที่ใช้บริการครับ*\nคุณ $customerName\n\n'
              '🔖 ใบเสร็จเลขที่: #$orderIdStr\n'
              '─────────────────\n'
              '${itemBuffer.toString().trimRight()}\n'
              '─────────────────\n'
              '💰 ยอดสุทธิ: ฿$totalFmt'
              '$pointLine';
          break;
        case 2:
          // Case 2: Cash + Delivery — รายการสั่งซื้อ + ยอด (ไม่มีคำ "กำลังเตรียม" แล้ว)
          message =
              '🧾 *ได้รับรายการสั่งซื้อแล้วครับ*\nคุณ $customerName\n\n'
              '🔖 ใบเสร็จเลขที่: #$orderIdStr\n'
              '${frontStoreCount > 0 ? "📦 สินค้าซื้อหน้าร้าน: $frontStoreCount รายการ\n" : ""}'
              '─────────────────\n'
              '${itemBuffer.toString().trimRight()}\n'
              '─────────────────\n'
              '💰 ยอดสุทธิ: ฿$totalFmt (ชำระแล้ว)'
              '$pointLine';
          break;
        case 3:
          // Case 3: Credit Only (Thank you + Bill Summary + Remaining Debt) (Attach Delivery Note)
          message =
              '📦 *รายการขายเงินเชื่อ*\nคุณ $customerName\n\n'
              '🔖 ใบส่งของเลขที่: #$orderIdStr\n'
              '─────────────────\n'
              '${itemBuffer.toString().trimRight()}\n'
              '─────────────────\n'
              'ยอดบิลนี้: ฿$totalFmt\n'
              '🚨 *หนี้รวมล่าสุด*: ฿${totalDebt.toStringAsFixed(0)}'
              '$pointLine';
          break;
        case 4:
          // Case 4: Credit + Delivery — รายการ + ยอด + หนี้ (ไม่มีคำ "กำลังเตรียม" แล้ว)
          message =
              '📦 *ได้รับรายการสั่งซื้อแล้วครับ (ลงบัญชี/COD)*\nคุณ $customerName\n\n'
              '🔖 ใบส่งของเลขที่: #$orderIdStr\n'
              '${frontStoreCount > 0 ? "📦 สินค้าซื้อหน้าร้าน: $frontStoreCount รายการ\n" : ""}'
              '─────────────────\n'
              '${itemBuffer.toString().trimRight()}\n'
              '─────────────────\n'
              'ยอดบิลนี้: ฿$totalFmt\n'
              '🚨 *หนี้รวมล่าสุด*: ฿${totalDebt.toStringAsFixed(0)}'
              '$pointLine';
          break;
        case 21:
          // Scenario 21: Cash+Delivery — กำลังเตรียมสินค้า (ส่งโดย DeliveryIntegrationService หลังสร้าง Firestore Job)
          message =
              '⏳ *กำลังเตรียมสินค้าของท่านครับ*\n'
              '🔖 เลขที่: #$orderIdStr\n'
              '─────────────────\n'
              'เมื่อรถออกจากร้าน ท่านจะได้รับข้อความแจ้งเตือนอีกครั้งครับ 🚚';
          break;
        case 41:
          // Scenario 41: Credit+Delivery — กำลังเตรียมสินค้า COD (ส่งโดย DeliveryIntegrationService)
          message =
              '⏳ *กำลังเตรียมสินค้าของท่านครับ*\n'
              '🔖 เลขที่: #$orderIdStr\n'
              '─────────────────\n'
              'สินค้าจะถูกนำส่งพร้อมเก็บยอด *฿$totalFmt* ปลายทางครับ\n'
              'เมื่อรถออกจากร้าน ท่านจะได้รับข้อความแจ้งเตือนอีกครั้งครับ 🚚';
          break;
        case 5:
          // Case 5: Debt Payment (Paid amount + Remaining debt + Thank you) (Attach Receipt)
          message =
              '💰 *รับชำระเงินเรียบร้อย*\nคุณ $customerName\n\n'
              '🔖 อ้างอิงบิล/อ้างอิงรายจ่าย: #$orderIdStr\n'
              '─────────────────\n'
              '💵 ยอดชำระครั้งนี้: ฿${received.toStringAsFixed(0)}\n'
              '📊 *ยอดค้างชำระคงเหลือ*: ฿${totalDebt.toStringAsFixed(0)}\n'
              '─────────────────\n'
              'ขอบคุณที่ใช้บริการครับ 🙏';
          break;
        default:
          return Response.badRequest(body: 'Invalid scenario');
      }

      // Send Message first
      await _lineService.pushMessage(lineUserId, message);

      // We do NOT push the image here anymore.
      // The Flutter client will generate the image and call /api/v1/line/push-receipt-image
      // which will save the file and push the image message ONLY WHEN it's ready.

      stdout.writeln(
        '✅ Push Scenario $scenario Sent for Order #$orderIdStr to $lineUserId',
      );
      return Response.ok('Push Scenario $scenario Sent');
    } catch (e, stack) {
      stderr.writeln('Push Scenario Error: $e');
      stderr.writeln(stack);
      return Response.internalServerError(body: 'Failed to push scenario');
    }
  }

  // POST /api/v1/line/push-receipt-image
  // Body: { "lineUserId": "...", "orderId": "...", "image": "<base64>" }
  Future<Response> _handlePushReceiptImage(Request request) async {
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);

      final String? lineUserId = body['lineUserId'];
      final String? orderId = body['orderId'];
      final String? base64Image = body['image'];

      if (lineUserId == null || orderId == null || base64Image == null) {
        return Response.badRequest(
          body: 'Missing lineUserId, orderId, or image',
        );
      }
      final safeOrderId = int.tryParse(orderId);
      if (safeOrderId == null || safeOrderId <= 0) {
        return Response.badRequest(body: 'Invalid orderId');
      }
      if (lineUserId.length > 100 || lineUserId.trim() != lineUserId) {
        return Response.badRequest(body: 'Invalid LINE recipient');
      }
      // Base64 expands binary data by roughly 4/3. Bound it before decoding.
      if (base64Image.length > 8 * 1024 * 1024) {
        return Response(413, body: 'Receipt image is too large');
      }

      // 1. Decode Image
      final bytes = base64Decode(base64Image);

      // 2. Save File
      // ✅ ใช้ writableDir เพื่อแก้ปัญหาความปลอดภัยสิทธิ์การเขียนไฟล์ใน C:\Program Files\
      final String writableDir = EnvConfig().writableDir;
      final directory = Directory('$writableDir/bills');
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      final filename = 'bill-$safeOrderId.png';
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);

      stdout.writeln(
        '✅ Saved Receipt Image: ${file.path} (${bytes.length} bytes)',
      );

      // 3. Construct URL
      // ✅ ใช้ EnvConfig().publicUrl โดยตรง (โหลดจาก .env ที่ exe directory)
      // ไม่ใช้ body['baseUrl'] เพราะ Flutter app รันบนเครื่องเดียวกับ backend
      // ทำให้ body['baseUrl'] ได้ http://localhost:8080 เสมอ
      final String baseUrl = EnvConfig().publicUrl;
      final imageUrl = '$baseUrl/public/bills/$filename';
      stdout.writeln('📤 Image URL → $imageUrl');

      await _lineService.pushImage(lineUserId, imageUrl);

      // ✅ 4. Auto-cleanup old bills (older than 7 days)
      _cleanupOldBills(directory);

      return Response.ok('Receipt Image Sent');
    } catch (e, stack) {
      stderr.writeln('Push Receipt Image Error: $e');
      stderr.writeln(stack);
      return Response.internalServerError(body: 'Failed to push receipt image');
    }
  }

  void _cleanupOldBills(Directory directory) {
    try {
      final now = DateTime.now();
      final files = directory.listSync().whereType<File>();
      int deletedCount = 0;
      for (final file in files) {
        final lastModified = file.lastModifiedSync();
        if (now.difference(lastModified).inDays >= 7) {
          file.deleteSync();
          deletedCount++;
        }
      }
      if (deletedCount > 0) {
        stdout.writeln('🧹 Cleaned up $deletedCount old bill images.');
      }
    } catch (e) {
      stderr.writeln('⚠️ Failed to clean up old bills: $e');
    }
  }

  // POST /api/v1/line/push-receipt
  Future<Response> _handlePushReceipt(Request request) async {
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);

      final String? lineUserId = body['lineUserId'];
      final String? orderIdStr = body['orderId'];

      if (lineUserId == null || orderIdStr == null) {
        return Response.badRequest(body: 'Missing lineUserId or orderId');
      }

      final conn = await DbConfig().connection;

      // ✅ Query ข้อมูลจาก DB จริง แทนการ parse จาก body (ป้องกัน amount=0.0)
      // 1. ดึงข้อมูล Order
      final orderRes = await conn.execute(
        'SELECT grandTotal FROM `order` WHERE id = :oid',
        {'oid': orderIdStr},
      );
      if (orderRes.numOfRows == 0) {
        return Response.notFound('Order not found');
      }
      final grandTotal =
          double.tryParse(orderRes.rows.first.colAt(0)?.toString() ?? '0') ??
          0.0;

      // 2. ดึงรายการสินค้า (Order Items)
      final itemsRes = await conn.execute(
        '''SELECT oi.productName, oi.quantity, oi.price, oi.total
           FROM orderitem oi
           WHERE oi.orderId = :oid''',
        {'oid': orderIdStr},
      );

      // 3. ดึงแต้มสะสมปัจจุบันของลูกค้า
      final pointsRes = await conn.execute(
        '''SELECT COALESCE((SELECT SUM(points_earned - points_used) 
                   FROM point_ledger pl 
                   WHERE pl.customer_id = c.id 
                     AND points_earned > points_used 
                     AND (expires_at IS NULL OR expires_at > NOW())), 0) as currentPoints
           FROM customer c
           JOIN `order` o ON o.customerId = c.id
           WHERE o.id = :oid''',
        {'oid': orderIdStr},
      );
      final currentPoints =
          int.tryParse(
            pointsRes.rows.firstOrNull?.colAt(0)?.toString() ?? '0',
          ) ??
          0;

      // สุดท้ายรับ points ที่ได้รับจาก request (ถ้าไม่มี คำนวณ fallback)
      final int earnedPoints =
          int.tryParse(body['points']?.toString() ?? '0') ?? 0;

      // 4. สร้างข้อความพร้อมรายการสินค้า
      final itemBuffer = StringBuffer();
      for (final row in itemsRes.rows) {
        final name = row.colAt(0) ?? '';
        final qty = row.colAt(1) ?? '';
        final price = double.tryParse(row.colAt(2)?.toString() ?? '0') ?? 0.0;
        final fmt = price % 1 == 0
            ? price.toInt().toString()
            : price.toStringAsFixed(2);
        itemBuffer.writeln('  • $name x$qty (฿$fmt)');
      }

      final totalFmt = grandTotal % 1 == 0
          ? grandTotal.toInt().toString()
          : grandTotal.toStringAsFixed(2);

      final pointLine = earnedPoints > 0
          ? '\n⭐ แต้มที่ได้รับ: +$earnedPoints (รวมสะสม: $currentPoints คะแนน)'
          : '';

      final message =
          '🧾 ขอบคุณที่ใช้บริการครับ\n\n'
          '🔖 ใบเสร็จเลขที่: #$orderIdStr\n'
          '─────────────────\n'
          '${itemBuffer.toString().trimRight()}\n'
          '─────────────────\n'
          '💰 ยอดสุทธิ: ฿$totalFmt'
          '$pointLine';

      await _lineService.pushMessage(lineUserId, message);

      stdout.writeln('✅ Push Receipt Sent for Order #$orderIdStr');
      return Response.ok('Push Sent');
    } catch (e) {
      stderr.writeln('Push Receipt Error: $e');
      return Response.internalServerError(body: 'Failed to push receipt');
    }
  }

  // POST /api/v1/line/push-image
  Future<Response> _handlePushImage(Request request) async {
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);

      final String? lineUserId = body['lineUserId'];
      final String? filename = body['filename'];
      // Ideally, pass the public base URL from env or request
      // For now, assume ngrok or public IP is set in .env or Settings
      // Fallback to a placeholder if not set, but Line won't load localhost.
      String baseUrl = EnvConfig().publicUrl;

      // If client sends full URL, use it. If filename, construct it.
      String imageUrl;
      if (filename != null &&
          (filename.startsWith('http') || filename.startsWith('https'))) {
        imageUrl = filename;
      } else if (filename != null) {
        imageUrl = '$baseUrl/public/bills/$filename';
      } else {
        return Response.badRequest(body: 'Missing filename');
      }

      if (lineUserId == null) {
        return Response.badRequest(body: 'Missing lineUserId');
      }

      await _lineService.pushImage(lineUserId, imageUrl);
      return Response.ok('Push Image Sent');
    } catch (e) {
      stderr.writeln('Push Image Error: $e');
      return Response.internalServerError(body: 'Failed to push image');
    }
  }

  // POST /api/v1/line/push-message
  Future<Response> _handlePushMessage(Request request) async {
    try {
      final payload = await request.readAsString();
      final body = jsonDecode(payload);

      final String? lineUserId = body['lineUserId'];
      final String? message = body['message'];

      if (lineUserId == null || message == null) {
        return Response.badRequest(body: 'Missing lineUserId or message');
      }

      await _lineService.pushMessage(lineUserId, message);
      return Response.ok('Push Sent');
    } catch (e) {
      stderr.writeln('Push Message Error: $e');
      return Response.internalServerError(body: 'Failed to push message');
    }
  }

  // POST /api/v1/line/notify-stage2/{orderId}
  // เรียกจาก Cloud Functions เมื่อกด "ปล่อยรถ"
  Future<Response> _handleNotifyStage2(Request request, String orderId) async {
    try {
      stdout.writeln('📦 Stage 2 Notification Request for Order #$orderId');

      String vehicleKey = '';
      try {
        final body = await request.readAsString();
        if (body.isNotEmpty) {
          vehicleKey =
              (jsonDecode(body) as Map<String, dynamic>)['vehicle']
                  ?.toString()
                  .trim() ??
              '';
        }
      } catch (_) {}

      final conn = await DbConfig().connection;

      // หา line_user_id จาก order_id
      final res = await conn.execute(
        '''
        SELECT c.line_user_id 
        FROM `order` o
        INNER JOIN customer c ON o.customerId = c.id
        WHERE o.id = :orderId
      ''',
        {'orderId': orderId},
      );

      if (res.numOfRows == 0) {
        stdout.writeln('⚠️  Order #$orderId not found');
        return Response.notFound('Order not found');
      }

      final lineUserId = res.rows.first.colAt(0);

      if (lineUserId == null || lineUserId.isEmpty) {
        stdout.writeln('⚠️  No line_user_id for Order #$orderId');
        return Response(400, body: 'Customer has no Line account');
      }

      final trackingToken =
          !CustomerTrackingController.canTrackVehicle(vehicleKey)
          ? null
          : await CustomerTrackingController.issue(
              orderId: int.tryParse(orderId) ?? 0,
              vehicleKey: vehicleKey,
            );
      final trackingUrl = trackingToken == null
          ? null
          : '${EnvConfig().publicUrl}/public/customer_tracking.html#$trackingToken';
      if (trackingUrl != null) {
        final flexCard = {
          'type': 'bubble',
          'size': 'mega',
          'header': {
            'type': 'box',
            'layout': 'vertical',
            'contents': [
              {
                'type': 'text',
                'text': '🚚 สินค้ากำลังเดินทางจัดส่ง',
                'weight': 'bold',
                'size': 'lg',
                'color': '#ffffff',
              },
            ],
            'backgroundColor': '#0f766e',
            'paddingAll': '16px',
          },
          'body': {
            'type': 'box',
            'layout': 'vertical',
            'spacing': 'md',
            'contents': [
              {
                'type': 'text',
                'text':
                    'สินค้าของท่านถูกปล่อยออกจากร้านแล้วครับ กำลังมุ่งหน้าไปจัดส่งให้ท่านถึงหน้างาน',
                'wrap': true,
                'size': 'sm',
                'color': '#334155',
              },
              {
                'type': 'box',
                'layout': 'vertical',
                'margin': 'md',
                'spacing': 'xs',
                'contents': [
                  {
                    'type': 'box',
                    'layout': 'baseline',
                    'spacing': 'sm',
                    'contents': [
                      {
                        'type': 'text',
                        'text': '🔖 ออเดอร์:',
                        'color': '#64748b',
                        'size': 'sm',
                        'flex': 2,
                      },
                      {
                        'type': 'text',
                        'text': '#$orderId',
                        'weight': 'bold',
                        'color': '#0f766e',
                        'size': 'sm',
                        'flex': 4,
                      },
                    ],
                  },
                  {
                    'type': 'box',
                    'layout': 'baseline',
                    'spacing': 'sm',
                    'contents': [
                      {
                        'type': 'text',
                        'text': '📞 ติดต่อร้าน:',
                        'color': '#64748b',
                        'size': 'sm',
                        'flex': 2,
                      },
                      {
                        'type': 'text',
                        'text': '085-1377402',
                        'weight': 'bold',
                        'color': '#334155',
                        'size': 'sm',
                        'flex': 4,
                      },
                    ],
                  },
                ],
              },
              {'type': 'separator', 'margin': 'md', 'color': '#e2e8f0'},
              {
                'type': 'text',
                'text': 'แตะปุ่มด้านล่างเพื่อดูตำแหน่งรถสดบนแผนที่ 📍',
                'size': 'xs',
                'color': '#94a3b8',
                'wrap': true,
              },
            ],
            'paddingAll': '16px',
          },
          'footer': {
            'type': 'box',
            'layout': 'vertical',
            'spacing': 'sm',
            'contents': [
              {
                'type': 'button',
                'style': 'primary',
                'height': 'sm',
                'action': {
                  'type': 'uri',
                  'label': '📍 กดติดตามตำแหน่งรถบนแผนที่',
                  'uri': trackingUrl,
                },
                'color': '#0f766e',
              },
            ],
            'paddingAll': '16px',
            'paddingTop': '0px',
          },
        };

        final sent = await _lineService.pushFlexMessage(
          lineUserId,
          '🚚 สินค้าของท่านกำลังเดินทางจัดส่งครับ (กดดูตำแหน่งรถ)',
          flexCard,
        );

        if (!sent) {
          // Fallback to text message if flex push failed
          final fallbackMessage =
              '🚚 สินค้าของท่านกำลังเดินทางจัดส่งครับ\n'
              '🔖 ออเดอร์: #$orderId\n'
              '📞 โทร: 085-1377402\n\n'
              '📍 ติดตามตำแหน่งรถได้ที่:\n$trackingUrl';
          await _lineService.pushMessage(lineUserId, fallbackMessage);
        }
      } else {
        final message =
            '🚚 สินค้าของท่านกำลังเดินทางจัดส่งครับ\n'
            '🔖 ออเดอร์: #$orderId\n'
            'หากมีข้อสงสัยสามารถติดต่อได้ที่เบอร์ร้าน 085-1377402 ครับ';
        await _lineService.pushMessage(lineUserId, message);
      }

      stdout.writeln('✅ Stage 2 Line sent to $lineUserId for Order #$orderId');
      return Response.ok('Stage 2 Notification Sent');
    } catch (e) {
      stderr.writeln('❌ Stage 2 Notification Error: $e');
      return Response.internalServerError(body: 'Failed: $e');
    }
  }

  // POST /api/v1/line/notify-stage3/{orderId}
  // เรียกจาก Cloud Functions เมื่อกด "จบงาน"
  Future<Response> _handleNotifyStage3(Request request, String orderId) async {
    try {
      stdout.writeln('📦 Stage 3 Notification Request for Order #$orderId');

      String? imageUrl;
      String? locationUrl;
      try {
        final payload = await request.readAsString();
        if (payload.isNotEmpty) {
          final body = jsonDecode(payload);
          imageUrl = body['imageUrl'];
          locationUrl = body['locationUrl'];
          final lat = body['lat'];
          final lng = body['lng'];
          if (locationUrl == null && lat != null && lng != null) {
            locationUrl = 'https://maps.google.com/?q=$lat,$lng';
          }
        }
      } catch (_) {}

      final conn = await DbConfig().connection;

      // หา line_user_id จาก order_id
      final res = await conn.execute(
        '''
        SELECT c.line_user_id 
        FROM `order` o
        INNER JOIN customer c ON o.customerId = c.id
        WHERE o.id = :orderId
      ''',
        {'orderId': orderId},
      );

      if (res.numOfRows == 0) {
        stdout.writeln('⚠️  Order #$orderId not found');
        return Response.notFound('Order not found');
      }

      final lineUserId = res.rows.first.colAt(0);

      if (lineUserId == null || lineUserId.isEmpty) {
        stdout.writeln('⚠️  No line_user_id for Order #$orderId');
        return Response(400, body: 'Customer has no Line account');
      }

      // ส่ง Line Message
      String message =
          '✅ ส่งสินค้าเรียบร้อยแล้ว\n'
          'ขอบคุณที่เลือกใช้บริการและให้ความไว้วางใจ\n'
          'ร้าน ส.บริการ ท่าข้าม ยินดีให้บริการครับ 🙏';

      if (locationUrl != null) {
        message += '\n\n📍 พิกัดจัดส่ง:\n$locationUrl';
      }

      await _lineService.pushMessage(lineUserId, message);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _lineService.pushImage(lineUserId, imageUrl).catchError((e) {
          stderr.writeln(
            'Warning: Failed to push receipt image for Stage 3: $e',
          );
          return false;
        });
      }

      stdout.writeln('✅ Stage 3 Line sent to $lineUserId for Order #$orderId');
      return Response.ok('Stage 3 Notification Sent');
    } catch (e) {
      stderr.writeln('❌ Stage 3 Notification Error: $e');
      return Response.internalServerError(body: 'Failed: $e');
    }
  }

  Future<Response> _handleWebhook(Request request) async {
    try {
      final payload = await request.readAsString();
      final signature = request.headers['x-line-signature'];
      final secret = EnvConfig().lineChannelSecret;
      if (secret.isNotEmpty &&
          !_webhookSignatureVerifier.verify(
            rawBody: payload,
            signature: signature,
            channelSecret: secret,
          )) {
        stderr.writeln('❌ Invalid LINE webhook signature');
        return Response.forbidden('Invalid LINE webhook signature');
      }
      final body = jsonDecode(payload);

      final events = body['events'] as List<dynamic>;

      for (var event in events) {
        final type = event['type'];
        final userId = event['source']['userId'];

        // replyToken might be null
        final replyToken = event['replyToken'];

        stdout.writeln(
          '📩 Line Webhook: Type=$type, UserId=$userId, Text=${event['message']?['text']}',
        );

        // 🟢 Handle Follow
        if (type == 'follow') {
          await _lineService.replyMessage(
            replyToken,
            'สวัสดีครับ! ยินดีต้อนรับสู่ระบบสมาชิก ร้านส.บริการ ท่าข้าม\n\nแตะเมนูสมาชิกใน LINE เพื่อสมัครหรือเชื่อมบัญชีอย่างปลอดภัยครับ',
          );
          continue;
        }

        // 🟡 Handle Message & Postback
        String? commandText;
        if (type == 'message' && event['message']['type'] == 'text') {
          commandText = (event['message']['text'] as String).trim();
        } else if (type == 'postback') {
          commandText = event['postback']['data'].toString().trim();
          stdout.writeln('📩 Postback Data: $commandText');
        }

        if (commandText != null) {
          final cmd = commandText;

          // 1. Is it Unregister?
          if (cmd == 'ยกเลิกสมาชิก' || cmd.toUpperCase() == 'UNREGISTER') {
            await _handleUnregister(userId, replyToken);
            continue;
          }

          // 2. Check Member Status First (ALWAYS AVAILABLE 24/7)
          var linkedData = await _getLinkedMemberData(userId);

          // Phone-only linking is deliberately disabled. A phone number is an
          // unverified contact, never proof that the LINE user owns a member.
          if (linkedData == null && RegExp(r'^[0-9]{10}$').hasMatch(cmd)) {
            await _lineService.replyMessage(
              replyToken,
              'เพื่อความปลอดภัย ระบบไม่ผูกสมาชิกด้วยเบอร์โทรอย่างเดียวครับ กรุณาแตะเมนูสมาชิกเพื่อส่งคำขอ หรือสแกน QR จากพนักงานที่ร้าน',
            );
            continue;
          }

          // 3. Main Commands (Register/Member/Catalog)
          if (cmd.toLowerCase().contains('register') ||
              cmd.contains('สมัคร') ||
              cmd.contains('สมาชิก') ||
              cmd.contains('QR')) {
            if (linkedData != null) {
              final liffId = '2009815377-VjmykeWs'; // ✅ Corrected LIFF ID
              final memberCode = linkedData['memberCode'];
              final name = linkedData['firstName'];
              final points = linkedData['currentPoints'] ?? 0;

              // Generate QR Code URL
              final qrUrl =
                  'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$memberCode';

              // Construct Flex Message
              final flexMessage = {
                'type': 'flex',
                'altText': 'บัตรสมาชิก S-Link',
                'contents': {
                  'type': 'bubble',
                  'header': {
                    'type': 'box',
                    'layout': 'vertical',
                    'contents': [
                      {
                        'type': 'text',
                        'text': 'MEMBERSHIP CARD',
                        'weight': 'bold',
                        'color': '#1DB446',
                        'size': 'sm',
                      },
                      {
                        'type': 'text',
                        'text': 'ร้านส.บริการ ท่าข้าม',
                        'weight': 'bold',
                        'size': 'xl',
                        'margin': 'md',
                      },
                    ],
                  },
                  'hero': {
                    'type': 'image',
                    'url': qrUrl,
                    'size': 'xl',
                    'aspectRatio': '1:1',
                    'aspectMode': 'cover',
                    'action': {'type': 'uri', 'uri': qrUrl},
                  },
                  'body': {
                    'type': 'box',
                    'layout': 'vertical',
                    'contents': [
                      {
                        'type': 'text',
                        'text': name,
                        'weight': 'bold',
                        'size': 'xl',
                        'align': 'center',
                      },
                      {
                        'type': 'text',
                        'text': 'Member: $memberCode',
                        'size': 'xs',
                        'color': '#aaaaaa',
                        'wrap': true,
                        'align': 'center',
                        'margin': 'xs',
                      },
                      {'type': 'separator', 'margin': 'xl'},
                      {
                        'type': 'box',
                        'layout': 'horizontal',
                        'margin': 'xl',
                        'contents': [
                          {
                            'type': 'text',
                            'text': 'P O I N T S',
                            'size': 'sm',
                            'color': '#555555',
                            'flex': 0,
                          },
                          {
                            'type': 'text',
                            'text': '$points',
                            'size': 'xl',
                            'weight': 'bold',
                            'align': 'end',
                            'color': '#111111',
                          },
                        ],
                      },
                    ],
                  },
                  'footer': {
                    'type': 'box',
                    'layout': 'vertical',
                    'spacing': 'sm',
                    'contents': [
                      {
                        'type': 'button',
                        'style': 'primary',
                        'color': '#1DB446',
                        'action': {
                          'type': 'uri',
                          'label': '🎟️ แลกรางวัล / ดูคูปอง',
                          'uri': 'https://liff.line.me/$liffId',
                        },
                      },
                    ],
                  },
                },
              };

              await _lineService.reply(replyToken, [flexMessage]);
            } else {
              await _lineService.replyMessage(
                replyToken,
                'กรุณาแตะเมนูสมาชิกใน LINE เพื่อสมัครด้วยบัญชี LINE ที่ยืนยันแล้วครับ หากมีเบอร์เดิม ระบบจะส่งคำขอให้พนักงานตรวจสอบโดยไม่เขียนทับบัญชีเดิม',
              );
            }
            continue;
          }

          // 7. Other Command Logic
          if (cmd.toUpperCase().startsWith('REF-ID:')) {
            await _lineService.replyMessage(
              replyToken,
              'ยกเลิกการผูกด้วย REF-ID แล้วเพื่อความปลอดภัยครับ กรุณาใช้คำขอในหน้า สมาชิก หรือสแกน QR ครั้งเดียวจากพนักงานที่ร้าน',
            );
          } else if (cmd == 'คะแนน' || cmd == 'แต้ม' || cmd == 'Point') {
            await _handlePointCheck(userId, replyToken);
          } else if (cmd == 'ประวัติ' ||
              cmd == 'ประวัติการซื้อ' ||
              cmd == 'History') {
            await _handleHistory(userId, replyToken);
          }
        }
      }

      return Response.ok('OK');
    } catch (e) {
      stderr.writeln('Webhook Error: $e');
      return Response.internalServerError(body: 'Error processing webhook');
    }
  }

  // History Handler
  Future<void> _handleHistory(String userId, String replyToken) async {
    try {
      final conn = await DbConfig().connection;
      // Find customerId from lineUserId
      final userRes = await conn.execute(
        'SELECT id FROM customer WHERE line_user_id = :uid',
        {'uid': userId},
      );

      if (userRes.numOfRows == 0) {
        await _lineService.replyMessage(
          replyToken,
          'คุณยังไม่ได้ผูกบัญชีสมาชิกครับ',
        );
        return;
      }

      final customerId = userRes.rows.first.colAt(0);

      // Get Last 5 Orders
      final orderRes = await conn.execute(
        'SELECT id, grandTotal, createdAt FROM `order` WHERE customerId = :cid ORDER BY id DESC LIMIT 5',
        {'cid': customerId},
      );

      if (orderRes.numOfRows == 0) {
        await _lineService.replyMessage(
          replyToken,
          '🤷‍♂️ ยังไม่พบประวัติการสั่งซื้อครับ',
        );
        return;
      }

      final buffer = StringBuffer('📜 ประวัติการซื้อ 5 รายการล่าสุด:\n');
      for (final row in orderRes.rows) {
        final id = row.colAt(0);
        final price = double.tryParse(row.colAt(1) ?? '0') ?? 0;
        final dateStr = row.colAt(2);

        // Simple date formatting if string
        String dateDisplay = dateStr ?? '-';
        if (dateStr != null && dateStr.length > 10) {
          dateDisplay = dateStr.substring(0, 10);
        }

        buffer.writeln('#$id - $dateDisplay (฿$price)');
      }

      await _lineService.replyMessage(replyToken, buffer.toString());
    } catch (e) {
      stderr.writeln('History Error: $e');
      await _lineService.replyMessage(
        replyToken,
        'ไม่สามารถดูประวัติได้ขณะนี้',
      );
    }
  }

  Future<Map<String, dynamic>?> _getLinkedMemberData(String userId) async {
    try {
      final conn = await DbConfig().connection;
      // 🟢 Robust Lookup: Trim whitespace and check isDeleted
      final res = await conn.execute(
        '''SELECT id, memberCode, firstName, 
           COALESCE((SELECT SUM(points_earned - points_used) 
                     FROM point_ledger pl 
                     WHERE pl.customer_id = customer.id 
                       AND (expires_at IS NULL OR expires_at > NOW())), 0) as currentPoints
           FROM customer 
           WHERE TRIM(line_user_id) = :uid 
             AND (isDeleted = 0 OR isDeleted IS NULL)''',
        {'uid': userId.trim()},
      );

      if (res.numOfRows > 0) {
        final row = res.rows.first;
        final data = {
          'id': row.colAt(0),
          'memberCode': row.colAt(1) ?? '',
          'firstName': row.colAt(2) ?? 'สมาชิก',
          'currentPoints': int.tryParse(row.colAt(3)?.toString() ?? '0') ?? 0,
        };
        stdout.writeln(
          '✅ Member Found: ${data['firstName']} (Points: ${data['currentPoints']})',
        );
        return data;
      }

      stdout.writeln('🔍 Member Not Found for Line ID: $userId');
      return null;
    } catch (e, stack) {
      stdout.writeln('❌ Get Member Data Error: $e\n$stack');
      return null;
    }
  }

  Future<void> _handlePointCheck(String userId, String replyToken) async {
    try {
      final conn = await DbConfig().connection;
      final results = await conn.execute(
        '''SELECT c.firstName, 
           COALESCE((SELECT SUM(points_earned - points_used) 
                     FROM point_ledger pl 
                     WHERE pl.customer_id = c.id 
                       AND (expires_at IS NULL OR expires_at > NOW())), 0) as currentPoints
           FROM customer c 
           WHERE c.line_user_id = :uid''',
        {'uid': userId},
      );

      if (results.numOfRows > 0) {
        final row = results.rows.first;
        final name = row.colAt(0) ?? 'ลูกค้า';
        final points = int.tryParse(row.colAt(1)?.toString() ?? '0') ?? 0;
        await _lineService.replyMessage(
          replyToken,
          'คุณ $name มีแต้มสะสมทั้งหมด: $points คะแนน',
        );
      } else {
        await _lineService.replyMessage(
          replyToken,
          'ไม่พบบัญชีสมาชิก กรุณาพิมพ์ "Register" เพื่อสมัคร',
        );
      }
    } catch (e) {
      await _lineService.replyMessage(
        replyToken,
        'ไม่สามารถตรวจสอบคะแนนได้ในขณะนี้',
      );
    }
  }

  Future<void> _handleUnregister(String userId, String replyToken) async {
    try {
      final conn = await DbConfig().connection;
      final res = await conn.execute(
        'UPDATE customer SET line_user_id = NULL, line_display_name = NULL WHERE line_user_id = :uid',
        {'uid': userId},
      );

      if (res.affectedRows > BigInt.zero) {
        await _lineService.replyMessage(
          replyToken,
          'ยกเลิกการผูกบัญชีสมาชิกเรียบร้อยครับ 👋',
        );
      } else {
        await _lineService.replyMessage(
          replyToken,
          'คุณยังไม่ได้เป็นสมาชิก หรือไม่ได้ผูกบัญชีไว้ครับ',
        );
      }
    } catch (e) {
      await _lineService.replyMessage(
        replyToken,
        'เกิดข้อผิดพลาดในการยกเลิกสมาชิก',
      );
    }
  }
}
