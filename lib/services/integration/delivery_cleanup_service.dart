import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../services/mysql_service.dart';
import '../../services/settings_service.dart';
import '../../repositories/delivery_history_repository.dart';
import 'delivery_distance_service.dart';
import '../logger_service.dart';

class DeliveryCleanupService {
  final MySQLService _dbService;
  final FirebaseService _firebaseService;
  final DeliveryDistanceService _distanceService;
  Timer? _cleanupTimer;

  DeliveryCleanupService(
    this._dbService,
    this._firebaseService,
    this._distanceService,
  );

  void startAutoCleanupTimer() {
    LoggerService.info('DeliveryCleanup', 'Starting Auto-Cleanup Timer for Pickup Jobs...');
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 20), (timer) async {
      await cleanupExpiredPickupJobs();
      await cleanupArchivableJobs();
    });
  }

  Future<bool> ensureAuth({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // 🔥 Force refresh token if requested or if we already have a user
        // This fixes 'permission-denied' on Windows Desktop when session markers expire.
        await user.getIdToken(forceRefresh || !kDebugMode); 
        LoggerService.info('DeliveryCleanup', 'Token valid for: ${user.email} (UID: ${user.uid})');
        return true;
      } catch (e) {
        LoggerService.error('DeliveryCleanup', 'Token refresh failed. Re-authenticating...', e);
      }
    }

    try {
      final settings = SettingsService();
      final email = settings.firebaseAuthEmail;
      final password = settings.firebaseAuthPassword;

      if (email.isEmpty || password.isEmpty) {
        LoggerService.warning('DeliveryCleanup', 'No Firebase credentials in Settings.');
        return false;
      }

      LoggerService.info('DeliveryCleanup', 'Connecting to S_MartPOS Cloud ($email)...');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final newUser = FirebaseAuth.instance.currentUser;
      if (newUser != null) {
        LoggerService.info('DeliveryCleanup', 'Signed in successfully! (UID: ${newUser.uid})');
        return true;
      }
      return false;
    } catch (e) {
      LoggerService.error('DeliveryCleanup', 'Firebase Login Error', e);
      return false;
    }
  }

  Future<void> cleanupExpiredPickupJobs() async {
    try {
      // ✅ 0. Check Auth
      if (!await ensureAuth()) {
        LoggerService.warning('DeliveryCleanup', 'Auth failed. Skipping expired jobs cleanup.');
        return;
      }

      // 1. Fetch jobs older than 60 minutes
      final expiredJobIds = await _firebaseService.fetchExpiredPickupJobs(60);

      if (expiredJobIds.isNotEmpty) {
        LoggerService.info('DeliveryCleanup', 'Found ${expiredJobIds.length} expired pickup jobs. Deleting...');

        for (final jobId in expiredJobIds) {
          await _firebaseService.deleteJob(jobId);
        }
        LoggerService.info('DeliveryCleanup', 'Deleted ${expiredJobIds.length} jobs.');
      }
    } catch (e) {
      LoggerService.error('DeliveryCleanup', 'Error in cleanupExpiredPickupJobs', e);
    }
  }

  Future<void> cleanupArchivableJobs() async {
    try {
      // ✅ 0. Check Auth
      if (!await ensureAuth()) {
        LoggerService.warning('DeliveryCleanup', 'Auth failed. Skipping archiving.');
        return;
      }

      final archivableJobs = await _firebaseService.fetchArchivableJobs();

      if (archivableJobs.isNotEmpty) {
        LoggerService.info('DeliveryCleanup', 'Found ${archivableJobs.length} completed/cancelled jobs. Archiving...');

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

          LoggerService.info('DeliveryCleanup', 'Job: $jobId | Order: $orderId | Driver: $driverName | Plate: $vehiclePlate');

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
              LoggerService.error('DeliveryCleanup', 'Error parsing location', e);
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
                final dbRes = await _dbService.query(
                  'SELECT distanceKm FROM customer WHERE firstName LIKE :cname OR CONCAT(firstName, " ", IFNULL(lastName, "")) LIKE :cname LIMIT 1', 
                  {'cname': '%$customerName%'}
                );
                if (dbRes.isNotEmpty) {
                  distanceKm = double.tryParse(dbRes.first['distanceKm']?.toString() ?? '0') ?? 0.0;
                  if (distanceKm > 0.0) {
                    fuelCostEstimate = distanceKm * fuelRate;
                    LoggerService.info('DeliveryCleanup', 'Using Predefined Customer Distance: ${distanceKm.toStringAsFixed(2)} km | Fuel: ฿${fuelCostEstimate.toStringAsFixed(2)}');
                  }
                }
              } catch (e) {
                LoggerService.error('DeliveryCleanup', 'Could not fetch customer distance', e);
              }
            }

            // 🌟 2. ถ้าลูกค้าไม่มีระยะทางที่ตั้งไว้ ให้คำนวณจาก GPS ปลายทาง (OSRM)
            if (distanceKm == 0.0) {
              final dLat = destinationLat ?? 0.0;
              final dLng = destinationLng ?? 0.0;
              if (shopLat != 0.0 && shopLng != 0.0 && dLat != 0.0 && dLng != 0.0) {
                distanceKm = await _distanceService.getRoadDistanceRoundTrip(shopLat, shopLng, dLat, dLng);
                fuelCostEstimate = distanceKm * fuelRate;
                LoggerService.info('DeliveryCleanup', 'Road Distance (RT): ${distanceKm.toStringAsFixed(2)} km | Fuel: ฿${fuelCostEstimate.toStringAsFixed(2)}');
              } else if (shopLat == 0.0 || shopLng == 0.0) {
                LoggerService.warning('DeliveryCleanup', 'Shop GPS not configured. Skipping distance calc.');
              }
            }
          } catch (e) {
            LoggerService.error('DeliveryCleanup', 'Error calculating distance', e);
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
                LoggerService.info('DeliveryCleanup', '$jobId already in SQL. Cleared from Cloud (passed 16:30 cutoff).');
              } else {
                LoggerService.info('DeliveryCleanup', '$jobId saved and deleted from Cloud (passed 16:30 cutoff).');
              }
            } else {
              if (archiveResult == -1) {
                // Already in SQL, kept on cloud until cutoff
              } else {
                LoggerService.info('DeliveryCleanup', '$jobId saved to SQL. Keeping on Cloud until 16:30.');
              }
            }
          } else {
            LoggerService.warning('DeliveryCleanup', 'Failed to save $jobId to MySQL. Keeping on Cloud for retry.');
          }
        }
        LoggerService.info('DeliveryCleanup', 'Processed ${archivableJobs.length} jobs (Archived to SQL, deleted if >= 16:30).');
      }
    } catch (e) {
      LoggerService.error('DeliveryCleanup', 'Archivable Jobs Error', e);
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
    LoggerService.info('DeliveryCleanup', 'Auto-Cleanup Timer Cancelled (disposed).');
  }
}
