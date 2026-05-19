import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PrintCoreService {
  /// Core method to print or preview a PDF document.
  /// It does not know anything about LocalSettings or keys.
  static Future<void> printDocument({
    required Uint8List bytes,
    required String docName,
    required PdfPageFormat format,
    Printer? printer,
    bool isPreview = false,
  }) async {
    if (isPreview) {
      await Printing.sharePdf(bytes: bytes, filename: '$docName.pdf');
      return;
    }

    if (printer == null) {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: docName, format: format);
      return;
    }

    try {
      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) async => bytes,
        name: docName,
        format: format,
        usePrinterSettings: true,
      );
    } catch (e) {
      debugPrint('❌ Direct print failed: $e. Falling back to layoutPdf dialog.');
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: docName, format: format);
    }
  }
}
