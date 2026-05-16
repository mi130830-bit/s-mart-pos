import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import '../pdf/pdf_helper.dart';

class DeliveryNoteA4Pdf {
  static Future<Uint8List> generate({
    required int orderId,
    required List<OrderItem> items,
    required Customer? customer,
    double discount = 0.0,
    double vatAmount = 0.0,
    double? grandTotalOverride,
    required ShopInfo shopInfo,
    bool showRuler = false,
    String? remark,
    String documentTitleTh = 'ใบส่งของ',
    String documentTitleEn = 'ใบส่งของ',
    String signatureLabel = 'ผู้รับของ',
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
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    // A4 Format
    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 1.5 * PdfPageFormat.cm,
      marginRight: 2.5 * PdfPageFormat.cm,
      marginTop: 1.5 * PdfPageFormat.cm,
      marginBottom: 1.5 * PdfPageFormat.cm,
    );

    const int itemsPerPage =
        20; // Expanded to fit A4 vertical layout with new margins
    final int totalPages =
        items.isEmpty ? 1 : (items.length / itemsPerPage).ceil();

    for (int i = 0; i < totalPages; i++) {
      final int start = i * itemsPerPage;
      final int end = (start + itemsPerPage < items.length)
          ? start + itemsPerPage
          : items.length;
      final List<OrderItem> chunkItems = items.sublist(start, end);

      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          final content = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                  shopInfo, logo, orderId, font, fontBold, documentTitleEn),
              pw.SizedBox(height: 10),
              _buildCustomerInfo(customer, font, fontBold),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: _buildTable(
                    chunkItems, start + 1, moneyFmt, font, fontBold),
              ),
              _buildFooter(calculatedTotal, discount, vatAmount,
                  finalGrandTotal, moneyFmt, font, fontBold,
                  signatureLabel: signatureLabel,
                  isLastPage: i == totalPages - 1,
                  pageNumber: i + 1,
                  totalPages: totalPages,
                  remark: remark),
            ],
          );

          if (showRuler) {
            return pw.Stack(children: [
              content,
              PdfHelper.buildRuler(pageFormat.width, pageFormat.height, font)
            ]);
          }
          return content;
        },
      ));
    }

    return pdf.save();
  }

  static pw.Widget _buildHeader(ShopInfo shopInfo, pw.ImageProvider? logo,
      int orderId, pw.Font font, pw.Font fontBold, String title) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null)
          pw.Container(
              width: 70,
              height: 70,
              margin: const pw.EdgeInsets.only(right: 15),
              child: pw.Image(logo)),
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ร้าน ${shopInfo.name}',
                    style: pw.TextStyle(font: fontBold, fontSize: 16)),
                pw.Text('จำหน่ายวัสดุก่อสร้าง อุปกรณ์ไฟฟ้าและประปา',
                    style: pw.TextStyle(font: font, fontSize: 12)),
                pw.Text(shopInfo.address,
                    style: pw.TextStyle(font: font, fontSize: 12)),
                pw.Text('โทร: ${shopInfo.phone}',
                    style: pw.TextStyle(font: font, fontSize: 12)),
              ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 16)),
          pw.Row(children: [
            pw.SizedBox(
                width: 60,
                child: pw.Text('เลขที่:',
                    style: pw.TextStyle(font: font, fontSize: 12))),
            pw.Text(orderId.toString().padLeft(8, '0'),
                style: pw.TextStyle(font: font, fontSize: 12)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: 60,
                child: pw.Text('วันที่:',
                    style: pw.TextStyle(font: font, fontSize: 12))),
            pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                style: pw.TextStyle(font: font, fontSize: 12)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: 60,
                child: pw.Text('เวลา:',
                    style: pw.TextStyle(font: font, fontSize: 12))),
            pw.Text(DateFormat('HH:mm:ss').format(DateTime.now()),
                style: pw.TextStyle(font: font, fontSize: 12)),
          ]),
        ]),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(
      Customer? customer, pw.Font font, pw.Font fontBold) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.SizedBox(
                width: 50,
                child: pw.Text('ลูกค้า: ',
                    style: pw.TextStyle(font: fontBold, fontSize: 12))),
            pw.Text(customer?.name ?? '-',
                style: pw.TextStyle(font: font, fontSize: 12)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: 50,
                child: pw.Text('ที่อยู่: ',
                    style: pw.TextStyle(font: fontBold, fontSize: 12))),
            pw.Text(customer?.shippingAddress ?? customer?.address ?? '-',
                style: pw.TextStyle(font: font, fontSize: 12)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: 50,
                child: pw.Text('โทร: ',
                    style: pw.TextStyle(font: fontBold, fontSize: 12))),
            pw.Text(customer?.phone ?? '-',
                style: pw.TextStyle(font: font, fontSize: 12)),
          ]),
        ]);
  }

  static pw.Widget _buildTable(List<OrderItem> items, int startIndex,
      NumberFormat moneyFmt, pw.Font font, pw.Font fontBold) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(40), // ลำดับ
        1: const pw.FlexColumnWidth(), // รายการ
        2: const pw.FixedColumnWidth(60), // จำนวน
        3: const pw.FixedColumnWidth(90), // ราคา
        4: const pw.FixedColumnWidth(90), // รวม
      },
      children: [
        pw.TableRow(
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(width: 1.0),
                    bottom: pw.BorderSide(width: 1.0))),
            children: [
              _cell('ลำดับ', fontBold, 12, align: pw.TextAlign.center),
              _cell('รายการ', fontBold, 12),
              _cell('จำนวน', fontBold, 12, align: pw.TextAlign.center),
              _cell('ราคา', fontBold, 12, align: pw.TextAlign.right),
              _cell('รวม', fontBold, 12, align: pw.TextAlign.right),
            ]),
        ...items.asMap().entries.map((entry) {
          final item = entry.value;
          return pw.TableRow(children: [
            _cell('${startIndex + entry.key}', font, 12,
                align: pw.TextAlign.center),
            _cell(item.productName, font, 12),
            _cell('${item.quantity}', font, 12, align: pw.TextAlign.center),
            _cell(moneyFmt.format(item.price.toDouble()), font, 12,
                align: pw.TextAlign.right),
            _cell(moneyFmt.format((item.price * item.quantity).toDouble()),
                font, 12,
                align: pw.TextAlign.right),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font, double fontSize,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: pw.Text(text,
              style: pw.TextStyle(font: font, fontSize: fontSize),
              textAlign: align));

  static pw.Widget _buildFooter(double total, double discount, double vat,
      double grandTotal, NumberFormat moneyFmt, pw.Font font, pw.Font fontBold,
      {required bool isLastPage,
      required int pageNumber,
      required int totalPages,
      String signatureLabel = 'ผู้รับของ',
      String? remark}) {
    return pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(width: 1.0)),
        ),
        padding: const pw.EdgeInsets.only(top: 10),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                pw.Text('หมายเหตุ: ${remark ?? ''}',
                    style: pw.TextStyle(font: font, fontSize: 12)),
                pw.SizedBox(height: 10),
                pw.Text('หน้า $pageNumber/$totalPages',
                    style: pw.TextStyle(font: font, fontSize: 10)),
              ])),
          if (isLastPage)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  pw.SizedBox(
                      width: 90,
                      child: pw.Text('รวม :',
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 90,
                      child: pw.Text(moneyFmt.format(total),
                          style: pw.TextStyle(font: font, fontSize: 12),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.Row(children: [
                  pw.SizedBox(
                      width: 90,
                      child: pw.Text('ส่วนลด :',
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 90,
                      child: pw.Text(moneyFmt.format(discount),
                          style: pw.TextStyle(font: font, fontSize: 12),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.SizedBox(height: 5),
                pw.Row(children: [
                  pw.SizedBox(
                      width: 90,
                      child: pw.Text('ยอดรวมทั้งสิ้น :',
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 90,
                      child: pw.Text(moneyFmt.format(grandTotal),
                          style: pw.TextStyle(font: fontBold, fontSize: 12),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.SizedBox(height: 60),
                pw.Text(
                    '..............................................................',
                    style: pw.TextStyle(font: font, fontSize: 12)),
                pw.SizedBox(
                    width: 180,
                    child: pw.Text(signatureLabel,
                        style: pw.TextStyle(font: font, fontSize: 12),
                        textAlign: pw.TextAlign.center)),
              ],
            )
        ]));
  }
}
