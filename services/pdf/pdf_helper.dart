import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/services.dart' show rootBundle;

class PdfHelper {
  // Keys for Logo & Shop Info
  static const String _keyShopLogo = 'shop_logo_base64';

  static Future<pw.Font> getFontRegular() async {
    await initializeDateFormatting('th', null);
    try {
      // 1. Try Local Asset
      final fontData =
          await rootBundle.load("assets/fonts/sarabun/Sarabun-Regular.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('⚠️ Error loading local Sarabun Regular: $e');
      // 2. Fallback to GoogleFonts
      try {
        return await PdfGoogleFonts.sarabunRegular();
      } catch (e2) {
        debugPrint('⚠️ Error loading GoogleFonts Sarabun Regular: $e2');
        return pw.Font.helvetica();
      }
    }
  }

  static Future<pw.Font> getFontBold() async {
    try {
      // 1. Try Local Asset
      final fontData =
          await rootBundle.load("assets/fonts/sarabun/Sarabun-Bold.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('⚠️ Error loading local Sarabun Bold: $e');
      // 2. Fallback to GoogleFonts
      return await PdfGoogleFonts.sarabunBold();
    }
  }

  static Future<pw.MemoryImage?> getLogo() async {
    final prefs = await SharedPreferences.getInstance();
    final base64String = prefs.getString(_keyShopLogo);
    if (base64String != null) {
      try {
        return pw.MemoryImage(base64Decode(base64String));
      } catch (e) {
        debugPrint('Error decoding logo: $e');
      }
    }
    return null;
  }

  // Draw Ruler Overlay (for verifying dimension)
  static pw.Widget buildRuler(double width, double height, pw.Font font) {
    return pw.Stack(children: [
      // Top Ruler (cm ticks)
      ...List.generate((width / PdfPageFormat.cm).ceil(), (index) {
        final x = index * PdfPageFormat.cm;
        return pw.Positioned(
          top: 0,
          left: x,
          child: pw.Column(children: [
            pw.Container(
                height: index % 5 == 0 ? 5 : 2,
                width: 1,
                color: PdfColors.black),
            if (index > 0)
              pw.Text('$index', style: pw.TextStyle(font: font, fontSize: 6))
          ]),
        );
      }),
      // Left Ruler (cm ticks)
      ...List.generate((height / PdfPageFormat.cm).ceil(), (index) {
        final y = index * PdfPageFormat.cm;
        return pw.Positioned(
          top: y,
          left: 0,
          child: pw.Row(children: [
            pw.Container(
                width: index % 5 == 0 ? 5 : 2,
                height: 1,
                color: PdfColors.black),
            if (index > 0)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 2),
                  child: pw.Text('$index',
                      style: pw.TextStyle(font: font, fontSize: 6)))
          ]),
        );
      }),
    ]);
  }

  static pw.Widget buildSignatureBox(
      String label, pw.Font font, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text('......................................................'),
        pw.SizedBox(height: 4),
        pw.Text(label, style: pw.TextStyle(font: fontBold, fontSize: 10)),
        pw.Text('วันที่ ..../..../....',
            style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    );
  }

  static pw.Widget buildLabelValueRow(String label, String value, pw.Font font,
      {double fontSize = 11}) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 35,
          child: pw.Text(label,
              style: pw.TextStyle(font: font, fontSize: fontSize),
              textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: fontSize)),
      ],
    );
  }

  static pw.Widget buildTableHeader(String text, pw.Font font, double size,
      {pw.TextAlign align = pw.TextAlign.center, double padding = 5.0}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: padding),
      child: pw.Text(text,
          style: pw.TextStyle(font: font, fontSize: size), textAlign: align),
    );
  }

  static pw.Widget buildTableCell(String text, pw.Font font, double size,
      {pw.TextAlign align = pw.TextAlign.left, double padding = 4.0}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: padding),
      child: pw.Text(text,
          style: pw.TextStyle(font: font, fontSize: size), textAlign: align),
    );
  }
}
