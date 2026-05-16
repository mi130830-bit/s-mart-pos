import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import '../pdf/pdf_helper.dart';

class CashReceiptPdf {
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
    final logo = await PdfHelper.getLogo();
    final moneyFmt = NumberFormat('#,##0.00');

    final double calculatedTotal = items
        .fold<Decimal>(Decimal.zero, (sum, i) => sum + (i.price * i.quantity))
        .toDouble();
    final double finalGrandTotal =
        grandTotalOverride ?? (calculatedTotal - discount + vatAmount);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );

    const int itemsPerPage = 25;
    final totalPages = (items.length / itemsPerPage).ceil();

    for (int i = 0; i < totalPages; i++) {
      final start = i * itemsPerPage;
      final end = (start + itemsPerPage < items.length)
          ? start + itemsPerPage
          : items.length;
      final chunkItems = items.sublist(start, end);

      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopInfo.name,
                          style: pw.TextStyle(font: fontBold, fontSize: 16)),
                      pw.Text(shopInfo.address,
                          style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('โทร: ${shopInfo.phone}',
                          style: pw.TextStyle(font: font, fontSize: 10)),
                    ],
                  ),
                  // ✅ แก้ไข: ใช้ pw.Image.fromBytes เพื่อส่ง Uint8List (logo) เข้าไปตรงๆ
                  if (logo != null)
                    pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(logo),
                    ),
                ],
              ),
              pw.Divider(),
              pw.Center(
                child: pw.Text('ใบเสร็จรับเงิน (CASH RECEIPT)',
                    style: pw.TextStyle(font: fontBold, fontSize: 14)),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ลูกค้า: ${customer?.name ?? "ลูกค้าทั่วไป"}'),
                      pw.Text('ที่อยู่: ${customer?.address ?? "-"}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('เลขที่: $orderId'),
                      pw.Text(
                          'วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('รายการ',
                              style: pw.TextStyle(font: fontBold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('จำนวน',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: fontBold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('รวม',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: fontBold))),
                    ],
                  ),
                  ...chunkItems.map((e) => pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(e.productName)),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${e.quantity}',
                                textAlign: pw.TextAlign.center)),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                moneyFmt
                                    .format((e.price * e.quantity).toDouble()),
                                textAlign: pw.TextAlign.right)),
                      ])),
                ],
              ),
              if (i == totalPages - 1) ...[
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('รวมเงิน: ${moneyFmt.format(calculatedTotal)}'),
                        if (discount > 0)
                          pw.Text('ส่วนลด: -${moneyFmt.format(discount)}'),
                        pw.Text('ยอดสุทธิ: ${moneyFmt.format(finalGrandTotal)}',
                            style: pw.TextStyle(font: fontBold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('หน้า ${i + 1} / $totalPages',
                    style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          );
        },
      ));
    }
    return pdf.save();
  }
}
