import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

abstract class PdfTemplate {
  static pw.Font? baseFont;
  static pw.Font? boldFont;
  static bool fontsLoaded = false;

  Future<void> loadFonts() async {
    if (fontsLoaded) return;
    try {
      final fontData = await rootBundle.load('assets/fonts/THSarabunNew.ttf');
      baseFont = pw.Font.ttf(fontData);
      final boldFontData =
          await rootBundle.load('assets/fonts/THSarabunNew Bold.ttf');
      boldFont = pw.Font.ttf(boldFontData);
      fontsLoaded = true;
    } catch (e) {
      // ignore: avoid_print
      print('Error loading PDF fonts: $e');
    }
  }

  pw.TextStyle style(String type, {PdfColor? color}) {
    final base = baseFont ?? pw.Font.helvetica();
    final bold = boldFont ?? pw.Font.helveticaBold();

    switch (type) {
      case 'h1':
        return pw.TextStyle(font: bold, fontSize: 30, color: color);
      case 'h2':
        return pw.TextStyle(font: bold, fontSize: 24, color: color);
      case 'h3':
        return pw.TextStyle(font: bold, fontSize: 16, color: color);
      case 'body':
        return pw.TextStyle(font: base, fontSize: 14, color: color);
      case 'body-bold':
        return pw.TextStyle(font: bold, fontSize: 14, color: color);
      case 'small':
        return pw.TextStyle(font: base, fontSize: 12, color: color);
      default:
        return pw.TextStyle(font: base, fontSize: 14, color: color);
    }
  }

  pw.Widget buildHeader(String docTitle, String docSubtitle,
      List<pw.Widget> leftInfo, List<pw.Widget> rightInfo) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: leftInfo),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(docTitle, style: style('h1')),
              pw.Text(docSubtitle,
                  style: style('body-bold', color: PdfColors.grey)),
              pw.SizedBox(height: 8),
              ...rightInfo,
            ],
          ),
        ],
      ),
      pw.Divider(),
    ]);
  }

  pw.Widget buildSignatureBox(String label) {
    return pw.Column(children: [
      pw.Container(
        width: 150,
        height: 1,
        color: PdfColors.black,
      ),
      pw.SizedBox(height: 5),
      pw.Text(label, style: style('body')),
      pw.SizedBox(height: 20),
      pw.Text('(___ / ___ / ___)', style: style('small')),
    ]);
  }

  pw.Widget tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: style('body-bold'), textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget tableCell(String text, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: style('body'), textAlign: align),
    );
  }
}
