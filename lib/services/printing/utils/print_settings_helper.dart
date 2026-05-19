import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../local_settings_service.dart';

class PrintSettingsHelper {
  static const String keyCashPrinter = 'printer_cash_name';
  static const String keyCashBillPrinter = 'printer_cash_bill_name';
  static const String keyTaxPrinter = 'printer_tax_name';
  static const String keyDeliveryPrinter = 'printer_delivery_name';
  static const String keyBarcodePrinter = 'printer_barcode_name';

  static final PdfPageFormat customA5 = PdfPageFormat(
    22.86 * PdfPageFormat.cm, // 9 นิ้ว
    13.97 * PdfPageFormat.cm, // 5.5 นิ้ว
    marginAll: 0,
  );

  static const PdfPageFormat formatA5 = PdfPageFormat(
    148 * PdfPageFormat.mm,
    210 * PdfPageFormat.mm,
    marginAll: 0,
  );

  static Future<Printer?> getPrinterBySettingKey(String key) async {
    final settings = LocalSettingsService();

    if (key == keyBarcodePrinter) {
      final manualName = await settings.getPrinterManualName();
      if (manualName != null && manualName.isNotEmpty) {
        return Printer(url: manualName, name: manualName);
      }
    }

    String? name;
    if (key == keyCashPrinter) {
      name = await settings.getCashPrinterName();
    } else if (key == keyCashBillPrinter) {
      name = await settings.getCashBillPrinterName();
    } else if (key == keyTaxPrinter) {
      name = await settings.getTaxPrinterName();
    } else if (key == keyDeliveryPrinter) {
      name = await settings.getDeliveryPrinterName();
    } else if (key == keyBarcodePrinter) {
      name = await settings.getBarcodePrinterName();
    } else {
      name = await settings.getString(key);
    }

    if (name == null || name.isEmpty) return null;
    return Printer(url: name, name: name);
  }

  static Future<PdfPageFormat> getDeliveryPageFormat() async {
    final settings = LocalSettingsService();
    final size = await settings.getDeliveryPaperSize();
    if (size == 'A4') return PdfPageFormat.a4;
    if (size == 'A5') return PdfPageFormat.a5; // Standard A5 (Laser)
    if (size == 'Continuous') return customA5; // 9x5.5" (Dot-Matrix)
    return customA5;
  }

  static Future<PdfPageFormat> getCashPageFormat() async {
    final settings = LocalSettingsService();
    final size = await settings.getCashPaperSize();
    if (size == 'A4') return PdfPageFormat.a4;
    if (size == 'A5') return PdfPageFormat.a5; // Standard A5 (Laser)
    if (size == 'Continuous') return customA5; // 9x5.5" (Dot-Matrix)
    if (size == '58mm') {
      return PdfPageFormat(
        57 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 2 * PdfPageFormat.mm,
      );
    }
    if (size == '80mm') {
      return PdfPageFormat(
        72 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 1 * PdfPageFormat.mm,
      );
    }
    return PdfPageFormat(
      72 * PdfPageFormat.mm, // Default to 72mm instead of 71mm to prevent cutoff/rejection
      double.infinity,
      marginAll: 1 * PdfPageFormat.mm,
    );
  }

  static Future<PdfPageFormat> getCashBillPageFormat() async {
    final settings = LocalSettingsService();
    final size = await settings.getCashBillPaperSize();
    return size == 'A4' ? PdfPageFormat.a4 : customA5;
  }
}
