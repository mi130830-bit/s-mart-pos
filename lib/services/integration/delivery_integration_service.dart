import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../services/firebase_service.dart';
import '../../services/telegram_service.dart';
import '../../services/mysql_service.dart';
import '../../services/settings_service.dart';
import '../../models/customer.dart';
import '../../models/order_item.dart';
import '../../repositories/delivery_history_repository.dart';
import '../logger_service.dart';
import 'delivery_distance_service.dart';
import 'delivery_cleanup_service.dart';

class DeliveryIntegrationService {
  final MySQLService _dbService;
  final FirebaseService _firebaseService;
  final TelegramService _telegramService = TelegramService();

  late final DeliveryDistanceService _distanceService;
  late final DeliveryCleanupService _cleanupService;

  DeliveryIntegrationService(this._dbService, this._firebaseService) {
    _distanceService = DeliveryDistanceService();
    _cleanupService =
        DeliveryCleanupService(_dbService, _firebaseService, _distanceService);
    _cleanupService.startAutoCleanupTimer();
  }

  void dispose() {
    _cleanupService.dispose();
  }

  /// Fetch Active (Pending/Shipping) Jobs for UI
  Future<List<Map<String, dynamic>>> fetchActiveDeliveryJobs() async {
    if (!await _cleanupService.ensureAuth()) {
      LoggerService.warning(
          'DeliveryIntegration', 'Auth failed. Cannot fetch active jobs.');
      return [];
    }
    return await _firebaseService.fetchActiveDeliveryJobs();
  }

  /// Public method ให้ UI เรียก Sync ได้จากหน้ารายงาน
  Future<void> syncNow() async {
    LoggerService.info(
        'DeliveryIntegration', 'Manual Sync triggered from UI...');

    // 👤 Force identity refresh to avoid permission-denied
    final authSuccess = await _cleanupService.ensureAuth(forceRefresh: true);
    if (!authSuccess) {
      LoggerService.error(
          'DeliveryIntegration', 'Manual Sync aborted: Auth Failed.');
      return;
    }

    try {
      // 1. Cleanup Expired Pickup Jobs
      await _cleanupService.cleanupExpiredPickupJobs();

      // 2. Archive Completed Delivery Jobs
      LoggerService.info('DeliveryIntegration', 'Starting archival process...');
      await _cleanupService.cleanupArchivableJobs();

      // 3. Retroactive Backfill: เติมข้อมูลย้อนหลังให้ records เก่า
      final repo = DeliveryHistoryRepository(db: _dbService);
      final settings = SettingsService();

      // 3a. แยก GPS coordinates จาก locationUrl สำหรับ records ที่ยังไม่มี
      final coordsFilled = await repo.backfillDestinationCoords();
      if (coordsFilled > 0) {
        LoggerService.info('DeliveryIntegration',
            'Coordinates filled for $coordsFilled records.');
      }

      // 3b. คำนวณระยะทาง + ค่าน้ำมัน ย้อนหลัง (ใช้ OSRM)
      final shopLat = settings.shopLatitude;
      final shopLng = settings.shopLongitude;
      if (shopLat != 0.0 && shopLng != 0.0) {
        final distFilled = await repo.backfillDistanceAndFuel(
          shopLat: shopLat,
          shopLng: shopLng,
          fuelRate: settings.fuelCostPerKm,
          calcRoadDistance: _distanceService.getRoadDistanceRoundTrip,
        );
        if (distFilled > 0) {
          LoggerService.info('DeliveryIntegration',
              'Distance/fuel recalculated for $distFilled records.');
        }
      }

      LoggerService.info('DeliveryIntegration', 'Manual Sync complete.');
    } catch (e) {
      LoggerService.error('DeliveryIntegration', 'Sync encountered errors', e);
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
    String paymentMethod = 'cash',
  }) async {
    final authSuccess = await _cleanupService.ensureAuth();
    if (!authSuccess) {
      if (isManual) {
        throw Exception(
            'เครื่องนี้ยังไม่ได้เชื่อมต่อระบบ S_MartPOS Cloud (Auth Failed)\nกรุณาไปที่ ตั้งค่า > การเชื่อมต่อ > Firebase แล้วตรวจสอบ Email/Password');
      } else {
        LoggerService.warning('DeliveryIntegration',
            'Firebase auth failed for Order #$orderId. Delivery job skipped (Background). MySQL order already saved.');
        return;
      }
    }

    try {
      // Create Job in Firebase
      final bool isPickup = jobType == 'pickup' || jobType == 'customer_pickup';
      final String initialStatus = 'pending';

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
        status: initialStatus,
        paymentMethod: paymentMethod,
      );

      if (jobId == null) return;

      // Notify Telegram
      try {
        if (await _telegramService
            .shouldNotify(TelegramService.keyNotifyDelivery)) {
          final title = isPickup
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
        LoggerService.error('DeliveryIntegration', 'Telegram Notify Error', e);
      }

      // Sync Job ID to Local DB
      try {
        final String localStatus = 'PENDING';

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

        // [New] ส่ง LINE "กำลังเตรียมสินค้า" (Scenario 21 สำหรับ Cash, 41 สำหรับ Credit)
        try {
          if (customer.id > 0 &&
              customer.lineUserId != null &&
              customer.lineUserId!.isNotEmpty) {
            final urlStr = SettingsService().apiUrl;
            final url = Uri.parse('$urlStr/line/push-scenario');

            // scenario: 21 (cash) or 41 (credit)
            final int lineScenario =
                paymentMethod.toLowerCase() == 'credit' ? 41 : 21;

            final payload = {
              'lineUserId': customer.lineUserId,
              'orderId': orderId.toString(),
              'scenario': lineScenario,
              'customerName': customer.name,
              'grandTotal': grandTotal,
            };

            await http
                .post(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 5));
            LoggerService.info('DeliveryIntegration',
                '✅ Sent Line Preparing Message (Scenario $lineScenario) for #$orderId');
          }
        } catch (e) {
          LoggerService.error(
              'DeliveryIntegration', 'Failed to send Preparing Line Msg', e);
        }
      } catch (e) {
        LoggerService.error(
            'DeliveryIntegration', 'Local DB Delivery Sync Error', e);
      }

      // Upload Bill Image
      if (billPdfData != null) {
        _uploadBillImageInBackground(jobId, orderId, billPdfData);
      }
    } catch (e) {
      LoggerService.error(
          'DeliveryIntegration', 'Error creating delivery job', e);
      if (isManual) {
        rethrow;
      }
    }
  }

  Future<void> _uploadBillImageInBackground(
      String jobId, int orderId, Uint8List pdfData) async {
    if (pdfData.isEmpty) return;

    LoggerService.info(
        'DeliveryIntegration', 'Processing bill image for Job $jobId...');

    try {
      await Future.delayed(const Duration(seconds: 1));

      // Rasterize PDF to PNG
      await for (var page in Printing.raster(pdfData, pages: [0], dpi: 72)) {
        final pngBytes = await page.toPng();

        // Save to Local Backend Folder
        final filename = 'bill_$orderId.png';
        final basePath = SettingsService().billsBasePath;
        final savePath = '$basePath/$filename';

        final file = File(savePath);
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsBytes(pngBytes);
        LoggerService.info('DeliveryIntegration', 'Saved locally: $savePath');
        LoggerService.info('DeliveryIntegration',
            'Saved Delivery Note locally, skipping Line image push for Stage 1.');

        break;
      }
    } catch (e) {
      LoggerService.error('DeliveryIntegration', 'Error processing bill', e);
    }
  }
}
