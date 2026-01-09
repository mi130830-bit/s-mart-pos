import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class BarcodeService {
  /// Generate a PDF with barcodes for the given products.
  /// [items] is a list of maps containing 'product' and 'count'.
  Future<Uint8List> generateBarcodePdf(List<Map<String, dynamic>> items) async {
    final pdf = pw.Document();

    final List<pw.Widget> allStickers = [];

    for (var item in items) {
      final Product product = item['product'];
      final int count = item['count'] ?? 1;
      final barcode = product.barcode ?? '';

      if (barcode.isEmpty) continue;

      for (int i = 0; i < count; i++) {
        allStickers.add(
          pw.Container(
            width: 150,
            height: 80,
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  product.name,
                  style:
                      pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                pw.SizedBox(height: 2),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: barcode,
                  width: 120,
                  height: 40,
                  drawText: true,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Price: ${product.retailPrice.toStringAsFixed(2)} ฿',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Chunk the stickers into pages (3 columns x 10 rows = 30 stickers per page)
    const stickersPerPage = 21; // 3x7 for better spacing on A4
    for (var i = 0; i < allStickers.length; i += stickersPerPage) {
      final chunk = allStickers.sublist(
        i,
        (i + stickersPerPage > allStickers.length)
            ? allStickers.length
            : i + stickersPerPage,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: chunk,
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Preview and print
  Future<void> printBarcodes(List<Map<String, dynamic>> items) async {
    final pdfData = await generateBarcodePdf(items);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: 'barcodes_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
