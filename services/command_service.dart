import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// import '../repositories/sales_repository.dart';
// import 'receipt_service.dart';
// import '../models/order_item.dart';
// import '../models/customer.dart';

class CommandService {
  static final CommandService _instance = CommandService._internal();
  factory CommandService() => _instance;
  CommandService._internal();

  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _commandSubscription;
  String? _deviceId;

  // Getter for Device ID
  Future<String> get deviceId async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_uuid');

    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString('device_uuid', _deviceId!);
      debugPrint('🆕 Generated New Device ID: $_deviceId');
    } else {
      debugPrint('🆔 Loaded Device ID: $_deviceId');
    }
    return _deviceId!;
  }

  // Start Listening for Commands (Disabled to save Firebase Costs)
  Future<void> startListening() async {
    /*
    final devId = await deviceId;

    debugPrint('🎧 Listening for commands for Device: $devId');

    _commandSubscription?.cancel();
    _commandSubscription = _firestore
        .collection('commands')
        .where('target_device_id', isEqualTo: devId)
        .where('status', isEqualTo: 'PENDING') // Only pending commands
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _processCommand(change.doc);
        }
      }
    }, onError: (e) {
      debugPrint('🔥 Command Listener Error: $e');
    });
    */
  }

  void stopListening() {
    _commandSubscription?.cancel();
    debugPrint('🛑 Stopped Command Listener');
  }

  /*
  Future<void> _processCommand(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final String cmd = data['command'] ?? 'UNKNOWN';
    final String docId = doc.id;

    debugPrint('🚀 Received Command: $cmd (ID: $docId)');

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
      debugPrint('❌ Command Execution Failed: $e');
      resultMessage = 'Error: $e';
    }

    // Update Status in Firestore
    await _updateCommandStatus(
        docId, success ? 'COMPLETED' : 'FAILED', resultMessage);
  }

  Future<void> _handleOpenDrawer(Map<String, dynamic> data) async {
    // Emulate drawer opening log
    debugPrint('🖨️ [Command] Opening Cash Drawer...');
    // Future: Integrate with PrinterService if direct command available
  }

  Future<void> _handleReprint(Map<String, dynamic> data) async {
    final orderId = data['payload']?['order_id'];
    if (orderId == null) throw Exception('Missing order_id in payload');

    debugPrint('🖨️ [Command] Reprinting Order #$orderId');

    final salesRepo = SalesRepository();
    final orderData = await salesRepo.getOrderWithItems(orderId);

    if (orderData == null) {
      throw Exception('Order #$orderId not found locally');
    }

    final Map<String, dynamic> order = orderData['order'];
    final List<OrderItem> items = orderData['items'] as List<OrderItem>;

    // Construct Customer object if data exists
    Customer? customer;
    if (order['customerId'] != null && order['customerId'] > 0) {
      customer = Customer(
          id: order['customerId'],
          firstName: order['firstName'] ?? 'Customer',
          lastName: order['lastName'],
          phone: order['phone'],
          memberCode: '', // Not critical for receipt
          currentPoints: 0);
    }

    final receiptService = ReceiptService();

    // Print!
    await receiptService.printReceipt(
      orderId: orderId,
      items: items,
      total: double.tryParse(order['total'].toString()) ?? 0.0,
      discount: double.tryParse(order['discount'].toString()) ?? 0.0,
      grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0.0,
      received: 0, // Reprint doesn't show payment details usually
      change: 0,
      customer: customer,
      // printerOverride: null // Use default
    );
  }

  Future<void> _updateCommandStatus(
      String docId, String status, String? message) async {
    try {
      await _firestore.collection('commands').doc(docId).update({
        'status': status,
        'result_message': message,
        'executed_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Failed to update command status: $e');
    }
  }
  */
}
