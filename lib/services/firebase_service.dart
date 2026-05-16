import 'package:flutter/foundation.dart';
import 'firestore_rest_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/customer.dart';
import '../models/order_item.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/settings_service.dart';
import 'mysql_service.dart';
import '../repositories/notification_repository.dart';
import '../repositories/sales_repository.dart';
import '../services/printing/receipt_service.dart';

class FirebaseService {
  // 0. Upload Bill Image to Storage
  Future<String?> uploadBillImage(Uint8List imageData, String jobId) async {
    try {
      final String fileName =
          'bills/${jobId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);

      final uploadTask = storageRef.putData(
        imageData,
        SettableMetadata(contentType: 'image/png'),
      );

      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('⚠️ Failed to upload Bill Image: $e');
      return null;
    }
  }

  // Use a getter to avoid throwing 'core/no-app' if Firebase isn't initialized yet
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('⚠️ FirebaseFirestore not ready: $e');
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
      debugPrint('☁️ Synced points for $firebaseUid: $newTotalPoints');
    } catch (e) {
      debugPrint('⚠️ Failed to sync points to Firebase: $e');
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
          debugPrint('⚠️ Failed to fetch warehouse flags from MySQL: $e');
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

      debugPrint('☁️ Created Cloud Job: $docId for Cust: $firebaseUid');
      return docId;
    } catch (e) {
      debugPrint('⚠️ Failed to create Cloud Job: $e');
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
      debugPrint('☁️ Updated Cloud Job: $jobId');
    } catch (e) {
      debugPrint('⚠️ Failed to update Cloud Job: $e');
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
      debugPrint('⚠️ Fetch Cloud Jobs Error: $e');
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
      debugPrint('⚠️ Fetch Shop Work Logs Error: $e');
      return [];
    }
  }

  // Helper: ตรวจสอบและ Sync ลูกค้า (POS <-> Firestore)
  Future<String> _ensureCustomerSynced(
      Customer customer, MySQLService dbService) async {
    // 1. ถ้ามี ID เดิมอยู่แล้ว ให้ใช้เลย (0 Read)
    if (customer.firebaseUid != null && customer.firebaseUid!.isNotEmpty) {
      // ✅ Update Line User ID if missing in Firestore (Healing)
      /* 
      // Implementation Detail: We could check and update firestore here if lineUserId is missing there but present in customer.
      // But to save reads, we assume it's synced or will be synced by next logic.
      */
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
        debugPrint('🔍 Found existing customer on cloud: $docId');

        await _updateLocalCustomerFirebaseUid(
            dbService, customer.id, docId); // Save to Local

        // ✅ Check if Line User ID needs sync (Local -> Cloud)
        // To simplify, we just always update Line ID on Windows if missing.
        // Actually, we could use REST to update if lineUserId is set.
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
          debugPrint('🔄 Synced Line User ID to Cloud Customer');
        }

        return docId;
      } else {
        // 4. ไม่เจอ -> สร้างใหม่
        return _createNewFirestoreCustomer(customer, dbService);
      }
    } catch (e) {
      debugPrint('⚠️ Find Customer Error: $e');
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

      debugPrint('✨ Created new customer on cloud: $docId');

      // Save ID back to Local MySQL
      await _updateLocalCustomerFirebaseUid(dbService, customer.id, docId);

      return docId;
    } catch (e) {
      debugPrint('⚠️ Create Customer Error: $e');
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
      debugPrint(
          '💾 Updated Local Customer #$localId with firebaseUid: $firebaseUid');
    } catch (e) {
      debugPrint('❌ Failed to update local customer firebaseUid: $e');
    }
  }

  // 3. Listen to Job Status Changes (MIGRATED to Cloud Functions)
  // ⚠️ Line Notifications for Stage 2 & 3 are now handled by Firebase Cloud Functions
  // See: functions/index.js for implementation
  void startJobStatusListener(MySQLService localDb) {
    debugPrint('⚠️ Firebase Job Listener is DISABLED.');
    debugPrint(
        '   Line Notifications (Stage 2/3) are handled by Cloud Functions.');

    /* DISABLED: Migrated to Cloud Functions
    debugPrint(
        '🎧 Initializing Firebase Job Listener (Line Notification Mode)...');

    try {
      // ยกเลิกตัวเก่าก่อน (Clean up)
      _jobSubscription?.cancel();

      // เริ่มฟังข้อมูล
      _jobSubscription = _firestore.collection('jobs').snapshots().listen(
        (snapshot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            () async {
              for (var change in snapshot.docChanges) {
                // ✅ Fix: Handle 'added' types too!
                if (change.type == DocumentChangeType.modified ||
                    change.type == DocumentChangeType.added) {
                  final data = change.doc.data();
                  if (data == null) continue;

                  debugPrint(
                      '🔥 Cloud Change Detected: ${change.doc.id}, Status: ${data['status']}, Approved: ${data['is_departure_approved']}');

                  final int? localOrderId = data['localOrderId'];
                  final String? status = data['status'];
                  final bool isDepartureApproved =
                      data['is_departure_approved'] == true;

                  // --- Logic แจ้งเตือน Line (Stages 2 & 3) ---
                  try {
                    if (localOrderId != null) {
                      // 1. ดึงสถานะปัจจุบันจาก Local DB (เพื่อกันส่งซ้ำ)
                      String currentLocalStatus = '';
                      final localJob = await localDb.query(
                          'SELECT status FROM delivery_jobs WHERE orderId = :oid',
                          {'oid': localOrderId});

                      if (localJob.isNotEmpty) {
                        currentLocalStatus =
                            localJob.first['status'].toString().toUpperCase();
                      }

                      // --- Stage 2: Shipping (ปล่อยรถ) ---
                      // Trigger: Cloud says 'SHIPPING' or 'APPROVED' (and not completed)
                      final s = status?.toLowerCase();
                      final bool isCloudShipping = (s == 'shipping' ||
                              s == 'enroute' ||
                              s == 'en_route' ||
                              isDepartureApproved) &&
                          s != 'completed';

                      if (isCloudShipping &&
                          currentLocalStatus != 'SHIPPING' &&
                          currentLocalStatus != 'COMPLETED') {
                        debugPrint(
                            '🚀 Stage 2 Trigger: Cloud=$status, Local=$currentLocalStatus');

                        // A. Send Notification
                        final msg =
                            '🚚 สินค้าของท่านกำลังเดินทางจัดส่งครับ\\nรอรับสายจากพนักงานได้เลยครับ!';
                        await sendLineNotification(localDb, localOrderId, msg);
                        debugPrint('☁️ Sent Line Notification for Stage 2');

                        // B. Update Local State (Upsert)
                        if (localJob.isNotEmpty) {
                          await localDb.execute(
                              'UPDATE delivery_jobs SET status = "SHIPPING" WHERE orderId = :oid',
                              {'oid': localOrderId});
                        } else {
                          await localDb.execute(
                              'INSERT INTO delivery_jobs (orderId, firebaseJobId, status) VALUES (:oid, :fid, :status)',
                              {
                                'oid': localOrderId,
                                'fid': change.doc.id,
                                'status': 'SHIPPING'
                              });
                        }
                      }

                      // --- Stage 3: Completed (ส่งเสร็จ) ---
                      // Trigger: Cloud says 'COMPLETED'
                      if (status?.toLowerCase() == 'completed' &&
                          currentLocalStatus != 'COMPLETED') {
                        debugPrint(
                            '🚀 Stage 3 Trigger: Cloud=$status, Local=$currentLocalStatus');

                        // A. Send Notification
                        final msg =
                            'สินค้าจัดส่งถึงมือท่านเรียบร้อยแล้ว 📦 ขอบคุณที่ไว้วางใจใช้บริการ ส.บริการ ท่าข้าม ครับ 🙏 โอกาสหน้าเชิญใหม่นะครับ';
                        await sendLineNotification(localDb, localOrderId, msg);
                        debugPrint('☁️ Sent Line Notification for Stage 3');

                        // B. Update Local State (Upsert)
                        if (localJob.isNotEmpty) {
                          await localDb.execute(
                              'UPDATE delivery_jobs SET status = "COMPLETED" WHERE orderId = :oid',
                              {'oid': localOrderId});
                        } else {
                          await localDb.execute(
                              'INSERT INTO delivery_jobs (orderId, firebaseJobId, status) VALUES (:oid, :fid, :status)',
                              {
                                'oid': localOrderId,
                                'fid': change.doc.id,
                                'status': 'COMPLETED'
                              });
                        }

                        // C. Update Main Order Status
                        await localDb.execute(
                            'UPDATE `order` SET status = "COMPLETED" WHERE id = :oid',
                            {'oid': localOrderId});
                      }
                    }
                  } catch (e) {
                    debugPrint('⚠️ Process Job Change Error: $e');
                  }
                }
              }
            }();
          });
        },
        onError: (e) {
          debugPrint('🔥 Firebase Listener Error: $e');
        },
      );

      debugPrint('🎧 Firebase Job Listener Attached Successfully.');
    } catch (e) {
      debugPrint('🔥 CRITICAL ERROR attaching listener: $e');
    }
    */
  }

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
      debugPrint('⚠️ Failed to resolve Line User ID: $e');
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
      debugPrint('⚠️ Failed to resolve Line User ID: $e');
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

  /// Private Helper: Send HTTP Request with Persistent Retry & Logging
  Future<bool> _sendWithRetry({
    required MySQLService db,
    required int orderId,
    required String lineUserId,
    required String messageType,
    required String content,
    required Uri url,
    required String body,
    int? existingLogId, // ✅ Support resuming existing log
    Duration timeout = const Duration(seconds: 8), // ✅ Configurable timeout
  }) async {
    // A. Init Repository & Table (Lazy Init)
    final repo = NotificationRepository(db);
    // Ensure table exists (cached check inside repo usually, but valid here too)
    await repo.initTable();

    int logId;
    if (existingLogId != null) {
      logId = existingLogId;
    } else {
      // B. Create Initial Log if new
      logId = await repo.createLog(
        orderId: orderId,
        lineUserId: lineUserId,
        messageType: messageType,
        content: content,
      );
    }

    // Try sending immediately (1 attempt)
    // We do ONE attempt here. If failed, the Queue Processor will pick it up later.
    // Or we can do a short loop. Let's do 1 immediate try to not block UI too long.
    try {
      debugPrint(
          '🚀 [Line] Sending $messageType -> $lineUserId (LogID: $logId)');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout); // ✅ Use configurable timeout

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success
        debugPrint('✅ [Line] Send Success!');
        await repo.markAsSuccess(logId);
        return true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ [Line] Immediate Send Failed: $e');

      // Update log to Failed/Retrying
      repo.updateLog(logId,
          status: 'RETRYING',
          errorMessage: e.toString()); // Fire & Forget DB update

      return false; // Failed immediately
    }
  }

  /// ✅ New Method: Process Pending Notifications (Background Job)
  Future<void> processPendingNotifications(MySQLService db) async {
    final repo = NotificationRepository(db);
    final pendingLogs = await repo.getPendingLogs();

    if (pendingLogs.isEmpty) return;

    debugPrint(
        '🔄 [Line] Processing ${pendingLogs.length} pending notifications...');

    for (final log in pendingLogs) {
      try {
        final int id = int.tryParse(log['id'].toString()) ?? 0;
        final int attempts =
            int.tryParse(log['attempt_count']?.toString() ?? '0') ?? 0;
        final String lineUserId = log['line_user_id']?.toString() ?? '';
        final String type = log['message_type']?.toString() ?? 'TEXT';
        final String content = log['content']?.toString() ?? '';

        // Stop retrying after many attempts (e.g., 10)
        if (attempts > 10) {
          await repo.markAsFailed(id, "Max attempts reached");
          continue;
        }

        // ✅ RECEIPT_IMAGE Retry Logic (Dynamically recreate PDF)
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
            
            continue; // Move to next log after handling Image
          } catch (e) {
            await repo.markAsFailed(id, 'Failed to recreate receipt: $e');
            continue;
          }
        }

        // Reconstruct Payload
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

        // Send (Reuse logic)
        await _sendWithRetry(
          db: db,
          orderId: int.tryParse(log['order_id']?.toString() ?? '0') ?? 0,
          lineUserId: lineUserId,
          messageType: type,
          content: content,
          url: url,
          body: body,
          existingLogId: id, // ✅ Pass existing ID
        );
      } catch (e) {
        debugPrint('⚠️ Error processing pending log: $e');
      }
    }
  }

  // ✅ New Method: Fetch Expired Pickup Jobs (for Auto-Cleanup)
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
        debugPrint('⚠️ [Firebase] Permission Denied for Expired Jobs. Check Firestore Rules.');
      } else {
        debugPrint('⚠️ [Firebase] Fetch Expired Jobs Error: $e');
      }
      return [];
    }
  }

  // ✅ New Method: Fetch Active (Pending/Shipping) Jobs
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

      // Sort locally by created_at descending to avoid needing a composite index
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
      debugPrint('⚠️ Fetch Active Jobs Error: $e');
      return [];
    }
  }

  // ✅ New Method: Fetch Archivable Jobs (for MySQL Archiving)
  Future<List<Map<String, dynamic>>> fetchArchivableJobs() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return await FirestoreRestService.fetchArchivableJobs();
    }
    
    try {
      // 🔥 SMOKE TEST: Try to fetch a single job with NO filters first
      // This helps determine if the issue is Rules (general) or Query (index required)
      try {
        final smoke = await _firestore.collection('jobs').limit(1).get();
        debugPrint('🔍 [Firebase] Smoke Test: Found ${smoke.docs.length} jobs (General Access OK)');
      } catch (e) {
        debugPrint('❌ [Firebase] Smoke Test FAILED: $e');
        if (e.toString().contains('permission-denied')) {
          debugPrint('💡 [Suggestion] Your Firestore Rules are still blocking access. Make sure you pressed "Publish".');
        }
      }

      // ✅ Fetch jobs that are completed
      final query = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'completed')
          .limit(500) // ✅ Increase limit to 500 to catch up with backlog
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
      debugPrint('⚠️ Fetch Archivable Jobs Error: $e');
      return [];
    }
  }

  // ✅ New Method:  // ✅ Delete Job (Cleanup)
  Future<void> deleteJob(String jobId) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await FirestoreRestService.deleteDocument('jobs', jobId);
      } else {
        await _firestore.collection('jobs').doc(jobId).delete();
      }
      debugPrint('🗑️ [Firebase] Deleted Job: $jobId');
    } catch (e) {
      debugPrint('⚠️ [Firebase] Failed to delete Job $jobId: $e');
    }
  }

  /// ✅ ส่งข้อความ Text โดยตรง (มี lineUserId แล้ว) + บันทึก Log
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

  /// ✅ ส่งรูปบิล Base64 โดยตรง + บันทึก Log
  Future<bool> sendLineReceiptImageDirect({
    required MySQLService db,
    required int orderId,
    required String lineUserId,
    required Uri url,
    required String base64Image,
  }) async {
    // ✅ ส่ง baseUrl ไปด้วย เพื่อให้ backend สร้าง HTTPS public URL ได้ถูกต้อง
    // (X-Forwarded headers จาก Cloudflare ไม่ถูก forward มายัง localhost)
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
      'baseUrl': baseUrl, // ✅ เช่น https://api.namecheap.work
    });

    return await _sendWithRetry(
      db: db,
      orderId: orderId,
      lineUserId: lineUserId,
      messageType: 'RECEIPT_IMAGE',
      content: 'receipt_image_order_$orderId', // Log content (ไม่เก็บ base64)
      url: url,
      body: body,
      timeout: const Duration(seconds: 30), // ✅ รูปใหญ่ต้องการเวลามากกว่า
    );
  }

  // ฟังก์ชันหยุดฟัง (ควรเรียกตอน Logout)
  void stopListener() {
    _jobSubscription?.cancel();
    debugPrint('🛑 Firebase Listener Stopped');
  }
}
