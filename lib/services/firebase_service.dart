import 'package:flutter/foundation.dart';
import 'firestore_rest_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../models/order_item.dart';
import '../services/settings_service.dart';
import 'mysql_service.dart';
import 'logger_service.dart';
import 'firebase/firebase_storage_service.dart';
import 'firebase/firebase_messaging_service.dart';

class FirebaseService {
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final FirebaseMessagingService _messagingService = FirebaseMessagingService();

  // 0. Upload Bill Image to Storage (Delegated)
  Future<String?> uploadBillImage(Uint8List imageData, String jobId) async {
    return await _storageService.uploadBillImage(imageData, jobId);
  }

  // Use a getter to avoid throwing 'core/no-app' if Firebase isn't initialized yet
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      LoggerService.error('FirebaseService', 'FirebaseFirestore not ready', e);
      rethrow;
    }
  }

  // เก็บ Subscription เพื่อให้หยุดฟังได้เมื่อเลิกใช้
  StreamSubscription<QuerySnapshot>? _jobSubscription;

  // 1. Sync Customer Points to Cloud (อัปเดตแต้ม)
  Future<void> updateCustomerPoints({
    required String firebaseUid,
    required int newTotalPoints,
  }) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await FirestoreRestService.updateDocument(
          'users', 
          firebaseUid, 
          {
            'currentPoints': newTotalPoints,
            'lastUpdated': DateTime.now(),
          }
        );
      } else {
        // ✅ ใช้ set(..., merge: true) แทน update() เพื่อให้สร้างเอกสารได้ถ้ายังไม่มี
        await _firestore.collection('users').doc(firebaseUid).set({
          'currentPoints': newTotalPoints,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      LoggerService.info('FirebaseService', 'Synced points for $firebaseUid: $newTotalPoints');
    } catch (e) {
      LoggerService.error('FirebaseService', 'Failed to sync points to Firebase', e);
    }
  }

  // 2. Create Delivery Job in Cloud (สร้างงานส่งของ)
  Future<String?> createDeliveryJob({
    required int localOrderId,
    required Customer customer,
    required List<OrderItem> items,
    required double grandTotal,
    required MySQLService dbService,
    String? note,
    List<String>? billImageUrls, // ✅ เพิ่มรายการรูปบิล
    String jobType = 'delivery', // ✅ Added jobType with default
    double vatAmount = 0.0, // ✅ Added VAT Amount
    String status = 'pending', // ✅ Added status (default pending)
    String paymentMethod = 'cash', // ✅ Added paymentMethod to differentiate COD
  }) async {
    try {
      // 2.1 Sync Customer First (ประหยัด Read/Write ด้วยการเช็ค local ก่อน)
      final String firebaseUid =
          await _ensureCustomerSynced(customer, dbService);

      // 2.2 Create Job with Correct Fields for S_link
      // Filter Items based on Setting
      final bool filterEnabled = SettingsService().enableWarehouseAutoTag;
      List<OrderItem> jobItems = items;

      if (filterEnabled) {
        // ✅ Fix: Force Check 'isWarehouseItem' from MySQL (Bypass Isar Cache)
        Set<int> warehouseProductIds = {};

        try {
          final pIds = items.map((i) => i.productId).toList();
          if (pIds.isNotEmpty) {
            final idsStr = pIds.join(',');
            // Fetch real flags from DB
            final res = await dbService.query(
                'SELECT id FROM product WHERE id IN ($idsStr) AND isWarehouseItem = 1');
            warehouseProductIds =
                res.map((r) => int.parse(r['id'].toString())).toSet();
          }
        } catch (e) {
          LoggerService.error('FirebaseService', 'Failed to fetch warehouse flags from MySQL', e);
          // Fallback to item property if DB fails
          warehouseProductIds = items
              .where((i) => i.product?.isWarehouseItem == true)
              .map((i) => i.productId)
              .toSet();
        }

        // Filter using the fresh set of IDs
        final warehouseItems = items.where((i) {
          // warehouseProductIds contains IDs that are confirmed 100% to be warehouse items
          return warehouseProductIds.contains(i.productId);
        }).toList();

        // Apply Logic
        if (warehouseItems.isNotEmpty) {
          jobItems = warehouseItems;
          // Update item objects to have correct flag locally for this payload
          jobItems = jobItems.map((i) {
            if (i.product != null) {
              // Return copy with forced flag true (since we confirmed it from DB)
              // We need to ensure OrderItem.product is mutable or use copyWith
              return i.copyWith(
                  product: i.product!.copyWith(isWarehouseItem: true));
            }
            return i;
          }).toList();
        } else {
          // Fallback logic remains same
        }
      }

      // details: แปลงรายการสินค้าเป็น String ยาวๆ
      String details = jobItems.map((i) {
        String txt =
            '${i.productName} x${i.quantity}${i.comment.isNotEmpty ? " (${i.comment})" : ""}';
        if (i.product?.shelfLocation != null &&
            i.product!.shelfLocation!.isNotEmpty) {
          txt += ' [เก็บ: ${i.product!.shelfLocation}]';
        }
        return txt.trim();
      }).join('\n');

      // If we filtered items, maybe add a note?
      if (filterEnabled && jobItems.length < items.length) {
        details +=
            '\n📦 มีของหน้าร้าน ${items.length - jobItems.length} จำนวนรายการ';
      }

      // ✅ แทรกหมายเหตุ (เช่น "จ่ายเงินแล้ว") ไว้ด้านบนสุด
      if (note != null && note.isNotEmpty) {
        details = '$note\n━━━━━━━━━━━━━━━━━━\n$details';
      }

      final jobPayload = {
        'localOrderId': localOrderId,
        'order_id': localOrderId, // ✅ REQUIRED for Backend/Line Notify
        'status': status, // ✅ Use param
        'job_type': jobType, // ✅ เพิ่ม job_type
        'created_at': DateTime.now(),
        'completed_at': status == 'completed' ? DateTime.now() : null, // ✅ Set completed_at if needed
        'created_by': 'POS System', // เพิ่มตาม Request
        'payment_method': paymentMethod, // ✅ Send paymentMethod to Firestore
        'customer_id': firebaseUid, // เชื่อมโยงกับ ID ที่ Sync แล้ว
        'customer': {
          'name': '${customer.firstName} ${customer.lastName ?? ""}'.trim(),
          'phoneNumber': customer.phone ?? '', // ✅ แก้ key เป็น phoneNumber ตาม S_link
          'address': customer.shippingAddress ?? customer.address ?? '',
          'location': null, // ยังไม่มีพิกัดจาก POS
          'line_user_id': customer.lineUserId, // ✅ เพิ่มเพื่อให้ Cloud Functions ส่งแจ้งเตือน Stage 2/3 ได้
        },
        'details': details, // ✅ เพิ่ม details (Filtered with Shelf)
        'items': jobItems // ✅ Use Filtered Items
            .map((item) => {
                  'name': item.productName,
                  'qty': item.quantity.toDouble(), // Convert Decimal to double
                  'price': item.price.toDouble(), // Convert Decimal to double
                  'total': item.total.toDouble(), // Convert Decimal to double
                  'location': item.product?.shelfLocation ?? '', // ✅ Send Shelf Location
                  'is_warehouse': item.product?.isWarehouseItem ?? false, // ✅ Send Flag
                })
            .toList(),
        'price': grandTotal, // Price is ALWAYS full amount
        'vat': vatAmount, // ✅ Added VAT Amount for S-Link
        'delivery_team': [], // ✅ ส่ง delivery_team ว่าง
        'is_departure_approved': false,
        'bill_image_urls': billImageUrls ?? [], // ✅ แนบรูปบิล
      };

      String? docId;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        docId = await FirestoreRestService.createDocument('jobs', jobPayload);
      } else {
        jobPayload['created_at'] = FieldValue.serverTimestamp();
        jobPayload['completed_at'] = status == 'completed' ? FieldValue.serverTimestamp() : null;
        final docRef = await _firestore.collection('jobs').add(jobPayload);
        docId = docRef.id;
      }

      LoggerService.info('FirebaseService', 'Created Cloud Job: $docId for Cust: $firebaseUid');
      return docId;
    } catch (e) {
      LoggerService.error('FirebaseService', 'Failed to create Cloud Job', e);
      return null;
    }
  }

  // 3. Update Job (ใช้สำหรับแนบรูปทีหลัง)
  Future<void> updateJob(String jobId, Map<String, dynamic> updates) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await FirestoreRestService.updateDocument('jobs', jobId, updates);
      } else {
        await _firestore.collection('jobs').doc(jobId).update(updates);
      }
      LoggerService.info('FirebaseService', 'Updated Cloud Job: $jobId');
    } catch (e) {
      LoggerService.error('FirebaseService', 'Failed to update Cloud Job', e);
    }
  }

  // ✅ New Method: Fetch Stock Check Jobs (Sync from Cloud)
  Future<List<Map<String, dynamic>>> fetchStockCheckJobs() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return await FirestoreRestService.fetchStockCheckJobs();
    }
    
    try {
      // Pull last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final query = await _firestore
          .collection('jobs')
          .where('created_at', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Include Doc ID
        // Helper to convert Timestamp to DateTime
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate();
        }
        return data;
      }).toList();
    } catch (e) {
      LoggerService.error('FirebaseService', 'Fetch Cloud Jobs Error', e);
      return [];
    }
  }

  // ✅ New Method: Fetch Shop Work Logs (Backoffice History)
  Future<List<Map<String, dynamic>>> fetchShopWorkLogs() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return await FirestoreRestService.fetchShopWorkLogs();
    }
    
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final query = await _firestore
          .collection('shop_work_logs') // Correct Collection from S-Link
          .where('logged_at',
              isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('logged_at', descending: true)
          .limit(20)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Map 'logged_at' to 'created_at' for consistency in UI
        if (data['logged_at'] is Timestamp) {
          data['created_at'] = (data['logged_at'] as Timestamp).toDate();
        }
        // Ensure items is a list
        if (data['items'] == null) data['items'] = [];
        return data;
      }).toList();
    } catch (e) {
      LoggerService.error('FirebaseService', 'Fetch Shop Work Logs Error', e);
      return [];
    }
  }

  // Helper: ตรวจสอบและ Sync ลูกค้า (POS <-> Firestore)
  Future<String> _ensureCustomerSynced(
      Customer customer, MySQLService dbService) async {
    // 1. ถ้ามี ID เดิมอยู่แล้ว ให้ใช้เลย (0 Read)
    if (customer.firebaseUid != null && customer.firebaseUid!.isNotEmpty) {
      return customer.firebaseUid!;
    }

    // 2. ถ้าไม่มี -> ค้นหาจากเบอร์โทร (1 Read)
    final phone = customer.phone ?? '';
    if (phone.isEmpty) {
      return _createNewFirestoreCustomer(customer, dbService);
    }

    try {
      String? docId;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        docId = await FirestoreRestService.findCustomerByPhone(phone);
      } else {
        final query = await _firestore
            .collection('customers')
            .where('phone_number', isEqualTo: phone)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          docId = query.docs.first.id;
        }
      }

      if (docId != null) {
        // 3. เจอในระบบ -> ดึง ID มาใช้ และบันทึกลง Local MySQL
        LoggerService.info('FirebaseService', 'Found existing customer on cloud: $docId');

        await _updateLocalCustomerFirebaseUid(
            dbService, customer.id, docId); // Save to Local

        if (customer.lineUserId != null) {
          if (defaultTargetPlatform == TargetPlatform.windows) {
            await FirestoreRestService.updateDocument('customers', docId, {
              'line_user_id': customer.lineUserId,
              'line_display_name': customer.lineDisplayName,
              'line_picture_url': customer.linePictureUrl
            });
          } else {
            await _firestore.collection('customers').doc(docId).update({
              'line_user_id': customer.lineUserId,
              'line_display_name': customer.lineDisplayName,
              'line_picture_url': customer.linePictureUrl
            });
          }
          LoggerService.info('FirebaseService', 'Synced Line User ID to Cloud Customer');
        }

        return docId;
      } else {
        // 4. ไม่เจอ -> สร้างใหม่
        return _createNewFirestoreCustomer(customer, dbService);
      }
    } catch (e) {
      LoggerService.error('FirebaseService', 'Find Customer Error', e);
      return _createNewFirestoreCustomer(customer, dbService);
    }
  }

  Future<String> _createNewFirestoreCustomer(
      Customer customer, MySQLService dbService) async {
    try {
      final payload = {
        'name': '${customer.firstName} ${customer.lastName ?? ""}'.trim(),
        'phone_number': customer.phone ?? '',
        'address': customer.address ?? '',
        'is_active': true,
        'from_source': 'POS',
        'line_user_id': customer.lineUserId, // ✅ Sync Line ID
        'line_display_name': customer.lineDisplayName,
        'line_picture_url': customer.linePictureUrl
      };

      String? docId;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        payload['created_at'] = DateTime.now();
        docId = await FirestoreRestService.createDocument('customers', payload);
      } else {
        payload['created_at'] = FieldValue.serverTimestamp();
        final docRef = await _firestore.collection('customers').add(payload);
        docId = docRef.id;
      }

      if (docId == null) throw Exception('Failed to create customer');

      LoggerService.info('FirebaseService', 'Created new customer on cloud: $docId');

      // Save ID back to Local MySQL
      await _updateLocalCustomerFirebaseUid(dbService, customer.id, docId);

      return docId;
    } catch (e) {
      LoggerService.error('FirebaseService', 'Create Customer Error', e);
      return 'POS_TEMP_${DateTime.now().millisecondsSinceEpoch}'; // Fallback ID
    }
  }

  Future<void> _updateLocalCustomerFirebaseUid(
      MySQLService db, int localId, String firebaseUid) async {
    try {
      await db.execute(
        'UPDATE customer SET firebaseUid = :uid WHERE id = :id',
        {'uid': firebaseUid, 'id': localId},
      );
      LoggerService.info('FirebaseService', 'Saved local customer #$localId with firebaseUid: $firebaseUid');
    } catch (e) {
      LoggerService.error('FirebaseService', 'Failed to update local customer firebaseUid', e);
    }
  }

  // 3. Listen to Job Status Changes (MIGRATED to Cloud Functions)
  void startJobStatusListener(MySQLService localDb) {
    LoggerService.warning('FirebaseService', 'Firebase Job Listener is DISABLED. Handled by Cloud Functions.');
  }

  // LINE and messaging notification wrappers (Delegated)
  Future<bool> sendLineNotification(MySQLService db, int orderId, String message) async {
    return await _messagingService.sendLineNotification(db, orderId, message);
  }

  Future<bool> sendLineImageNotification(MySQLService db, int orderId, String filename) async {
    return await _messagingService.sendLineImageNotification(db, orderId, filename);
  }

  Future<void> processPendingNotifications(MySQLService db) async {
    await _messagingService.processPendingNotifications(db);
  }

  Future<bool> sendLineNotificationDirect({
    required MySQLService db,
    required int orderId,
    required String lineUserId,
    required String message,
  }) async {
    return await _messagingService.sendLineNotificationDirect(
      db: db,
      orderId: orderId,
      lineUserId: lineUserId,
      message: message,
    );
  }

  Future<bool> sendLineReceiptImageDirect({
    required MySQLService db,
    required int orderId,
    required String lineUserId,
    required Uri url,
    required String base64Image,
  }) async {
    return await _messagingService.sendLineReceiptImageDirect(
      db: db,
      orderId: orderId,
      lineUserId: lineUserId,
      url: url,
      base64Image: base64Image,
    );
  }

  // Expired jobs auto-cleanup
  Future<List<String>> fetchExpiredPickupJobs(int minutesOld) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return await FirestoreRestService.fetchExpiredPickupJobs(minutesOld);
    }
    
    try {
      final cutoff = DateTime.now().subtract(Duration(minutes: minutesOld));

      final query = await _firestore
          .collection('jobs')
          .where('job_type', whereIn: ['pickup', 'customer_pickup'])
          .where('created_at', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      return query.docs.map((doc) => doc.id).toList();
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        LoggerService.warning('FirebaseService', '[Firebase] Permission Denied for Expired Jobs. Check Firestore Rules.');
      } else {
        LoggerService.error('FirebaseService', '[Firebase] Fetch Expired Jobs Error', e);
      }
      return [];
    }
  }

  // Active (Pending/Shipping) Jobs
  Future<List<Map<String, dynamic>>> fetchActiveDeliveryJobs() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return await FirestoreRestService.fetchActiveDeliveryJobs();
    }
    
    try {
      final query = await _firestore
          .collection('jobs')
          .where('status', whereIn: ['pending', 'shipping', 'enroute', 'en_route', 'accepted'])
          .get();

      final List<Map<String, dynamic>> results = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate();
        }
        return data;
      }).toList();

      results.sort((a, b) {
        final dateA = a['created_at'] as DateTime?;
        final dateB = b['created_at'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA); // descending
      });

      return results;
    } catch (e) {
      LoggerService.error('FirebaseService', 'Fetch Active Jobs Error', e);
      return [];
    }
  }

  // Archivable Jobs
  Future<List<Map<String, dynamic>>> fetchArchivableJobs() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return await FirestoreRestService.fetchArchivableJobs();
    }
    
    try {
      try {
        final smoke = await _firestore.collection('jobs').limit(1).get();
        LoggerService.info('FirebaseService', '[Firebase] Smoke Test: Found ${smoke.docs.length} jobs (General Access OK)');
      } catch (e) {
        LoggerService.error('FirebaseService', '[Firebase] Smoke Test FAILED', e);
      }

      final query = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'completed')
          .limit(500)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate();
        }
        if (data['completed_at'] is Timestamp) {
          data['completed_at'] = (data['completed_at'] as Timestamp).toDate();
        }
        return data;
      }).toList();
    } catch (e) {
      LoggerService.error('FirebaseService', 'Fetch Archivable Jobs Error', e);
      return [];
    }
  }

  // Delete Job (Cleanup)
  Future<void> deleteJob(String jobId) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await FirestoreRestService.deleteDocument('jobs', jobId);
      } else {
        await _firestore.collection('jobs').doc(jobId).delete();
      }
      LoggerService.info('FirebaseService', '[Firebase] Deleted Job: $jobId');
    } catch (e) {
      LoggerService.error('FirebaseService', '[Firebase] Failed to delete Job $jobId', e);
    }
  }

  // Stop listening
  void stopListener() {
    _jobSubscription?.cancel();
    LoggerService.info('FirebaseService', 'Firebase Listener Stopped');
  }
}
