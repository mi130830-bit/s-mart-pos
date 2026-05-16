import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import '../pdf/pdf_helper.dart';

class TaxInvoiceA4Pdf {
  static Future<Uint8List> generate({
    required int orderId,
    required List<OrderItem> items,
    required double total,
    required double grandTotal,
    required double vatRate,
    required Customer customer,
    required ShopInfo shopInfo,
    PdfPageFormat? pageFormat,
  }) async {
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();
    final moneyFmt = NumberFormat('#,##0.00');

    final pdf =
        pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));

    pdf.addPage(pw.Page(
      pageFormat: pageFormat ?? PdfPageFormat.a4,
      margin:
          pageFormat != null ? pw.EdgeInsets.zero : const pw.EdgeInsets.all(20),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
                child: pw.Text('ใบกำกับภาษี / Tax Invoice',
                    style: pw.TextStyle(font: fontBold, fontSize: 20))),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ผู้ขาย: ${shopInfo.name}',
                            style: pw.TextStyle(font: fontBold)),
                        pw.Text(shopInfo.address,
                            style: pw.TextStyle(font: font)),
                        pw.Text('เลขประจำตัวผู้เสียภาษี: ${shopInfo.taxId}',
                            style: pw.TextStyle(font: font)),
                      ]),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('เลขที่: $orderId',
                            style: pw.TextStyle(font: font)),
                        pw.Text(
                            'วันที่: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                            style: pw.TextStyle(font: font)),
                      ]),
                ]),
            pw.Divider(),
            pw.Text('ลูกค้า: ${customer.name}',
                style: pw.TextStyle(font: fontBold)),
            pw.Text('ที่อยู่: ${customer.address ?? "-"}',
                style: pw.TextStyle(font: font)),
            pw.Text('เลขผู้เสียภาษี: ${customer.taxId ?? "-"}',
                style: pw.TextStyle(font: font)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              children: [
                pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('รายการ',
                              style: pw.TextStyle(font: fontBold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('จำนวน',
                              style: pw.TextStyle(font: fontBold),
                              textAlign: pw.TextAlign.center)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('ราคา/หน่วย',
                              style: pw.TextStyle(font: fontBold),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('รวม',
                              style: pw.TextStyle(font: fontBold),
                              textAlign: pw.TextAlign.right)),
                    ]),
                ...items.map((e) => pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(e.productName,
                              style: pw.TextStyle(font: font))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('${e.quantity}',
                              style: pw.TextStyle(font: font),
                              textAlign: pw.TextAlign.center)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(moneyFmt.format(e.price.toDouble()),
                              style: pw.TextStyle(font: font),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              moneyFmt
                                  .format((e.price * e.quantity).toDouble()),
                              style: pw.TextStyle(font: font),
                              textAlign: pw.TextAlign.right)),
                    ])),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('รวมเงิน: ${moneyFmt.format(total)}',
                        style: pw.TextStyle(font: font)),
                    pw.Text(
                        'ภาษีมูลค่าเพิ่ม (7%): ${moneyFmt.format(total * 0.07)}',
                        style: pw.TextStyle(font: font)),
                    pw.Text('ยอดสุทธิ: ${moneyFmt.format(grandTotal)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 14)),
                  ]),
            ]),
          ],
        );
      },
    ));
    return pdf.save();
  }
}
