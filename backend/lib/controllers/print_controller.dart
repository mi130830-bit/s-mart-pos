import 'dart:convert';
import '../db_config.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:io';
import 'package:dotenv/dotenv.dart';

class PrintController {
  Router get router {
    final router = Router();
    router.post('/order/<id>', _printOrder);
    router.get('/test', _testPrint);
    return router;
  }

  // POST /api/v1/print/order/:id
  Future<Response> _printOrder(Request request, String id) async {
    try {
      stdout.writeln('🖨️ API: Printing Order #$id...');
      final orderId = int.tryParse(id);
      if (orderId == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid ID'}));
      }

      final conn = await DbConfig().connection;

      // 1. Fetch Order Header
      final orderResult = await conn.execute(
        'SELECT * FROM `order` WHERE id = :id',
        {'id': orderId},
      );

      if (orderResult.rows.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Order not found'}));
      }
      final orderRow = orderResult.rows.first.assoc();

      // 2. Fetch Order Items
      final itemsResult = await conn.execute(
        'SELECT * FROM orderitem WHERE orderId = :id',
        {'id': orderId},
      );

      final items = itemsResult.rows.map((row) => row.assoc()).toList();

      // 3. Prepare Data for Print Service
      final printData = {
        'orderId': orderRow['orderNumber'] ?? id,
        'date': orderRow['createdAt'].toString(),
        'total': orderRow['total'], // Subtotal
        'discount': orderRow['discount'],
        'grandTotal': orderRow['grandTotal'], // Net Total
        'received': orderRow['received'],
        'change': orderRow['changeAmount'] ?? orderRow['change'],
        'paymentMethod': orderRow['paymentMethod'],
        'items': items.map((item) {
          return {
            'productName': item['productName'],
            'quantity': item['quantity'],
            'price': item['price'],
            'total': item['total'],
          };
        }).toList(),
      };

      // 4. Send to Remote Print Service via Cloudflare Tunnel
      final env = DotEnv(includePlatformEnvironment: true)..load();
      final printServiceUrl = env['PRINT_SERVICE_URL'];

      if (printServiceUrl != null && printServiceUrl.isNotEmpty) {
        await _sendToRemotePrintService(printServiceUrl, printData);
      } else {
        throw Exception('PRINT_SERVICE_URL not configured');
      }

      return Response.ok(
        jsonEncode({
          'message': 'Print command sent to Remote Service',
          'orderId': id,
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stack) {
      stdout.writeln('❌ Print Error: $e');
      stdout.writeln(stack);
      return Response.internalServerError(
        body: jsonEncode({'error': 'Print failed: $e'}),
      );
    }
  }

  Future<void> _sendToRemotePrintService(
    String baseUrl,
    Map<String, dynamic> data,
  ) async {
    stdout.writeln('📡 Sending to Remote Print Service: $baseUrl');
    final url = Uri.parse('$baseUrl/print');

    // We need 'http' package, but let's use standard dart:io HttpClient for zero-dependency if possible,
    // or just assume we can add 'http' to pubspec.
    // Since 'http' is not in standard libs, let's use HttpClient.

    final client = HttpClient();
    try {
      final req = await client.postUrl(url);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(data));
      final resp = await req.close();

      if (resp.statusCode != 200) {
        final body = await resp.transform(utf8.decoder).join();
        throw Exception('Remote Service Error (${resp.statusCode}): $body');
      }
      stdout.writeln('✅ Remote Print Success!');
    } finally {
      client.close();
    }
  }

  // GET /api/v1/print/test
  Future<Response> _testPrint(Request request) async {
    try {
      await _printOrder(request, 'TEST-999');
      return Response.ok(jsonEncode({'message': 'Test Print OK'}));
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': '$e'}));
    }
  }
}
