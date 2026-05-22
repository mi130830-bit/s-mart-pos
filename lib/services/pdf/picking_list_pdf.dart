import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../models/order_item.dart';
import 'pdf_helper.dart';

class PickingListPdf {
  static Future<Uint8List> generate({
    required List<OrderItem> items,
    required PdfPageFormat pageFormat,
  }) async {
    await initializeDateFormatting('th', null);
    final pdf = pw.Document();
    
    // ดึงฟอนต์ผ่าน PdfHelper (เพื่อใช้ประสิทธิภาพของระบบฟอนต์แคชใน Step 2)
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();
    
    final style = pw.TextStyle(font: font, fontSize: 18);
    final headerStyle = pw.TextStyle(font: fontBold, fontSize: 22, fontWeight: pw.FontWeight.bold);
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
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
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 5),
              ...items.map((item) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item.productName, style: style.copyWith(fontWeight: pw.FontWeight.bold, font: fontBold)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('จำนวน: ${NumberFormat('#,##0.##').format(item.quantity.toDouble())}', style: style),
                          if (item.product?.shelfLocation != null && item.product!.shelfLocation!.isNotEmpty)
                            pw.Container(
                              color: PdfColors.black,
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                              child: pw.Text('Shelf: ${item.product!.shelfLocation}', style: style.copyWith(color: PdfColors.white)),
                            ),
                        ],
                      ),
                      pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('___ จัดสินค้าเรียบร้อย ___', style: style.copyWith(fontSize: 14))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
