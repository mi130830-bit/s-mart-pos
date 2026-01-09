import 'dart:async'; // REFRESH: Line restored at 15:30
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'dart:typed_data';
import '../models/customer.dart';
import '../models/order_item.dart';
import 'mysql_service.dart';

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
      // ✅ ใช้ set(..., merge: true) แทน update() เพื่อให้สร้างเอกสารได้ถ้ายังไม่มี
      await _firestore.collection('users').doc(firebaseUid).set({
        'currentPoints': newTotalPoints,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
  }) async {
    try {
      // 2.1 Sync Customer First (ประหยัด Read/Write ด้วยการเช็ค local ก่อน)
      final String firebaseUid =
          await _ensureCustomerSynced(customer, dbService);

      // 2.2 Create Job with Correct Fields for S_link
      // details: แปลงรายการสินค้าเป็น String ยาวๆ
      String details = items
          .map((i) =>
              '${i.productName} x${i.quantity}${i.comment.isNotEmpty ? " (${i.comment})" : ""}'
                  .trim())
          .join('\n');

      // ✅ แทรกหมายเหตุ (เช่น "จ่ายเงินแล้ว") ไว้ด้านบนสุด
      if (note != null && note.isNotEmpty) {
        details = '$note\n━━━━━━━━━━━━━━━━━━\n$details';
      }

      final docRef = await _firestore.collection('jobs').add({
        'localOrderId': localOrderId,
        'status': 'pending', // S_link ใช้ 'pending' (ตัวพิมพ์เล็ก)
        'job_type': jobType, // ✅ เพิ่ม job_type
        'created_at': FieldValue.serverTimestamp(),
        'created_by': 'POS System', // เพิ่มตาม Request
        'customer_id': firebaseUid, // เชื่อมโยงกับ ID ที่ Sync แล้ว
        'customer': {
          'name': '${customer.firstName} ${customer.lastName ?? ""}'.trim(),
          'phoneNumber':
              customer.phone ?? '', // ✅ แก้ key เป็น phoneNumber ตาม S_link
          'address': customer.shippingAddress ?? customer.address ?? '',
          'location': null, // ยังไม่มีพิกัดจาก POS
        },
        'details': details, // ✅ เพิ่ม details
        'items': items
            .map((item) => {
                  'name': item.productName,
                  'qty': item.quantity.toDouble(), // Convert Decimal to double
                  'price': item.price.toDouble(), // Convert Decimal to double
                  'total': item.total.toDouble() // Convert Decimal to double
                })
            .toList(),
        'price': grandTotal, // S_link น่าจะใช้ price หรือ codAmount
        'delivery_team': [], // ✅ ส่ง delivery_team ว่าง
        'is_departure_approved': false,
        'bill_image_urls': billImageUrls ?? [], // ✅ แนบรูปบิล
      });

      debugPrint('☁️ Created Cloud Job: ${docRef.id} for Cust: $firebaseUid');
      return docRef.id;
    } catch (e) {
      debugPrint('⚠️ Failed to create Cloud Job: $e');
      return null;
    }
  }

  // 3. Update Job (ใช้สำหรับแนบรูปทีหลัง)
  Future<void> updateJob(String jobId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update(updates);
      debugPrint('☁️ Updated Cloud Job: $jobId');
    } catch (e) {
      debugPrint('⚠️ Failed to update Cloud Job: $e');
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
    // ใช้ phone_number ให้ตรงกับ S_link
    final phone = customer.phone ?? '';
    if (phone.isEmpty) {
      // กรณีไม่มีเบอร์โทร สร้างใหม่เลยแบบไม่มีเบอร์ (ไม่แนะนำแต่กัน Error)
      return _createNewFirestoreCustomer(customer, dbService);
    }

    try {
      final query = await _firestore
          .collection('customers')
          .where('phone_number', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        // 3. เจอในระบบ -> ดึง ID มาใช้ และบันทึกลง Local MySQL
        final docId = query.docs.first.id;
        debugPrint('🔍 Found existing customer on cloud: $docId');
        await _updateLocalCustomerFirebaseUid(
            dbService, customer.id, docId); // Save to Local
        return docId;
      } else {
        // 4. ไม่เจอ -> สร้างใหม่
        return _createNewFirestoreCustomer(customer, dbService);
      }
    } catch (e) {
      debugPrint('⚠️ Find Customer Error: $e');
      // กันตาย: สร้างใหม่ไปเลย
      return _createNewFirestoreCustomer(customer, dbService);
    }
  }

  Future<String> _createNewFirestoreCustomer(
      Customer customer, MySQLService dbService) async {
    try {
      final docRef = await _firestore.collection('customers').add({
        'name': '${customer.firstName} ${customer.lastName ?? ""}'.trim(),
        'phone_number': customer.phone ?? '',
        'address': customer.address ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'is_active': true,
        'from_source': 'POS',
      });
      debugPrint('✨ Created new customer on cloud: ${docRef.id}');

      // Save ID back to Local MySQL
      await _updateLocalCustomerFirebaseUid(dbService, customer.id, docRef.id);

      return docRef.id;
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

  // 3. Listen to Job Status Changes (Disabled as requested to save Read costs)
  void startJobStatusListener(MySQLService localDb) {
    debugPrint(
        '❄️ Firebase Job Listener is DISABLED to save cost (Local sync removed).');
    /*
    debugPrint('🎧 Initializing Firebase Job Listener (Production Mode)...');

    try {
      // ยกเลิกตัวเก่าก่อน (Clean up)
      _jobSubscription?.cancel();

      // เริ่มฟังข้อมูล
      _jobSubscription = _firestore
          .collection('jobs')
          // ⚠️ ถ้ายังเด้งที่บรรทัดนี้ ให้ลบ .where ออก แล้วไปสร้าง Index บน Firebase Console
          .where('status', whereIn: ['COMPLETED', 'CANCELLED', 'ASSIGNED'])
          .snapshots()
          .listen(
            (snapshot) {
              // Re-dispatch processing to the Flutter platform/UI thread. Some plugins
              // may invoke callbacks from native threads; scheduling a post-frame
              // callback ensures we process on the correct thread and avoid the
              // "non-platform thread" platform-channel warning.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                for (var change in snapshot.docChanges) {
                  if (change.type == DocumentChangeType.modified) {
                    final data = change.doc.data(); // dynamic map
                    final String jobId = change.doc.id;

                    // ดึงค่าแบบปลอดภัย (Safe Access)
                    final String? newStatus = data?['status'];
                    final int? localOrderId = data?['localOrderId'];

                    if (newStatus != null && localOrderId != null) {
                      debugPrint(
                        '🔄 Cloud Job $jobId changed to $newStatus (Local Order: $localOrderId)',
                      );

                      try {
                        // 1. Update Job Status ใน Local DB
                        await localDb.execute(
                          'UPDATE delivery_jobs SET status = :status WHERE orderId = :oid',
                          {'status': newStatus, 'oid': localOrderId},
                        );

                        // 2. Update Order Status (ถ้างานจบแล้ว)
                        if (newStatus == 'COMPLETED') {
                          await localDb.execute(
                            'UPDATE `order` SET status = "COMPLETED" WHERE id = :oid',
                            {'oid': localOrderId},
                          );
                        }
                        debugPrint(
                          '✅ Local DB Updated for Order #$localOrderId',
                        );
                      } catch (e) {
                        debugPrint('❌ Failed to update local DB: $e');
                      }
                    }
                  }
                }
              });
            },
            onError: (e) {
              debugPrint('🔥 Firebase Listener Error: $e');
              final err = e.toString();
              if (err.contains('failed-precondition') ||
                  err.contains('index')) {
                debugPrint(
                  '💡 ต้องสร้าง Index บน Firebase Console: Collection "jobs", Field "status"',
                );
              }
              if (err.contains('permission-denied') ||
                  err.contains('Missing or insufficient')) {
                debugPrint(
                  '🔒 Firebase permission denied when listening to jobs. Check Firestore rules and authentication.',
                );
                // Stop the listener to avoid repeated permission errors
                _jobSubscription?.cancel();
                _jobSubscription = null;
              }
            },
          );

      debugPrint('🎧 Firebase Job Listener Attached Successfully.');
    } catch (e) {
      debugPrint('🔥 CRITICAL ERROR attaching listener: $e');
    }
    */
  }

  // ฟังก์ชันหยุดฟัง (ควรเรียกตอน Logout)
  void stopListener() {
    _jobSubscription?.cancel();
    debugPrint('🛑 Firebase Listener Stopped');
  }
}
