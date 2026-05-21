import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'mysql_service.dart';

import '../repositories/sales_repository.dart';
import 'printing/receipt_service.dart';
import '../models/order_item.dart';
import '../models/customer.dart';

class CommandService {
  static final CommandService _instance = CommandService._internal();
  factory CommandService() => _instance;
  CommandService._internal();

  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('⚠️ FirebaseFirestore not ready: $e');
      rethrow;
    }
  }

  StreamSubscription<QuerySnapshot>? _commandSubscription;
  StreamSubscription<QuerySnapshot>? _masterCommandSubscription; // [Added]
  String? _deviceId;

  // Getter for Device ID
  Future<String> get deviceId async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_uuid');

    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString('device_uuid', _deviceId!);
      debugPrint('[NEW] Generated New Device ID: $_deviceId');
    } else {
      debugPrint('[INFO] Loaded Device ID: $_deviceId');
    }
    return _deviceId!;
  }

  Timer? _pollingTimer;

  // Start Listening for Commands from S-Link (Polled to avoid Windows C++ SDK crashes)
  Future<void> startListening() async {
    if (kIsWeb) return;

    final devId = await deviceId;

    debugPrint('[LISTEN] Polling for commands for Device: $devId');

    stopListening(); // Ensure clean start

    if (defaultTargetPlatform == TargetPlatform.windows) {
      // [Windows] Use Local MySQL Polling (Free, Fast, No Firebase Reads)
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final mysql = MySQLService();
          if (!mysql.isConnected()) return;

          final query = '''
            SELECT * FROM pos_commands 
            WHERE status = 'PENDING' 
              AND (target_device_id = :devId OR target_device_id = 'POS_MASTER')
              AND created_at >= NOW() - INTERVAL 5 MINUTE
            LIMIT 10
          ''';
          
          final pendingCmds = await mysql.query(query, {'devId': devId});
          
          for (var cmdData in pendingCmds) {
            debugPrint(
                '⚡ [POS] Received Local Command: ${cmdData['command']} (ID: ${cmdData['id']})');
            await _processCommandRest(Map<String, dynamic>.from(cmdData));
          }
        } catch (e) {
          debugPrint('[ERROR] Windows Command Polling Error: $e');
        }
      });
    } else {
      // [Mobile] Use Firestore SDK Snapshots (Real-time Sockets = NO Polling = Very Low Cost)
      _commandSubscription = _firestore
          .collection('commands')
          .where('target_device_id', isEqualTo: devId)
          .where('status', isEqualTo: 'PENDING')
          .snapshots()
          .listen((snapshot) async {
        for (var doc in snapshot.docs) {
          debugPrint('[CMD] Received Direct Command: ${doc.id}');
          await _processCommand(doc);
        }
      }, onError: (e) => debugPrint('[ERROR] Direct Command Stream Error: $e'));

      _masterCommandSubscription = _firestore
          .collection('commands')
          .where('target_device_id', isEqualTo: 'POS_MASTER')
          .where('status', isEqualTo: 'PENDING')
          .snapshots()
          .listen((snapshot) async {
        for (var doc in snapshot.docs) {
          debugPrint('[CMD] Received MASTER Command: ${doc.id}');
          await _processCommand(doc);
        }
      }, onError: (e) => debugPrint('[ERROR] Master Command Stream Error: $e'));
    }
  }

  void stopListening() {
    _commandSubscription?.cancel();
    _masterCommandSubscription?.cancel();
    _pollingTimer?.cancel();
    debugPrint('[STOP] Stopped Command Polling');
  }

  Future<void> _processCommand(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final String cmd = data['command'] ?? 'UNKNOWN';
    final String docId = doc.id;

    // [Claim Lock] Use Firestore Transaction to change status from PENDING -> PROCESSING
    // Atomic operation to prevent 2 Listeners from processing the same command (Race Condition)
    bool claimed = false;
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('commands').doc(docId);
        final freshDoc = await transaction.get(docRef);

        // If status is not PENDING (already claimed), abort.
        if (freshDoc.data()?['status'] != 'PENDING') {
          return; // Transaction สำเร็จ แต่ไม่ได้ Claim
        }

        // Claim Success: Update status to PROCESSING
        transaction.update(docRef, {
          'status': 'PROCESSING',
          'claimed_at': FieldValue.serverTimestamp(),
        });
        claimed = true;
      });
    } catch (e) {
      debugPrint('[WARN] Could not claim command $docId (already claimed): $e');
      return; // ออกไปเลย ปล่อยให้ Listener อื่น Process
    }

    if (!claimed) {
      debugPrint(
          '[SKIP] Skipping command $docId (already claimed by another listener)');
      return;
    }

    debugPrint('[PROCESS] Processing Command: $cmd (ID: $docId)');

    bool success = false;
    String? resultMessage;

    try {
      switch (cmd) {
        case 'OPEN_DRAWER':
          await _handleOpenDrawer(data);
          success = true;
          resultMessage = 'Drawer Opened';
          break;
        case 'PRINT_RECEIPT':
          await _handleReprint(data);
          success = true;
          resultMessage = 'Reprint Triggered';
          break;
        case 'PING':
          success = true;
          resultMessage = 'Pong! (Online)';
          break;
        default:
          resultMessage = 'Unknown Command';
          break;
      }
    } catch (e) {
      debugPrint('[ERROR] Command Execution Failed: $e');
      resultMessage = 'Error: $e';
    }

    // Update Final Status in Firestore
    await _updateCommandStatus(
        docId, success ? 'COMPLETED' : 'FAILED', resultMessage);
  }

  Future<void> _handleOpenDrawer(Map<String, dynamic> data) async {
    debugPrint('[PRINT] [Command] Opening Cash Drawer...');
  }

  Future<void> _handleReprint(Map<String, dynamic> data) async {
    final orderId = data['payload']?['order_id'];
    if (orderId == null) throw Exception('Missing order_id in payload');

    debugPrint('[PRINT] [Command] Reprinting Order #$orderId');

    final salesRepo = SalesRepository();

    // [Retry] Use Retry Mechanism to prevent "Order Not Found" race condition (Restored)
    final orderData = await _fetchOrderWithRetry(salesRepo, orderId);

    if (orderData == null) {
      debugPrint('[ERROR] [Command] Order #$orderId not found after retries.');
      throw Exception('Order #$orderId not found locally');
    }

    final Map<String, dynamic> order = orderData['order'];
    final List<OrderItem> items = orderData['items'] as List<OrderItem>;

    // Construct Customer object if data exists
    Customer? customer;
    final rawId = order['customerId'];
    int? customerIdInt;

    if (rawId != null) {
      if (rawId is int) {
        customerIdInt = rawId;
      } else if (rawId is String) {
        customerIdInt = int.tryParse(rawId);
      }
    }

    if (customerIdInt != null && customerIdInt > 0) {
      customer = Customer(
          id: customerIdInt,
          firstName: order['firstName'] ?? 'Customer',
          lastName: order['lastName'],
          phone: order['phone'],
          memberCode: '',
          currentPoints: 0,
          lineUserId: order['line_user_id']); // [Info] Populate Line User ID
    }

    final receiptService = ReceiptService();

    // Print!
    await receiptService.printReceipt(
      orderId: orderId,
      items: items,
      total: double.tryParse(order['total'].toString()) ?? 0.0,
      discount: double.tryParse(order['discount'].toString()) ?? 0.0,
      grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0.0,
      received: 0,
      change: 0,
      customer: customer,
    );

    // ---------------------------------------------------------
    // [Line OA] Generate & Send Receipt Image
    // ---------------------------------------------------------
    if (customer?.lineUserId != null && customer!.lineUserId!.isNotEmpty) {
      try {
        debugPrint('[IMAGE] Generating Receipt Image for Line OA...');
        final imageBytes = await receiptService.captureReceiptImage(
          orderId: orderId,
          items: items,
          total: double.tryParse(order['total'].toString()) ?? 0.0,
          grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0.0,
          received: double.tryParse(order['grandTotal'].toString()) ?? 0.0,
          change: 0,
          customer: customer,
        );

        if (imageBytes != null) {
          final base64Image = base64Encode(imageBytes);
          final url =
              Uri.parse('http://localhost:8080/api/v1/line/push-receipt-image');

          debugPrint('[SEND] Sending Receipt Image to Backend...');
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lineUserId': customer.lineUserId,
              'orderId': orderId.toString(),
              'image': base64Image,
            }),
          );

          if (response.statusCode == 200) {
            debugPrint('[SUCCESS] Receipt Image sent to Line OA successfully.');
          } else {
            debugPrint(
                '[ERROR] Failed to send Receipt Image: ${response.statusCode} - ${response.body}');
          }
        }
      } catch (e) {
        debugPrint('[WARN] Error sending Line Receipt Image: $e');
      }
    }
    // ---------------------------------------------------------
  }

  Future<Map<String, dynamic>?> _fetchOrderWithRetry(
      SalesRepository repo, int orderId) async {
    for (int i = 0; i < 3; i++) {
      try {
        final orderData = await repo.getOrderWithItems(orderId);
        if (orderData != null) {
          return orderData;
        }
        debugPrint(
            '[WARN] Order #$orderId not found, retrying... (${i + 1}/3)');
      } catch (e) {
        debugPrint('[WARN] Error fetching order #$orderId: $e');
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<void> _updateCommandStatus(
      String docId, String status, String? message) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final mysql = MySQLService();
        await mysql.execute(
          '''
          UPDATE pos_commands 
          SET status = :status, result_message = :msg, executed_at = NOW() 
          WHERE id = :id
          ''',
          {
            'status': status, 
            'msg': message, 
            'id': docId
          }
        );
      } else {
        await _firestore.collection('commands').doc(docId).update({
          'status': status,
          'result_message': message,
          'executed_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[ERROR] Failed to update command status: $e');
    }
  }

  // ✅ New Method for Windows Local MySQL processing
  Future<void> _processCommandRest(Map<String, dynamic> data) async {
    final String docId = data['id'].toString();
    final String cmd = data['command'] ?? 'UNKNOWN';

    // Parse payload if it's a JSON string from MySQL
    if (data['payload'] is String) {
      try {
        data['payload'] = jsonDecode(data['payload']);
      } catch (e) {
        data['payload'] = {};
      }
    }

    // Claim Lock via Local MySQL (Atomic UPDATE)
    try {
      final mysql = MySQLService();
      final result = await mysql.execute(
        '''
        UPDATE pos_commands 
        SET status = 'PROCESSING', claimed_at = NOW() 
        WHERE id = :id AND status = 'PENDING'
        ''',
        {'id': docId}
      );
      
      if (result.affectedRows == BigInt.zero) {
        debugPrint('[WARN] Could not claim local command $docId (already claimed)');
        return;
      }
    } catch (e) {
      debugPrint('[WARN] Error claiming local command $docId: $e');
      return;
    }

    debugPrint('[PROCESS-REST] Processing Command: $cmd (ID: $docId)');

    bool success = false;
    String? resultMessage;

    try {
      switch (cmd) {
        case 'OPEN_DRAWER':
          await _handleOpenDrawer(data);
          success = true;
          resultMessage = 'Drawer Opened';
          break;
        case 'PRINT_RECEIPT':
          await _handleReprint(data);
          success = true;
          resultMessage = 'Reprint Triggered';
          break;
        case 'PING':
          success = true;
          resultMessage = 'Pong! (Online)';
          break;
        default:
          resultMessage = 'Unknown Command';
          break;
      }
    } catch (e) {
      debugPrint('[ERROR] Command Execution Failed: $e');
      resultMessage = 'Error: $e';
    }

    // Update Final Status via REST
    await _updateCommandStatus(
        docId, success ? 'COMPLETED' : 'FAILED', resultMessage);
  }
}
