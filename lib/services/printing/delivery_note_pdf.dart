import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import '../pdf/pdf_helper.dart';

class DeliveryNotePdf {
  static Future<Uint8List> generate({
    required int orderId,
    required List<OrderItem> items,
    required Customer? customer,
    double discount = 0.0,
    double vatAmount = 0.0,
    double? grandTotalOverride,
    required ShopInfo shopInfo,
    required PdfPageFormat pageFormat,
    bool showRuler = false,
    String? remark,
  }) async {
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();

    final pdf =
        pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));

    pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(15),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
                child: pw.Text('ใบส่งของ / Delivery Note',
                    style: pw.TextStyle(font: fontBold, fontSize: 16))),
            pw.SizedBox(height: 5),
            pw.Text('ลูกค้า: ${customer?.name ?? "-"}',
                style: pw.TextStyle(font: font, fontSize: 12)),
            pw.Divider(),
            pw.Expanded(
              child: pw.Column(
                children: items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                            child: pw.Text(item.productName,
                                style: pw.TextStyle(font: font, fontSize: 10))),
                        pw.Text('${item.quantity} หน่วย',
                            style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            pw.Divider(),
            pw.Center(
                child: pw.Text('ขอบคุณที่ใช้บริการ',
                    style: pw.TextStyle(font: font, fontSize: 10))),
          ],
        );
      },
    ));
    return pdf.save();
  }
}
