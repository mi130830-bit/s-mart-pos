import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import '../pdf/pdf_helper.dart';

class DeliveryNoteA5Pdf {
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
    PdfPageFormat? pageFormat,
    String documentTitleTh = 'ใบส่งของ',
    String documentTitleEn = 'ใบส่งของ',
    String signatureLabel = 'ผู้รับของ',
    bool useShippingAddress = true,
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

    // Forces 9x5.5 inch layout for continuous dot-matrix paper
    final finalPageFormat = pageFormat ?? PdfPageFormat(
      9.0 * PdfPageFormat.inch,
      5.5 * PdfPageFormat.inch,
      marginLeft: 0.5 * PdfPageFormat.cm,
      marginRight:
          2.50 * PdfPageFormat.cm, // Ensure right tractor feed is clear
      marginTop: 0.8 * PdfPageFormat.cm,
      marginBottom: 0.8 * PdfPageFormat.cm,
    );

    final int itemsPerPage = 6; // 6 rows to leave room for footer on last page
    final int totalPages =
        items.isEmpty ? 1 : (items.length / itemsPerPage).ceil();

    for (int i = 0; i < totalPages; i++) {
      final int start = i * itemsPerPage;
      final int end = (start + itemsPerPage < items.length)
          ? start + itemsPerPage
          : items.length;
      final List<OrderItem> chunkItems = items.sublist(start, end);

      pdf.addPage(pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: finalPageFormat,
          buildBackground: (context) => pw.Container(color: PdfColors.white),
        ),
        build: (context) {
          final content = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                  shopInfo, logo, orderId, font, fontBold, documentTitleEn),
              pw.SizedBox(height: 5),
              _buildCustomerInfo(customer, font, fontBold,
                  useShippingAddress: useShippingAddress),
              pw.SizedBox(height: 5),
              pw.Expanded(
                child: _buildTable(chunkItems, start + 1, moneyFmt, font,
                    fontBold, itemsPerPage),
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
              PdfHelper.buildRuler(
                  finalPageFormat.width, finalPageFormat.height, font)
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
              width: 50,
              height: 50,
              margin: const pw.EdgeInsets.only(right: 15),
              child: pw.Image(logo)),
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ร้าน ${shopInfo.name}',
                    style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.Text('จำหน่ายวัสดุก่อสร้าง อุปกรณ์ไฟฟ้าและประปา',
                    style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Text(shopInfo.address,
                    style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Text('โทร: ${shopInfo.phone}',
                    style: pw.TextStyle(font: font, fontSize: 10)),
              ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: 14)),
          pw.Row(children: [
            pw.SizedBox(
                width: 50,
                child: pw.Text('เลขที่:',
                    style: pw.TextStyle(font: font, fontSize: 10))),
            pw.Text(orderId.toString().padLeft(8, '0'),
                style: pw.TextStyle(font: font, fontSize: 10)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: 50,
                child: pw.Text('วันที่:',
                    style: pw.TextStyle(font: font, fontSize: 10))),
            pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                style: pw.TextStyle(font: font, fontSize: 10)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: 50,
                child: pw.Text('เวลา:',
                    style: pw.TextStyle(font: font, fontSize: 10))),
            pw.Text(DateFormat('HH:mm:ss').format(DateTime.now()),
                style: pw.TextStyle(font: font, fontSize: 10)),
          ]),
        ]),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(
      Customer? customer, pw.Font font, pw.Font fontBold,
      {bool useShippingAddress = true}) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.SizedBox(
                width: 40,
                child: pw.Text('ลูกค้า: ',
                    style: pw.TextStyle(font: fontBold, fontSize: 10))),
            pw.Text(customer?.name ?? '-',
                style: pw.TextStyle(font: font, fontSize: 10)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: 40,
                child: pw.Text('ที่อยู่: ',
                    style: pw.TextStyle(font: fontBold, fontSize: 10))),
            pw.Text(
                useShippingAddress
                    ? (customer?.shippingAddress ?? customer?.address ?? '-')
                    : (customer?.address ?? '-'),
                style: pw.TextStyle(font: font, fontSize: 10)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: 40,
                child: pw.Text('โทร: ',
                    style: pw.TextStyle(font: fontBold, fontSize: 10))),
            pw.Text(customer?.phone ?? '-',
                style: pw.TextStyle(font: font, fontSize: 10)),
          ]),
        ]);
  }

  static pw.Widget _buildTable(List<OrderItem> items, int startIndex,
      NumberFormat moneyFmt, pw.Font font, pw.Font fontBold, int itemsPerPage) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(30), // ลำดับ
        1: const pw.FlexColumnWidth(), // รายการ
        2: const pw.FixedColumnWidth(40), // จำนวน
        3: const pw.FixedColumnWidth(70), // ราคา
        4: const pw.FixedColumnWidth(70), // รวม
      },
      children: [
        pw.TableRow(
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(width: 1.0),
                    bottom: pw.BorderSide(
                        width: 1.0))), // Top/Bottom lines for header
            children: [
              _cell('ลำดับ', fontBold, 9.5, align: pw.TextAlign.center),
              _cell('รายการ', fontBold, 9.5),
              _cell('จำนวน', fontBold, 9.5, align: pw.TextAlign.center),
              _cell('ราคา', fontBold, 9.5, align: pw.TextAlign.right),
              _cell('รวม', fontBold, 9.5, align: pw.TextAlign.right),
            ]),
        ...items.asMap().entries.map((entry) {
          final item = entry.value;
          return pw.TableRow(children: [
            _cell('${startIndex + entry.key}', font, 9.5,
                align: pw.TextAlign.center),
            _cell(item.productName, font, 9.5),
            _cell('${item.quantity}', font, 9.5, align: pw.TextAlign.center),
            _cell(moneyFmt.format(item.price.toDouble()), font, 9.5,
                align: pw.TextAlign.right),
            _cell(moneyFmt.format((item.price * item.quantity).toDouble()),
                font, 9.5,
                align: pw.TextAlign.right),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font, double fontSize,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
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
        padding: const pw.EdgeInsets.only(top: 5),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                pw.Text('หมายเหตุ: ${remark ?? ''}',
                    style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(height: 10),
                pw.Text('หน้า $pageNumber/$totalPages',
                    style: pw.TextStyle(font: font, fontSize: 9)),
              ])),
          if (isLastPage)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  pw.SizedBox(
                      width: 80,
                      child: pw.Text('รวม :',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 70,
                      child: pw.Text(moneyFmt.format(total),
                          style: pw.TextStyle(font: font, fontSize: 10),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.Row(children: [
                  pw.SizedBox(
                      width: 80,
                      child: pw.Text('ส่วนลด :',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 70,
                      child: pw.Text(moneyFmt.format(discount),
                          style: pw.TextStyle(font: font, fontSize: 10),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.SizedBox(height: 2),
                pw.Row(children: [
                  pw.SizedBox(
                      width: 80,
                      child: pw.Text('ยอดรวมทั้งสิ้น :',
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: 70,
                      child: pw.Text(moneyFmt.format(grandTotal),
                          style: pw.TextStyle(font: fontBold, fontSize: 10),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.SizedBox(height: 30),
                pw.Text(
                    '......................................................',
                    style: pw.TextStyle(font: font, fontSize: 10)),
                pw.SizedBox(
                    width: 120,
                    child: pw.Text(signatureLabel,
                        style: pw.TextStyle(font: font, fontSize: 10),
                        textAlign: pw.TextAlign.center)),
              ],
            )
        ]));
  }
}

// Added Class for compatibility with receipt_service.dart
class CashReceiptA5Pdf {
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
    PdfPageFormat? pageFormat,
  }) {
    // Call DeliveryNoteA5Pdf but change title to "Receipt"
    return DeliveryNoteA5Pdf.generate(
        orderId: orderId,
        items: items,
        customer: customer,
        discount: discount,
        vatAmount: vatAmount,
        grandTotalOverride: grandTotalOverride,
        shopInfo: shopInfo,
        showRuler: showRuler,
        remark: remark,
        pageFormat: pageFormat,
        documentTitleTh: 'ใบเสร็จรับเงิน',
        documentTitleEn: 'ใบเสร็จรับเงิน',
        signatureLabel: 'ผู้รับเงิน',
        useShippingAddress: false);
  }
}
