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

  /// อัปเดตรายการสินค้าของบิลจัดส่ง (กรณีมีการแก้ไขบิล)
  Future<void> updateDeliveryJobItems({
    required int orderId,
    required List<OrderItem> items,
    required double grandTotal,
    String? oldStatus,
    double oldGrandTotal = 0.0,
  }) async {
    try {
      // 1. ตรวจสอบว่าบิลนี้มีในระบบส่งของหรือไม่
      final existsRes = await _dbService.query(
          'SELECT firebaseJobId FROM delivery_jobs WHERE orderId = :oid',
          {'oid': orderId});
      
      if (existsRes.isEmpty) return; // ไม่ใช่งานจัดส่ง หรือยังไม่เคยส่งขึ้น cloud

      final jobId = existsRes.first['firebaseJobId']?.toString();
      if (jobId == null || jobId.isEmpty) return;

      // 2. จัดเตรียมข้อมูล Items & Details เหมือนตอนสร้าง
      final bool filterEnabled = SettingsService().enableWarehouseAutoTag;
      List<OrderItem> jobItems = items;

      if (filterEnabled) {
        Set<int> warehouseProductIds = {};
        try {
          final pIds = items.map((i) => i.productId).toList();
          if (pIds.isNotEmpty) {
            final idsStr = pIds.join(',');
            final res = await _dbService.query(
                'SELECT id FROM product WHERE id IN ($idsStr) AND isWarehouseItem = 1');
            warehouseProductIds =
                res.map((r) => int.parse(r['id'].toString())).toSet();
          }
        } catch (e) {
          warehouseProductIds = items
              .where((i) => i.product?.isWarehouseItem == true)
              .map((i) => i.productId)
              .toSet();
        }

        final warehouseItems = items.where((i) => warehouseProductIds.contains(i.productId)).toList();
        if (warehouseItems.isNotEmpty) {
          jobItems = warehouseItems.map((i) {
            if (i.product != null) {
              return i.copyWith(product: i.product!.copyWith(isWarehouseItem: true));
            }
            return i;
          }).toList();
        }
      }

      String details = jobItems.map((i) {
        String txt = '${i.productName} x${i.quantity}${i.comment.isNotEmpty ? " (${i.comment})" : ""}';
        if (i.product?.shelfLocation != null && i.product!.shelfLocation!.isNotEmpty) {
          txt += ' [เก็บ: ${i.product!.shelfLocation}]';
        }
        return txt.trim();
      }).join('\n');

      if (filterEnabled && jobItems.length < items.length) {
        details += '\n📦 มีของหน้าร้าน ${items.length - jobItems.length} จำนวนรายการ';
      }

      // ตรวจสอบกรณีหนี้เพิ่ม (แก้ไขบิลเงินสด แล้วมียอดต้องเก็บปลายทาง)
      double debtDelta = grandTotal - oldGrandTotal;
      bool isPaidToUnpaid = (oldStatus == 'COMPLETED' || oldStatus == 'PAID') && debtDelta > 0.001;

      if (isPaidToUnpaid) {
        details = '⚠️ จ่ายแล้วบางส่วน! เก็บเงินปลายทางเพิ่มเฉพาะส่วนต่าง: ฿${debtDelta.toStringAsFixed(2)}\n━━━━━━━━━━━━━━━━━━\n$details';
      } else {
        details = '⚠️ มีการแก้ไขรายการสินค้า!\n━━━━━━━━━━━━━━━━━━\n$details';
      }

      final updates = {
        'details': details,
        'price': isPaidToUnpaid ? debtDelta : grandTotal, // ถ้าเดิมจ่ายแล้ว ให้แอปคนขับเก็บเฉพาะส่วนต่าง!
        if (isPaidToUnpaid) 'payment_method': 'credit', // บังคับให้เป็น COD เพื่อเก็บส่วนต่าง
        'items': jobItems.map((item) => {
                  'name': item.productName,
                  'qty': item.quantity.toDouble(),
                  'price': item.price.toDouble(),
                  'total': item.total.toDouble(),
                  'location': item.product?.shelfLocation ?? '',
                  'is_warehouse': item.product?.isWarehouseItem ?? false,
                }).toList(),
      };

      // 3. อัปเดตขึ้น Firebase
      await _firebaseService.updateJob(jobId, updates);
      LoggerService.info('DeliveryIntegration', '✅ Updated Cloud Job $jobId with new items for Order #$orderId');

      // 4. ส่งแจ้งเตือน Telegram (Option)
      try {
        if (await _telegramService.shouldNotify(TelegramService.keyNotifyDelivery)) {
          String msg = '⚠️ *มีการแก้ไขรายการบิลจัดส่ง*\n'
              '━━━━━━━━━━━━━━━━━━\n'
              '🧾 *เลขที่บิล:* #$orderId\n'
              '💰 *ยอดเงินใหม่:* ${grandTotal.toStringAsFixed(2)} บาท\n'
              '━━━━━━━━━━━━━━━━━━\n'
              'แอปคนขับอัปเดตข้อมูลอัตโนมัติแล้ว';
          _telegramService.sendMessage(msg);
        }
      } catch (e) {
        LoggerService.error('DeliveryIntegration', 'Telegram Notify Edit Error', e);
      }

    } catch (e) {
      LoggerService.error('DeliveryIntegration', 'Error updating delivery job items', e);
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
