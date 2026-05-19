import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../local_settings_service.dart';
import '../label_printer_service.dart';
import '../../pdf/barcode_label_pdf.dart';
import '../core/print_core_service.dart';
import '../utils/print_settings_helper.dart';
import '../../../models/label_config.dart';

class BarcodeLabelHandler {
  static Future<void> printBarcode({
    required String barcode,
    required String name,
    required double price,
    Printer? printerOverride,
  }) async {
    final settings = LocalSettingsService();
    final sizeStr = await settings.getBarcodePaperSize();
    final printer = printerOverride ?? await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyBarcodePrinter);

    if (sizeStr == '103mmx27mm') {
      await LabelPrinterService().smartPrintBarcode(
          type: LabelType.barcode406x108,
          barcode: barcode,
          name: name,
          price: price);
      return;
    }
    if (sizeStr == '32mmx25mm') {
      await LabelPrinterService().smartPrintBarcode(
          type: LabelType.barcode32x25,
          barcode: barcode,
          name: name,
          price: price);
      return;
    }

    double width = 4.0 * PdfPageFormat.cm;
    double height = 3.0 * PdfPageFormat.cm;
    if (sizeStr == '50mmx30mm') {
      width = 5.0 * PdfPageFormat.cm;
      height = 3.0 * PdfPageFormat.cm;
    }

    final format = PdfPageFormat(width, height, marginAll: 2 * PdfPageFormat.mm);
    final bytes = await BarcodeLabelPdf.generate(
      barcode: barcode,
      name: name,
      price: price,
      pageFormat: format,
    );

    await PrintCoreService.printDocument(
      bytes: bytes,
      docName: 'Label_$barcode',
      format: format,
      printer: printer,
      isPreview: false,
    );
  }
}
