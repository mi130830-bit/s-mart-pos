import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'local_db_service.dart';
import 'api_service.dart';
import '../models/schema/order_collection.dart';
import '../models/schema/product_collection.dart';
import 'settings_service.dart';
import 'customer_display_service.dart';

class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final int pendingOrders;
  final DateTime? lastSyncTime;
  final String? lastError;

  SyncStatus({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingOrders = 0,
    this.lastSyncTime,
    this.lastError,
  });

  SyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingOrders,
    DateTime? lastSyncTime,
    String? lastError,
  }) {
    return SyncStatus(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: lastError, // Nullable, can reset error
    );
  }
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;

  // Stream for UI
  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _currentStatus = SyncStatus();

  void _updateStatus({
    bool? isOnline,
    bool? isSyncing,
    int? pendingOrders,
    DateTime? lastSyncTime,
    String? lastError,
  }) {
    _currentStatus = _currentStatus.copyWith(
      isOnline: isOnline,
      isSyncing: isSyncing,
      pendingOrders: pendingOrders,
      lastSyncTime: lastSyncTime,
      lastError: lastError,
    );
    _statusController.add(_currentStatus);
  }

  void startSyncLoop() {
    _syncTimer?.cancel();
    debugPrint('🔄 SyncService: Started background sync loop (every 2 mins)');

    // Refresh pending count on start
    _refreshPendingCount();

    // Initial Sync
    syncAll();

    // Loop
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      syncAll();
    });
  }

  void stopSyncLoop() {
    _syncTimer?.cancel();
    debugPrint('⏹️ SyncService: Stopped background sync');
  }

  Future<void> _refreshPendingCount() async {
    final db = LocalDbService().db;
    final count =
        await db.orderCollections.filter().isSyncedEqualTo(false).count();
    _updateStatus(pendingOrders: count);
  }

  Future<void> syncAll() async {
    if (_currentStatus.isSyncing) return;
    _updateStatus(
        isSyncing: true, lastError: null); // Clear previous error on start

    try {
      // 1. Check Connectivity (Basic check via simplified ping or just try push)
      // For now, we assume online and let the operations fail if offline.

      await pushOrders();
      await pullProducts();

      // ✅ Pull global settings from MySQL so clients update automatically
      // when the master machine changes settings (e.g. QR Code, Shop Name)
      await SettingsService().loadSettings();
      CustomerDisplayService().reloadSettings(); // สั่งให้หน้าจอลูกค้าโหลดรูป QR ใหม่ทันที

      _updateStatus(
        isOnline: true,
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        lastError: null,
      );
    } catch (e) {
      debugPrint('⚠️ SyncService Error: $e');
      _updateStatus(
        isOnline: false,
        isSyncing: false,
        lastError: e.toString(),
      );
    }
  }

  // --- PUSH: Send Local Orders to Server ---
  Future<void> pushOrders() async {
    final db = LocalDbService().db;

    // Find unsynced orders
    final unsyncedOrders =
        await db.orderCollections.filter().isSyncedEqualTo(false).findAll();

    _updateStatus(pendingOrders: unsyncedOrders.length);

    if (unsyncedOrders.isEmpty) return;

    debugPrint('📤 SyncService: Pushing ${unsyncedOrders.length} orders...');

    for (final order in unsyncedOrders) {
      try {
        final payload = jsonDecode(order.payload);

        // Post to API
        await ApiService().post('/orders', payload);

        await db.writeTxn(() async {
          order.isSynced = true;
          order.error = null;
          await db.orderCollections.put(order);
        });

        debugPrint('✅ Synced Order ID: ${order.id}');

        // Update pending count immediately
        _refreshPendingCount();
      } catch (e) {
        debugPrint('❌ Failed to sync Order ID ${order.id}: $e');
        await db.writeTxn(() async {
          order.error = e.toString();
          await db.orderCollections.put(order);
        });
        // Rethrow to mark sync as failed/offline in syncAll
        throw Exception('Failed to push order: $e');
      }
    }
  }

  // --- PULL: Get Products from Server (Incremental) ---
  Future<void> pullProducts() async {
    debugPrint('📥 SyncService: Pulling products...');
    final db = LocalDbService().db;

    // Find latest update time
    final latestProduct =
        await db.productCollections.where().sortByLastUpdatedDesc().findFirst();

    final lastUpdated = latestProduct?.lastUpdated.toIso8601String();

    // Add query param if exists
    final queryParams = lastUpdated != null ? '?lastUpdated=$lastUpdated' : '';

    try {
      // We still handle pagination just in case, but usually incremental is small
      int page = 1;
      bool hasMore = true;

      // If we are doing full pull (no lastUpdated), we might want to be careful.
      // But for incremental, it should be fine.

      while (hasMore) {
        // Construct URL
        final endpoint =
            '/products$queryParams${queryParams.isEmpty ? '?' : '&'}page=$page&limit=100';

        final List<dynamic> productsJson = await ApiService().get(endpoint);

        if (productsJson.isEmpty) {
          hasMore = false;
          break;
        }

        await db.writeTxn(() async {
          for (final json in productsJson) {
            final remoteId = json['id'];
            final barcode = json['barcode'] ?? '';

            // Check existence by Barcode or Remote ID
            // Ideally Remote ID is better if we have it.
            ProductCollection? existing;

            if (remoteId != null) {
              existing = await db.productCollections
                  .filter()
                  .remoteIdEqualTo(remoteId)
                  .findFirst();
            }

            if (existing == null && barcode.isNotEmpty) {
              existing = await db.productCollections
                  .filter()
                  .barcodeEqualTo(barcode)
                  .findFirst();
            }

            final p = existing ?? ProductCollection();
            p.remoteId = remoteId;
            p.barcode = barcode;
            p.name = json['name'] ?? 'Unknown';
            p.price = double.tryParse(json['price'].toString()) ?? 0.0;
            p.costPrice = double.tryParse(json['costPrice'].toString());
            p.stock = int.tryParse(json['stockQuantity'].toString()) ?? 0;
            p.imagePath = json['imagePath'];
            p.categoryId = json['categoryId']?.toString();
            // Use server timestamp if available, else now
            p.lastUpdated = json['updatedAt'] != null
                ? DateTime.parse(json['updatedAt'])
                : DateTime.now();

            await db.productCollections.put(p);
          }
        });

        debugPrint('📥 Pulled Page $page (${productsJson.length} items)');
        page++;
      }
    } catch (e) {
      debugPrint('⚠️ SyncService Pull Error: $e');
      throw Exception('Failed to pull products: $e');
    }
  }
}
