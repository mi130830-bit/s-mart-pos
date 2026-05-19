import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../../../repositories/shift_repository.dart';
import '../../alert_service.dart';

import '../core/print_core_service.dart';
import '../utils/print_settings_helper.dart';
import '../utils/print_data_helper.dart';

import '../shift_report_pdf.dart';

class ShiftReportHandler {
  static Future<void> printShiftClosingSlip({
    required ShiftSummary shift,
    required String paperSize,
    Printer? printerOverride,
    bool isPreview = false,
  }) async {
    try {
      final shopInfo = await PrintDataHelper.getShopInfo();
      Uint8List bytes;
      PdfPageFormat format;
      String targetPrinterKey = PrintSettingsHelper.keyCashPrinter;

      if (paperSize == 'A4' || paperSize == 'SAVE_PDF') {
        format = PdfPageFormat.a4;
        bytes = await ShiftReportPdf.generateFull(shift: shift, shopInfo: shopInfo);
      } else {
        // Thermal or A5 (Shortened version)
        if (paperSize == 'A5') {
          format = PdfPageFormat.a5;
        } else if (paperSize == '80mm') {
          format = PdfPageFormat(
            72 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 1 * PdfPageFormat.mm,
          );
        } else {
          format = await PrintSettingsHelper.getCashPageFormat();
        }
        bytes = await ShiftReportPdf.generateShort(shift: shift, shopInfo: shopInfo, pageFormat: format);
      }

      final printer = printerOverride ?? await PrintSettingsHelper.getPrinterBySettingKey(targetPrinterKey);
      final docName = 'Shift_Summary_${DateFormat('yyyyMMdd_HHmm').format(shift.closedAt)}';

      await PrintCoreService.printDocument(
        bytes: bytes,
        docName: docName,
        format: format,
        printer: printer,
        isPreview: paperSize == 'SAVE_PDF' || isPreview,
      );
    } catch (e, stack) {
      debugPrint('❌ printShiftClosingSlip Error: $e\n$stack');
      AlertService.show(message: 'พิมพ์สรุปกะไม่สำเร็จ: ${e.toString()}', type: 'error');
    }
  }
}
