import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../../models/order_item.dart';
import '../../alert_service.dart';

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
      final now = DateTime.now();

      final pdf = pw.Document();
      final fontData = await rootBundle.load('assets/fonts/sarabun/Sarabun-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final style = pw.TextStyle(font: ttf, fontSize: 18);
      final headerStyle = pw.TextStyle(font: ttf, fontSize: 22, fontWeight: pw.FontWeight.bold);

      pdf.addPage(pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text('ใบจัดเตรียมสินค้า (Picking List)', style: headerStyle)),
                pw.Center(child: pw.Text('หน้าร้าน (Front Store)', style: headerStyle)),
                pw.Divider(),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('วันที่: ${DateFormat('dd/MM/yyyy HH:mm', 'th').format(now)}', style: style.copyWith(fontSize: 14)),
                      pw.Text('Items: ${items.length}', style: style.copyWith(fontSize: 14)),
                    ]),
                pw.Divider(),
                pw.SizedBox(height: 5),
                ...items.map((item) {
                  return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.productName, style: style.copyWith(fontWeight: pw.FontWeight.bold)),
                          pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('จำนวน: ${NumberFormat('#,##0.##').format(item.quantity)}', style: style),
                                if (item.product?.shelfLocation != null && item.product!.shelfLocation!.isNotEmpty)
                                  pw.Container(
                                      color: PdfColors.black,
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                                      child: pw.Text('Shelf: ${item.product!.shelfLocation}', style: style.copyWith(color: PdfColors.white)))
                              ]),
                          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                        ],
                      ));
                }),
                pw.SizedBox(height: 20),
                pw.Center(child: pw.Text('___ จัดสินค้าเรียบร้อย ___', style: style.copyWith(fontSize: 14))),
              ],
            );
          }));

      final bytes = await pdf.save();

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
