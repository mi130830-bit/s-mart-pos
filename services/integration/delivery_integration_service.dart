import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../../services/firebase_service.dart';
import '../../services/telegram_service.dart';
import '../../services/mysql_service.dart';
import '../../models/customer.dart';
import '../../models/order_item.dart';

class DeliveryIntegrationService {
  final MySQLService _dbService;
  final FirebaseService _firebaseService;
  final TelegramService _telegramService = TelegramService();

  DeliveryIntegrationService(this._dbService, this._firebaseService);

  Future<void> createDeliveryJob({
    required int orderId,
    required Customer customer,
    required List<OrderItem> items,
    required double grandTotal,
    bool isManual = false,
    String? note,
    Uint8List? billPdfData,
    String jobType = 'delivery',
  }) async {
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
      final jobId = await _firebaseService.createDeliveryJob(
        localOrderId: orderId,
        customer: customer,
        items: items,
        grandTotal: grandTotal,
        dbService: _dbService,
        note: note,
        billImageUrls: [],
        jobType: jobType,
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
        final existsRes = await _dbService.query(
            'SELECT orderId FROM delivery_jobs WHERE orderId = :oid',
            {'oid': orderId});
        if (existsRes.isEmpty) {
          await _dbService.execute(
            'INSERT INTO delivery_jobs (orderId, firebaseJobId, status) VALUES (:oid, :fid, :status)',
            {'oid': orderId, 'fid': jobId, 'status': 'PENDING'},
          );
        } else {
          await _dbService.execute(
            'UPDATE delivery_jobs SET firebaseJobId = :fid, status = :status WHERE orderId = :oid',
            {'oid': orderId, 'fid': jobId, 'status': 'PENDING'},
          );
        }
      } catch (e) {
        debugPrint('⚠️ Local DB Delivery Sync Error: $e');
      }

      // 6. Upload Bill Image
      if (billPdfData != null) {
        _uploadBillImageInBackground(jobId, orderId, billPdfData);
      }
    } catch (e) {
      debugPrint('Error creating delivery job: $e');
      if (isManual) {
        rethrow; // Rethrow if triggered manually so UI can show error
      }
    }
  }

  void _uploadBillImageInBackground(
      String jobId, int orderId, Uint8List pdfData) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      List<String> imageUrls = [];
      try {
        await for (var page in Printing.raster(pdfData, pages: [0], dpi: 200)) {
          final pngBytes = await page.toPng();
          final url = await _firebaseService.uploadBillImage(
              pngBytes, 'order_$orderId');
          if (url != null) imageUrls.add(url);
          break;
        }
      } catch (innerError) {
        debugPrint('⚠️ Error inside Printing.raster loop: $innerError');
      }
      if (imageUrls.isNotEmpty) {
        await _firebaseService.updateJob(jobId, {'bill_image_urls': imageUrls});
      }
    } catch (e) {
      debugPrint('⚠️ Background upload crash avoided: $e');
    }
  }
}
