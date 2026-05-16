import 'package:firedart/firedart.dart';
import 'dart:io';

/// Firebase Configuration Service
/// Initialize Firestore connection for syncing orders
class FirebaseConfig {
  static Firestore? _firestore;
  static bool _initialized = false;

  static Future<Firestore> get firestore async {
    if (!_initialized) {
      await _initialize();
    }
    return _firestore!;
  }

  static Future<void> _initialize() async {
    if (_initialized) return;

    const projectId = 'opsmate-3dde2'; // Replace with your Firebase Project ID

    // Initialize Firestore
    Firestore.initialize(projectId);
    _firestore = Firestore.instance;

    _initialized = true;
    stdout.writeln('✅ Firebase initialized: $projectId');
  }

  /// Sync Order to Firestore for Cloud Functions trigger
  static Future<void> syncOrderToFirestore({
    required int orderId,
    required int customerId,
    required double grandTotal,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    try {
      final db = await firestore;

      await db.collection('orders').document(orderId.toString()).set({
        'orderId': orderId,
        'customerId': customerId,
        'grandTotal': grandTotal,
        'paymentMethod': paymentMethod,
        'itemCount': items.length,
        'items': items,
        'note': note, // "Deliver to address" or "Pickup at store"
        'createdAt': DateTime.now().toIso8601String(),
        'source': 'POS', // POS Desktop or POS Web
      });

      stdout.writeln('✅ Order #$orderId synced to Firestore');
    } catch (e) {
      stderr.writeln('⚠️ Failed to sync Order to Firestore: $e');
      // Don't throw - MySQL transaction already completed
    }
  }
}
