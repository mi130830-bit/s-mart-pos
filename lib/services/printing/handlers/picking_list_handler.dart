import 'package:flutter/foundation.dart';
import '../../../models/order_item.dart';
import '../../alert_service.dart';
import '../../pdf/picking_list_pdf.dart';
import '../core/print_core_service.dart';
import '../utils/print_settings_helper.dart';

class PickingListHandler {
  static Future<void> printPickingList(List<OrderItem> items) async {
    try {
      final printer = await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyCashPrinter) ??
          await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyCashBillPrinter);

      if (printer == null) {
        debugPrint('⚠️ No printer found for Picking List.');
        return;
      }

      final pageFormat = await PrintSettingsHelper.getCashPageFormat();
      
      // ดึง bytes ที่เจนเนอเรตมาจาก PickingListPdf
      final bytes = await PickingListPdf.generate(
        items: items,
        pageFormat: pageFormat,
      );

      await PrintCoreService.printDocument(
        bytes: bytes,
        docName: 'PickingList',
        format: pageFormat,
        printer: printer,
        isPreview: false,
      );
    } catch (e) {
      debugPrint('Error printing Picking List: $e');
      AlertService.show(message: 'พิมพ์ใบจัดของไม่สำเร็จ: $e', type: 'error');
    }
  }
}
