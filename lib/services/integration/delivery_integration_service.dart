import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../../services/firebase_service.dart';
import '../../services/telegram_service.dart';
import '../../services/mysql_service.dart';
import '../../services/settings_service.dart';
import '../../models/customer.dart';
import '../../models/order_item.dart';

import '../../repositories/delivery_history_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeliveryIntegrationService {
  final MySQLService _dbService;
  final FirebaseService _firebaseService;
  final TelegramService _telegramService = TelegramService();
  Timer? _cleanupTimer;

  DeliveryIntegrationService(this._dbService, this._firebaseService) {
    _startAutoCleanupTimer();
  }

  void _startAutoCleanupTimer() {
    debugPrint(
        '⏳ [DeliveryService] Starting Auto-Cleanup Timer for Pickup Jobs...');
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 20), (timer) async {
      await _cleanupExpiredPickupJobs();
      await _cleanupArchivableJobs();
    });
  }

  Future<bool> _ensureAuth({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // 🔥 Force refresh token if requested or if we already have a user
        // This fixes 'permission-denied' on Windows Desktop when session markers expire.
        await user.getIdToken(forceRefresh || !kDebugMode); 
        debugPrint('✅ [Auth] Token valid for: ${user.email} (UID: ${user.uid})');
        return true;
      } catch (e) {
        debugPrint('⚠️ [Auth] Token refresh failed: $e. Re-authenticating...');
      }
    }

    try {
      final settings = SettingsService();
      final email = settings.firebaseAuthEmail;
      final password = settings.firebaseAuthPassword;

      if (email.isEmpty || password.isEmpty) {
        debugPrint('⚠️ [Auth] No Firebase credentials in Settings.');
        return false;
      }

      debugPrint('☁️ [Auth] Connecting to S_MartPOS Cloud ($email)...');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final newUser = FirebaseAuth.instance.currentUser;
      if (newUser != null) {
        debugPrint('✅ [Auth] Signed in successfully! (UID: ${newUser.uid})');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ [Auth] Firebase Login Error: $e');
      return false;
    }
  }

  Future<void> _cleanupExpiredPickupJobs() async {
    try {
      // ✅ 0. Check Auth
      if (!await _ensureAuth()) {
        debugPrint('⚠️ [AutoCleanup] Auth failed. Skipping expired jobs cleanup.');
        return;
      }

      // 1. Fetch jobs older than 60 minutes
      final expiredJobIds = await _firebaseService.fetchExpiredPickupJobs(60);

      if (expiredJobIds.isNotEmpty) {
        debugPrint(
            '🧹 [AutoCleanup] Found ${expiredJobIds.length} expired pickup jobs. Deleting...');

        for (final jobId in expiredJobIds) {
          await _firebaseService.deleteJob(jobId);
        }
        debugPrint('✅ [AutoCleanup] Deleted ${expiredJobIds.length} jobs.');
      }
    } catch (e) {
      debugPrint('⚠️ [AutoCleanup] Error: $e');
    }
  }

  Future<void> _cleanupArchivableJobs() async {
    try {
      // ✅ 0. Check Auth
      if (!await _ensureAuth()) {
        debugPrint('⚠️ [AutoCleanup] Auth failed. Skipping archiving.');
        return;
      }

      final archivableJobs = await _firebaseService.fetchArchivableJobs();

      if (archivableJobs.isNotEmpty) {
        debugPrint(
            '🧹 [AutoCleanup] Found ${archivableJobs.length} completed/cancelled jobs. Archiving...');

        final repo = DeliveryHistoryRepository(db: _dbService);

        for (final job in archivableJobs) {
          final String jobId = job['id'];
          final int orderId = job['localOrderId'] ?? 0;
          final double totalAmount = (job['price'] ?? 0.0).toDouble();
          final String status = job['status'] ?? 'completed';
          final String jobType = job['job_type'] ?? 'delivery';

          // ✅ ข้ามการเก็บลงประวัติขนส่งสำหรับงานรับของหน้าร้าน/หลังร้าน
          if (jobType == 'pickup' || jobType == 'customer_pickup') {
            continue; // ปล่อยให้ _cleanupExpiredPickupJobs ลบทิ้งเองเมื่อครบเวลา
          }

          final DateTime? createdAt = job['created_at'] != null ? job['created_at'] as DateTime : null;
          final DateTime? completedAt = job['completed_at'] != null ? job['completed_at'] as DateTime : null;
          
          final customer = job['customer'] ?? {};
          final String customerName = customer['name'] ?? '';
          final String customerAddress = customer['address'] ?? '';
          final String customerPhone =
              customer['phoneNumber'] ?? customer['phone'] ?? '';

          // ✅ New Parsing Strategy: Collect drivers and find vehicle accurately
          final driverNamesList = <String>[];
          String vehiclePlate = '';

          if (job['delivery_team'] != null && (job['delivery_team'] as List).isNotEmpty) {
            for (var member in (job['delivery_team'] as List)) {
              final String rawType = member['type']?.toString().toLowerCase() ?? '';
              final String rawName = (member['name'] ?? '').toString().trim();
              final String rawPlate = (member['licensePlate'] ?? member['vehicle_plate'] ?? '').toString().trim();

              // Heuristics: Check if this member is actually a vehicle
              bool isVehicleMember = (rawType == 'car' || rawType == 'vehicle');
              if (!isVehicleMember && rawName.isNotEmpty) {
                // Check keywords in name if type is missing/wrong
                final lowerName = rawName.toLowerCase();
                if (lowerName.contains('ดั้ม') || 
                    lowerName.contains('ดั๊ม') || 
                    lowerName.contains('ดัมพ์') || 
                    lowerName.contains('รถ') || 
                    lowerName.contains('กะบะ') || 
                    lowerName.contains('กระบะ') ||
                    lowerName.contains('โฟล์ค') ||
                    lowerName.contains('ลิฟท์')) {
                  isVehicleMember = true;
                }
              }

              if (isVehicleMember) {
                if (vehiclePlate.isEmpty) {
                  vehiclePlate = (rawPlate.isNotEmpty ? rawPlate : rawName).toUpperCase();
                }
              } else {
                if (rawName.isNotEmpty) {
                  driverNamesList.add(rawName);
                }
              }
            }
          }
          final String driverName = driverNamesList.join(', ');

          debugPrint('🚚 [Archive] Job: $jobId | Order: $orderId | Driver: $driverName | Plate: $vehiclePlate');

          // Location URL from destination_location (S-Link standard) or proof_location
          String locationUrl = '';
          double? destinationLat;
          double? destinationLng;
          final gp = job['destination_location'] ?? job['proof_location'];
          if (gp != null) {
            try {
              if (gp is String) {
                locationUrl = gp;
                // Try to parse lat/lng from URL
                if (locationUrl.contains('?q=')) {
                  final coordStr = locationUrl.split('?q=').last.split('&').first;
                  final parts = coordStr.split(',');
                  if (parts.length >= 2) {
                    destinationLat = double.tryParse(parts[0].trim());
                    destinationLng = double.tryParse(parts[1].trim());
                  }
                }
              } else if (gp is Map) {
                final lat = gp['_latitude'] ?? gp['latitude'] ?? gp['lat'];
                final lng = gp['_longitude'] ?? gp['longitude'] ?? gp['lng'];
                if (lat != null && lng != null) {
                  destinationLat = (lat as num).toDouble();
                  destinationLng = (lng as num).toDouble();
                  locationUrl = 'https://maps.google.com/?q=$destinationLat,$destinationLng';
                }
              } else {
                // In case it's a Firestore GeoPoint object
                try {
                  final lat = (gp as dynamic).latitude;
                  final lng = (gp as dynamic).longitude;
                  if (lat != null && lng != null) {
                    destinationLat = (lat as num).toDouble();
                    destinationLng = (lng as num).toDouble();
                    locationUrl = 'https://maps.google.com/?q=$destinationLat,$destinationLng';
                  }
                } catch (_) {}
              }
            } catch (e) {
              debugPrint('⚠️ [AutoCleanup] Error parsing location: $e');
            }
          }

          // ✅ Bill image URL from S-Link (proof photo taken after delivery)
          String? billImageUrl = job['proof_image_url']
              ?? job['receipt_image_url']
              ?? job['billImageUrl'];
          // If null, look in completed_items or delivery_proof sub-object
          if (billImageUrl == null) {
            final proof = job['delivery_proof'] ?? job['proof'];
            if (proof is Map) {
              billImageUrl = proof['image_url']?.toString()
                  ?? proof['imageUrl']?.toString()
                  ?? proof['url']?.toString();
            }
          }

          // Feature: Distance & Fuel Cost Calculation via Haversine
          double distanceKm = 0.0;
          double fuelCostEstimate = 0.0;
          try {
            final settings = SettingsService();
            final shopLat = settings.shopLatitude;
            final shopLng = settings.shopLongitude;
            final fuelRate = settings.fuelCostPerKm;

            // 🌟 1. ดึงระยะทางจากที่ตั้งค่าไว้ในประวัติลูกค้า (ถ้ามี)
            if (customerName.isNotEmpty && customerName != 'ลูกค้าทั่วไป') {
              try {
                final db = MySQLService();
                final dbRes = await db.query(
                  'SELECT distanceKm FROM customer WHERE firstName LIKE :cname OR CONCAT(firstName, " ", IFNULL(lastName, "")) LIKE :cname LIMIT 1', 
                  {'cname': '%$customerName%'}
                );
                if (dbRes.isNotEmpty) {
                  distanceKm = double.tryParse(dbRes.first['distanceKm']?.toString() ?? '0') ?? 0.0;
                  if (distanceKm > 0.0) {
                    fuelCostEstimate = distanceKm * fuelRate;
                    debugPrint('📏 [Archive] Using Predefined Customer Distance: ${distanceKm.toStringAsFixed(2)} km | Fuel: ฿${fuelCostEstimate.toStringAsFixed(2)}');
                  }
                }
              } catch (e) {
                debugPrint('⚠️ [Archive] Could not fetch customer distance: $e');
              }
            }

            // 🌟 2. ถ้าลูกค้าไม่มีระยะทางที่ตั้งไว้ ให้คำนวณจาก GPS ปลายทาง (OSRM)
            if (distanceKm == 0.0) {
              // Use raw destinationLat/Lng captured above — no need to re-parse URL
              final dLat = destinationLat ?? 0.0;
              final dLng = destinationLng ?? 0.0;
              if (shopLat != 0.0 && shopLng != 0.0 && dLat != 0.0 && dLng != 0.0) {
                distanceKm = await _getRoadDistanceRoundTrip(shopLat, shopLng, dLat, dLng);
                fuelCostEstimate = distanceKm * fuelRate;
                debugPrint('📏 [Archive] Road Distance (RT): ${distanceKm.toStringAsFixed(2)} km | Fuel: ฿${fuelCostEstimate.toStringAsFixed(2)}');
              } else if (shopLat == 0.0 || shopLng == 0.0) {
                debugPrint('⚠️ [Archive] Shop GPS not configured. Skipping distance calc.');
              }
            }
          } catch (e) {
            debugPrint('⚠️ [AutoCleanup] Error calculating distance: $e');
          }

          // Archive to MySQL
          final archiveResult = await repo.archiveJob(
            orderId: orderId,
            firebaseJobId: jobId,
            driverName: driverName,
            vehiclePlate: vehiclePlate,
            customerName: customerName,
            customerPhone: customerPhone,
            customerAddress: customerAddress,
            totalAmount: totalAmount,
            status: status,
            jobType: jobType,
            locationUrl: locationUrl,
            billImageUrl: billImageUrl,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
            distanceKm: distanceKm,
            fuelCostEstimate: fuelCostEstimate,
            createdAt: createdAt,
            completedAt: completedAt,
          );

          // 🗑️ Delete from Firebase only if archived or already exists AND time is past 16:30
          if (archiveResult > 0 || archiveResult == -1) {
            final now = DateTime.now();
            final cutoffTime = DateTime(now.year, now.month, now.day, 16, 30);
            
            bool shouldDelete = false;
            if (now.isAfter(cutoffTime)) {
               // เวลาปัจจุบันเลย 16:30 แล้ว -> ลบงานที่เสร็จก่อน 16:30 ของวันนี้ทิ้ง
               if (completedAt == null || completedAt.isBefore(cutoffTime)) {
                 shouldDelete = true;
               }
            } else {
               // เวลาปัจจุบันยังไม่ถึง 16:30 -> ลบเฉพาะงานที่เสร็จก่อน 16:30 ของเมื่อวาน (หลงเหลือ)
               final yesterdayCutoff = cutoffTime.subtract(const Duration(days: 1));
               if (completedAt == null || completedAt.isBefore(yesterdayCutoff)) {
                 shouldDelete = true;
               }
            }

            if (shouldDelete) {
              await _firebaseService.deleteJob(jobId);
              if (archiveResult == -1) {
                debugPrint('♻️ [Archive] $jobId already in SQL. Cleared from Cloud (passed 16:30 cutoff).');
              } else {
                debugPrint('✅ [Archive] $jobId saved and deleted from Cloud (passed 16:30 cutoff).');
              }
            } else {
              if (archiveResult == -1) {
                // Already in SQL, kept on cloud until cutoff
              } else {
                debugPrint('✅ [Archive] $jobId saved to SQL. Keeping on Cloud until 16:30.');
              }
            }
          } else {
            debugPrint('❌ [Archive] Failed to save $jobId to MySQL. Keeping on Cloud for retry.');
          }
        }
        debugPrint('✅ [AutoCleanup] Processed ${archivableJobs.length} jobs (Archived to SQL, deleted if >= 16:30).');
      }
    } catch (e) {
      debugPrint('⚠️ [AutoCleanup] Archivable Jobs Error: $e');
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }

  // ✅ New Method: Fetch Active (Pending/Shipping) Jobs for UI
  Future<List<Map<String, dynamic>>> fetchActiveDeliveryJobs() async {
    if (!await _ensureAuth()) {
      debugPrint('⚠️ [DeliveryService] Auth failed. Cannot fetch active jobs.');
      return [];
    }
    return await _firebaseService.fetchActiveDeliveryJobs();
  }

  // ✅ Task 2: Public method ให้ UI เรียก Sync ได้จากหน้ารายงาน
  Future<void> syncNow() async {
    debugPrint('🔄 [DeliveryService] Manual Sync triggered from UI...');
    
    // 👤 Force identity refresh to avoid permission-denied
    final authSuccess = await _ensureAuth(forceRefresh: true);
    if (!authSuccess) {
      debugPrint('❌ [DeliveryService] Manual Sync aborted: Auth Failed.');
      return;
    }
    
    try {
      // 1. Cleanup Expired Pickup Jobs (Optional/Background)
      await _cleanupExpiredPickupJobs();
      
      // 2. Archive Completed Delivery Jobs (Main Task)
      debugPrint('📦 Starting archival process...');
      await _cleanupArchivableJobs();

      // 3. ✅ Retroactive Backfill: เติมข้อมูลย้อนหลังให้ records เก่า
      final repo = DeliveryHistoryRepository(db: _dbService);
      final settings = SettingsService();

      // 3a. แยก GPS coordinates จาก locationUrl สำหรับ records ที่ยังไม่มี
      final coordsFilled = await repo.backfillDestinationCoords();
      if (coordsFilled > 0) {
        debugPrint('📍 [Backfill] Coordinates filled for $coordsFilled records.');
      }

      // 3b. คำนวณระยะทาง + ค่าน้ำมัน ย้อนหลัง (ใช้ OSRM)
      final shopLat = settings.shopLatitude;
      final shopLng = settings.shopLongitude;
      if (shopLat != 0.0 && shopLng != 0.0) {
        final distFilled = await repo.backfillDistanceAndFuel(
          shopLat: shopLat,
          shopLng: shopLng,
          fuelRate: settings.fuelCostPerKm,
          calcRoadDistance: _getRoadDistanceRoundTrip,
        );
        if (distFilled > 0) {
          debugPrint('⛽ [Backfill] Distance/fuel recalculated for $distFilled records.');
        }
      }
      
      debugPrint('✅ [DeliveryService] Manual Sync complete.');
    } catch (e) {
      debugPrint('⚠️ [DeliveryService] Sync encountered errors: $e');
    }
  }

  Future<void> createDeliveryJob({
    required int orderId,
    required Customer customer,
    required List<OrderItem> items,
    required double grandTotal,
    double vatAmount = 0.0,
    bool isManual = false,
    String? note,
    Uint8List? billPdfData,
    String jobType = 'delivery',
    String paymentMethod = 'cash', // ✅ Added paymentMethod to capture COD/Cash
  }) async {
    // Phase 7.3: Firebase auth check — fail gracefully ถ้า Background call
    if (FirebaseAuth.instance.currentUser == null) {
      bool loginSuccess = false;
      try {
        final settings = SettingsService();
        final email = settings.firebaseAuthEmail;
        final password = settings.firebaseAuthPassword;

        if (email.isNotEmpty && password.isNotEmpty) {
          debugPrint('☁️ Auto-connecting to S_MartPOS Cloud...');
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (FirebaseAuth.instance.currentUser != null) {
            loginSuccess = true;
            debugPrint('✅ Auto-connection successful!');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Auto-login failed: $e');
      }

      if (!loginSuccess) {
        if (isManual) {
          // แสดง error ให้ UI รับรู้ เมื่อผู้ใช้กดเอง
          throw Exception(
              'เครื่องนี้ยังไม่ได้เชื่อมต่อระบบ S_MartPOS Cloud (Auth Failed)\nกรุณาไปที่ ตั้งค่า > การเชื่อมต่อ > Firebase แล้วตรวจสอบ Email/Password');
        } else {
          // Phase 7.3: Background call → log เงียบๆ ไม่ throw ไม่กระทบ MySQL ที่ commit ไปแล้ว
          debugPrint(
              '⚠️ [DeliveryJob] Firebase auth failed for Order #$orderId. Delivery job skipped (Background). MySQL order already saved.');
          return;
        }
      }
    }

    try {
      // 1. Sync Points (if linked) - DISABLED as requested
      /*
      if (customer.firebaseUid != null) {
        _firebaseService
            .updateCustomerPoints(
              firebaseUid: customer.firebaseUid!,
              newTotalPoints: customer.currentPoints,
            )
            .catchError((e) => debugPrint("Firebase Points Sync Error: $e"));
      }
      */

      // 2. Create Job in Firebase
      final bool isPickup = jobType == 'pickup' || jobType == 'customer_pickup';
      // ✅ Pickup jobs start as 'pending' so they appear in S-Link pickup screen
      // They will auto-delete from Firestore after 60 min (no MySQL archiving)
      final String initialStatus = isPickup ? 'pending' : 'pending';

      final jobId = await _firebaseService.createDeliveryJob(
        localOrderId: orderId,
        customer: customer,
        items: items,
        grandTotal: grandTotal,
        dbService: _dbService,
        note: note,
        billImageUrls: [],
        jobType: jobType,
        vatAmount: vatAmount,
        status: initialStatus, // ✅ Set initial status
        paymentMethod: paymentMethod, // ✅ Pass paymentMethod
      );

      if (jobId == null) return;

      // 3. Notify Telegram
      try {
        if (await _telegramService
            .shouldNotify(TelegramService.keyNotifyDelivery)) {
          final title = (jobType == 'pickup' || jobType == 'customer_pickup')
              ? '🛍️ *ลูกค้าเข้ารับเอง (Pickup)*'
              : '🚚 *มีงานจัดส่งใหม่*';
          String msg = '$title ${isManual ? "(Manual)" : ""}\n'
              '━━━━━━━━━━━━━━━━━━\n'
              '🧾 *เลขที่บิล:* #$orderId\n'
              '👤 *ลูกค้า:* ${customer.name}\n'
              '📍 *ที่อยู่:* ${customer.shippingAddress ?? customer.address ?? "-"}\n'
              '💰 *ยอดเงิน:* ${grandTotal.toStringAsFixed(2)} บาท\n';
          if (note != null) msg += '📝 *หมายเหตุ:* $note\n';
          msg += '━━━━━━━━━━━━━━━━━━';
          _telegramService.sendMessage(msg);
        }
      } catch (e) {
        debugPrint('⚠️ Telegram Notify Error: $e');
      }

      // 4. Update Local Order Status if Manual (DISABLED: Don't change status to HELD)
      // if (isManual) {
      //   await _dbService.execute(
      //     'UPDATE `order` SET status = :status WHERE id = :oid',
      //     {'status': 'HELD', 'oid': orderId},
      //   );
      // }

      // 5. Sync Job ID to Local DB
      try {
        final String localStatus = isPickup ? 'PENDING' : 'PENDING';

        final existsRes = await _dbService.query(
            'SELECT orderId FROM delivery_jobs WHERE orderId = :oid',
            {'oid': orderId});
        if (existsRes.isEmpty) {
          await _dbService.execute(
            'INSERT INTO delivery_jobs (orderId, firebaseJobId, status) VALUES (:oid, :fid, :status)',
            {'oid': orderId, 'fid': jobId, 'status': localStatus},
          );
        } else {
          await _dbService.execute(
            'UPDATE delivery_jobs SET firebaseJobId = :fid, status = :status WHERE orderId = :oid',
            {'oid': orderId, 'fid': jobId, 'status': localStatus},
          );
        }
      } catch (e) {
        debugPrint('⚠️ Local DB Delivery Sync Error: $e');
      }

      // 6. Upload Bill Image
      if (billPdfData != null) {
        // Fire and forget, but with Future return type for better testing/handling if needed later
        _uploadBillImageInBackground(jobId, orderId, billPdfData);
      }

      // 7. Notification: Preparing (or Thank You for Pickup)
      try {
        if (!isPickup && !isManual && customer.lineUserId != null) {
          debugPrint('📤 [DeliveryService] Skipping duplicate Stage 1 Notification (Handled by OrderProcessing/NotificationService)');
          // Removed manual push to prevent duplicate Stage 1 messages.
          // NotificationService.sendSaleNotification (scenario 2 & 4) already sends detailed Stage 1.
        }
      } catch (e) {
        debugPrint('⚠️ Line Notification Error: $e');
      }
    } catch (e) {
      debugPrint('Error creating delivery job: $e');
      if (isManual) {
        rethrow; // Rethrow if triggered manually so UI can show error
      }
    }
  }

  Future<void> _uploadBillImageInBackground(
      String jobId, int orderId, Uint8List pdfData) async {
    if (pdfData.isEmpty) return;

    debugPrint('⏳ [Bill] Processing bill image for Job $jobId...');

    try {
      await Future.delayed(const Duration(seconds: 1));

      // Rasterize PDF to PNG
      await for (var page in Printing.raster(pdfData, pages: [0], dpi: 72)) {
        final pngBytes = await page.toPng();

        // 1. Save to Local Backend Folder
        final filename = 'bill_$orderId.png';
        final basePath = SettingsService().billsBasePath;
        final savePath = '$basePath/$filename';

        final file = File(savePath);
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsBytes(pngBytes);
        debugPrint('💾 [Bill] Saved locally: $savePath');

        debugPrint(
            '✅ [Bill] Saved Delivery Note locally, skipping Line image push for Stage 1.');

        break;
      }
    } catch (e) {
      debugPrint('⚠️ [Bill] Error processing bill: $e');
    }
  }

  // ── OSRM Road Distance (Round Trip) ───────────────────────────
  /// ดึงระยะทางถนนจริงเส้นทางเดียว (กิโลเมตร) × 2 สำหรับไปกลับ
  /// Fallback: Haversine × 1.4 (road factor) × 2 ถ้า OSRM ไม่ตอบ
  Future<double> _getRoadDistanceRoundTrip(
      double lat1, double lon1, double lat2, double lon2) async {
    try {
      // OSRM: lon,lat order (!สำคัญ: ลองkก่อน)
      final url =
          'http://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=false';
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'POS-Desktop/1.0');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(const Utf8Decoder()).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final routes = json['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final distanceM = (routes[0]['distance'] as num).toDouble();
          final oneWayKm = distanceM / 1000.0;
          debugPrint('✅ OSRM: ${oneWayKm.toStringAsFixed(2)} km × 2 = ${(oneWayKm * 2).toStringAsFixed(2)} km (RT)');
          return oneWayKm * 2; // ไปกลับ
        }
      }
    } catch (e) {
      debugPrint('⚠️ OSRM failed: $e — falling back to Haversine ×1.4 ×2');
    }
    // Fallback: เส้นตรง × 1.4 (road factor) × 2 (ไปกลับ)
    return _haversineDistance(lat1, lon1, lat2, lon2) * 1.4 * 2;
  }

  // ── Haversine Distance Formula ─────────────────────────────────
  /// คำนวณระยะทางเส้นตรงระหว่าง 2 พิกัด GPS (กิโลเมตร)
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0;
    final double dLat = _deg2rad(lat2 - lat1);
    final double dLon = _deg2rad(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);
}
