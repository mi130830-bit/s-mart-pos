import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/customer.dart';
import '../../models/order_item.dart';
import '../settings_service.dart';
import '../mysql_service.dart';
import '../logger_service.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/sales_repository.dart';
import '../printing/receipt_service.dart';

/// Service dedicated to LINE pushing notifications, retry queues, and background log processor.
class FirebaseMessagingService {
  /// Sends standard LINE text notification.
  Future<bool> sendLineNotification(
      MySQLService db, int orderId, String message) async {
    // 1. Resolve Line User ID
    String? lineUserId;
    try {
      final res = await db.query('''
          SELECT c.line_user_id 
          FROM `order` o
          JOIN customer c ON o.customerId = c.id
          WHERE o.id = :oid
        ''', {'oid': orderId});
      if (res.isNotEmpty) {
        lineUserId = res.first['line_user_id']?.toString();
      }
    } catch (e) {
      LoggerService.error('FirebaseMessaging', 'Failed to resolve Line User ID', e);
      return false;
    }

    if (lineUserId == null || lineUserId.isEmpty) return false;

    // 2. Prepare Payload
    final apiUrl = SettingsService().apiUrl;
    final Uri url = Uri.parse('$apiUrl/line/push-message');
    final body = jsonEncode({
      'lineUserId': lineUserId,
      'message': message,
    });

    // 3. Send with Retry & Log (Future<bool>)
    return await _sendWithRetry(
      db: db,
      orderId: orderId,
      lineUserId: lineUserId,
      messageType: 'TEXT',
      content: message,
      url: url,
      body: body,
    );
  }

  /// Sends standard LINE image notification.
  Future<bool> sendLineImageNotification(
      MySQLService db, int orderId, String filename) async {
    // 1. Resolve Line User ID
    String? lineUserId;
    try {
      final res = await db.query('''
          SELECT c.line_user_id 
          FROM `order` o
          JOIN customer c ON o.customerId = c.id
          WHERE o.id = :oid
        ''', {'oid': orderId});
      if (res.isNotEmpty) {
        lineUserId = res.first['line_user_id']?.toString();
      }
    } catch (e) {
      LoggerService.error('FirebaseMessaging', 'Failed to resolve Line User ID', e);
      return false;
    }

    if (lineUserId == null || lineUserId.isEmpty) return false;

    // 2. Prepare Payload
    final apiUrl = SettingsService().apiUrl;
    final Uri url = Uri.parse('$apiUrl/line/push-image');
    final body = jsonEncode({
      'lineUserId': lineUserId,
      'filename': filename,
    });

    // 3. Send with Retry & Log
    return await _sendWithRetry(
      db: db,
      orderId: orderId,
      lineUserId: lineUserId,
      messageType: 'IMAGE',
      content: filename,
      url: url,
      body: body,
    );
  }

  /// Private Helper: Send HTTP Request with Persistent Retry & Logging.
  Future<bool> _sendWithRetry({
    required MySQLService db,
    required int orderId,
    required String lineUserId,
    required String messageType,
    required String content,
    required Uri url,
    required String body,
    int? existingLogId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final repo = NotificationRepository(db);
    await repo.initTable();

    int logId;
    if (existingLogId != null) {
      logId = existingLogId;
    } else {
      logId = await repo.createLog(
        orderId: orderId,
        lineUserId: lineUserId,
        messageType: messageType,
        content: content,
      );
    }

    try {
      LoggerService.info(
          'FirebaseMessaging', 'Sending $messageType -> $lineUserId (LogID: $logId)');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        LoggerService.info('FirebaseMessaging', 'Send Success!');
        await repo.markAsSuccess(logId);
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      LoggerService.error('FirebaseMessaging', 'Immediate Send Failed', e);

      repo.updateLog(logId,
          status: 'RETRYING',
          errorMessage: e.toString());

      return false;
    }
  }

  /// Processes queued pending Line messages.
  Future<void> processPendingNotifications(MySQLService db) async {
    final repo = NotificationRepository(db);
    final pendingLogs = await repo.getPendingLogs();

    if (pendingLogs.isEmpty) return;

    LoggerService.info(
        'FirebaseMessaging', 'Processing ${pendingLogs.length} pending notifications...');

    for (final log in pendingLogs) {
      try {
        final int id = int.tryParse(log['id'].toString()) ?? 0;
        final int attempts =
            int.tryParse(log['attempt_count']?.toString() ?? '0') ?? 0;
        final String lineUserId = log['line_user_id']?.toString() ?? '';
        final String type = log['message_type']?.toString() ?? 'TEXT';
        final String content = log['content']?.toString() ?? '';

        if (attempts > 10) {
          await repo.markAsFailed(id, "Max attempts reached");
          continue;
        }

        if (type == 'RECEIPT_IMAGE') {
          try {
            final orderId = int.tryParse(log['order_id']?.toString() ?? '0') ?? 0;
            if (orderId == 0) throw Exception("Invalid Order ID");

            final salesRepo = SalesRepository();
            final orderResult = await salesRepo.getOrderWithItems(orderId);
            if (orderResult == null) throw Exception("Order not found");

            final order = orderResult['order'] as Map<String, dynamic>;
            final items = (orderResult['items'] as List<OrderItem>?) ?? [];
            final customer = Customer.fromJson({
              'id': int.tryParse(order['customerId'].toString()) ?? 0,
              'firstName': order['firstName'] ?? '',
              'lastName': order['lastName'] ?? '',
              'phone': order['phone'] ?? '',
            });

            final double total = double.tryParse(order['total']?.toString() ?? '0') ?? 0;
            final double grandTotal = double.tryParse(order['grandTotal']?.toString() ?? '0') ?? 0;
            final double received = double.tryParse(order['received']?.toString() ?? '0') ?? 0;
            final double changeAmount = double.tryParse(order['changeAmount']?.toString() ?? '0') ?? 0;

            final imageBytes = await ReceiptService().captureReceiptImage(
              orderId: orderId,
              items: items,
              total: total,
              grandTotal: grandTotal,
              received: received,
              change: changeAmount,
              customer: customer,
            );

            if (imageBytes == null) throw Exception("Failed to generate receipt image");

            final base64Image = base64Encode(imageBytes);
            
            final apiUrl = SettingsService().apiUrl;
            final url = Uri.parse('$apiUrl/api/v1/line/push-receipt-image');
            final body = jsonEncode({
              'lineUserId': lineUserId,
              'orderId': orderId.toString(),
              'imageBase64': base64Image,
              'amount': grandTotal.toStringAsFixed(2)
            });

            await _sendWithRetry(
              db: db,
              orderId: orderId,
              lineUserId: lineUserId,
              messageType: type,
              content: content,
              url: url,
              body: body,
              existingLogId: id,
            );
            
            continue;
          } catch (e) {
            await repo.markAsFailed(id, 'Failed to recreate receipt: $e');
            continue;
          }
        }

        final apiUrl = SettingsService().apiUrl;
        Uri url;
        String body;

        if (type == 'IMAGE') {
          url = Uri.parse('$apiUrl/line/push-image');
          body = jsonEncode({'lineUserId': lineUserId, 'filename': content});
        } else {
          url = Uri.parse('$apiUrl/line/push-message');
          body = jsonEncode({'lineUserId': lineUserId, 'message': content});
        }

        await _sendWithRetry(
          db: db,
          orderId: int.tryParse(log['order_id']?.toString() ?? '0') ?? 0,
          lineUserId: lineUserId,
          messageType: type,
          content: content,
          url: url,
          body: body,
          existingLogId: id,
        );
      } catch (e) {
        LoggerService.error('FirebaseMessaging', 'Error processing pending log', e);
      }
    }
  }

  /// Sends standard text message directly (with preset LineUserID) + logs.
  Future<bool> sendLineNotificationDirect({
    required MySQLService db,
    required int orderId,
    required String lineUserId,
    required String message,
  }) async {
    final apiUrl = SettingsService().apiUrl;
    final Uri url = Uri.parse('$apiUrl/line/push-message');
    final body = jsonEncode({'lineUserId': lineUserId, 'message': message});

    return await _sendWithRetry(
      db: db,
      orderId: orderId,
      lineUserId: lineUserId,
      messageType: 'TEXT',
      content: message,
      url: url,
      body: body,
    );
  }

  /// Sends receipt image base64 directly + logs.
  Future<bool> sendLineReceiptImageDirect({
    required MySQLService db,
    required int orderId,
    required String lineUserId,
    required Uri url,
    required String base64Image,
  }) async {
    String baseUrl = SettingsService().apiUrl;
    if (baseUrl.endsWith('/api/v1')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 7);
    } else if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    final body = jsonEncode({
      'lineUserId': lineUserId,
      'orderId': orderId.toString(),
      'image': base64Image,
      'baseUrl': baseUrl,
    });

    return await _sendWithRetry(
      db: db,
      orderId: orderId,
      lineUserId: lineUserId,
      messageType: 'RECEIPT_IMAGE',
      content: 'receipt_image_order_$orderId',
      url: url,
      body: body,
      timeout: const Duration(seconds: 30),
    );
  }
}
