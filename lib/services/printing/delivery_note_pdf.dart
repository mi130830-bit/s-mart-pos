import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
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
    bool showRuler = false,
    String? remark,
    required PdfPageFormat pageFormat,
    String documentTitleTh = 'ใบส่งของ',
    String documentTitleEn = 'ใบส่งของ',
    String signatureLabel = 'ผู้รับของ',
    bool useShippingAddress = true,
    Uint8List? shopLogoBytes,
  }) async {
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();
    final logo = shopLogoBytes != null ? pw.MemoryImage(shopLogoBytes) : null;
    final moneyFmt = NumberFormat('#,##0.00');

    final double calculatedTotal = items
        .fold<Decimal>(Decimal.zero, (sum, i) => sum + (i.price * i.quantity))
        .toDouble();
    final double finalGrandTotal =
        grandTotalOverride ?? (calculatedTotal - discount + vatAmount);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    // Determine paper type by size (in points: 1mm = ~2.835pt)
    // A4 height ≈ 841pt, A5 height ≈ 595pt, Continuous ≈ 396pt (5.5in)
    final bool isA4 = pageFormat.height > 700;
    final bool isContinuous = pageFormat.height < 430; // 5.5in = ~396pt
    // else: A5 standard

    final int itemsPerPage = isA4 ? 20 : (isContinuous ? 6 : 8);
    final double globalFontSize = isA4 ? 12.0 : 9.5;
    final double headerFontSize = isA4 ? 12.0 : 9.0;
    final double titleFontSize = isA4 ? 16.0 : 11.0;
    final double cellPaddingVertical = isA4 ? 4.0 : 2.0;

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
          pageFormat: pageFormat,
          buildBackground: (context) => pw.Container(color: PdfColors.white),
        ),
        build: (context) {
          final content = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                  shopInfo, logo, orderId, font, fontBold, documentTitleEn,
                  titleFontSize: titleFontSize, headerFontSize: headerFontSize),
              pw.SizedBox(height: isA4 ? 10 : 4),
              _buildCustomerInfo(customer, font, fontBold,
                  useShippingAddress: useShippingAddress,
                  fontSize: globalFontSize,
                  labelWidth: isA4 ? 50 : 38),
              pw.SizedBox(height: isA4 ? 10 : (isContinuous ? 3 : 4)),
              pw.Expanded(
                child: _buildTable(chunkItems, start + 1, moneyFmt, font,
                    fontBold, itemsPerPage,
                    fontSize: globalFontSize,
                    paddingVertical: cellPaddingVertical),
              ),
              _buildFooter(calculatedTotal, discount, vatAmount,
                  finalGrandTotal, moneyFmt, font, fontBold,
                  signatureLabel: signatureLabel,
                  isLastPage: i == totalPages - 1,
                  pageNumber: i + 1,
                  totalPages: totalPages,
                  remark: remark,
                  fontSize: globalFontSize,
                  footerSpacing: isA4 ? 60 : (isContinuous ? 5 : 15)),
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
      int orderId, pw.Font font, pw.Font fontBold, String title,
      {required double titleFontSize, required double headerFontSize}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logo != null)
          pw.Container(
              width: titleFontSize * 3.5,
              height: titleFontSize * 3.5,
              margin: const pw.EdgeInsets.only(right: 15),
              child: pw.Image(logo)),
        pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ร้าน ${shopInfo.name}',
                    style: pw.TextStyle(font: fontBold, fontSize: titleFontSize)),
                pw.Text('จำหน่ายวัสดุก่อสร้าง อุปกรณ์ไฟฟ้าและประปา',
                    style: pw.TextStyle(font: font, fontSize: headerFontSize)),
                pw.Text(shopInfo.address,
                    style: pw.TextStyle(font: font, fontSize: headerFontSize)),
                pw.Text('โทร: ${shopInfo.phone}',
                    style: pw.TextStyle(font: font, fontSize: headerFontSize)),
              ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(font: fontBold, fontSize: titleFontSize)),
          pw.Row(children: [
            pw.SizedBox(
                width: headerFontSize * 5.0,
                child: pw.Text('เลขที่:',
                    style: pw.TextStyle(font: font, fontSize: headerFontSize))),
            pw.Text(orderId.toString().padLeft(8, '0'),
                style: pw.TextStyle(font: font, fontSize: headerFontSize)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: headerFontSize * 5.0,
                child: pw.Text('วันที่:',
                    style: pw.TextStyle(font: font, fontSize: headerFontSize))),
            pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                style: pw.TextStyle(font: font, fontSize: headerFontSize)),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: headerFontSize * 5.0,
                child: pw.Text('เวลา:',
                    style: pw.TextStyle(font: font, fontSize: headerFontSize))),
            pw.Text(DateFormat('HH:mm:ss').format(DateTime.now()),
                style: pw.TextStyle(font: font, fontSize: headerFontSize)),
          ]),
        ]),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(
      Customer? customer, pw.Font font, pw.Font fontBold,
      {bool useShippingAddress = true,
      required double fontSize,
      required double labelWidth}) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.SizedBox(
                width: labelWidth,
                child: pw.Text('ลูกค้า: ',
                    style: pw.TextStyle(font: fontBold, fontSize: fontSize))),
            pw.Expanded(
              child: pw.Text(customer?.name ?? '-',
                  style: pw.TextStyle(font: font, fontSize: fontSize)),
            ),
          ]),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(
                width: labelWidth,
                child: pw.Text('ที่อยู่: ',
                    style: pw.TextStyle(font: fontBold, fontSize: fontSize))),
            pw.Expanded(
              child: pw.Text(
                  useShippingAddress
                      ? (customer?.shippingAddress ?? customer?.address ?? '-')
                      : (customer?.address ?? '-'),
                  style: pw.TextStyle(font: font, fontSize: fontSize)),
            ),
          ]),
          pw.Row(children: [
            pw.SizedBox(
                width: labelWidth,
                child: pw.Text('โทร: ',
                    style: pw.TextStyle(font: fontBold, fontSize: fontSize))),
            pw.Expanded(
              child: pw.Text(customer?.phone ?? '-',
                  style: pw.TextStyle(font: font, fontSize: fontSize)),
            ),
          ]),
        ]);
  }

  static pw.Widget _buildTable(List<OrderItem> items, int startIndex,
      NumberFormat moneyFmt, pw.Font font, pw.Font fontBold, int itemsPerPage,
      {required double fontSize, required double paddingVertical}) {
    return pw.Table(
      columnWidths: {
        0: pw.FixedColumnWidth(fontSize * 3.0), // ลำดับ
        1: const pw.FlexColumnWidth(), // รายการ
        2: pw.FixedColumnWidth(fontSize * 4.0), // จำนวน
        3: pw.FixedColumnWidth(fontSize * 7.0), // ราคา
        4: pw.FixedColumnWidth(fontSize * 7.0), // รวม
      },
      children: [
        pw.TableRow(
            decoration: const pw.BoxDecoration(
                border: pw.Border(
                    top: pw.BorderSide(width: 1.0),
                    bottom: pw.BorderSide(
                        width: 1.0))), // Top/Bottom lines for header
            children: [
              _cell('ลำดับ', fontBold, fontSize, align: pw.TextAlign.center, paddingVertical: paddingVertical),
              _cell('รายการ', fontBold, fontSize, paddingVertical: paddingVertical),
              _cell('จำนวน', fontBold, fontSize, align: pw.TextAlign.center, paddingVertical: paddingVertical),
              _cell('ราคา', fontBold, fontSize, align: pw.TextAlign.right, paddingVertical: paddingVertical),
              _cell('รวม', fontBold, fontSize, align: pw.TextAlign.right, paddingVertical: paddingVertical),
            ]),
        ...items.asMap().entries.map((entry) {
          final item = entry.value;
          return pw.TableRow(children: [
            _cell('${startIndex + entry.key}', font, fontSize,
                align: pw.TextAlign.center, paddingVertical: paddingVertical),
            _cell(item.productName, font, fontSize, paddingVertical: paddingVertical),
            _cell('${item.quantity}', font, fontSize, align: pw.TextAlign.center, paddingVertical: paddingVertical),
            _cell(moneyFmt.format(item.price.toDouble()), font, fontSize,
                align: pw.TextAlign.right, paddingVertical: paddingVertical),
            _cell(moneyFmt.format((item.price * item.quantity).toDouble()),
                font, fontSize,
                align: pw.TextAlign.right, paddingVertical: paddingVertical),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font, double fontSize,
          {pw.TextAlign align = pw.TextAlign.left, required double paddingVertical}) =>
      pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: paddingVertical, horizontal: 4),
          child: pw.Text(text,
              style: pw.TextStyle(font: font, fontSize: fontSize),
              textAlign: align));

  static pw.Widget _buildFooter(double total, double discount, double vat,
      double grandTotal, NumberFormat moneyFmt, pw.Font font, pw.Font fontBold,
      {required bool isLastPage,
      required int pageNumber,
      required int totalPages,
      String signatureLabel = 'ผู้รับของ',
      String? remark,
      required double fontSize,
      required double footerSpacing}) {
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
                    style: pw.TextStyle(font: font, fontSize: fontSize)),
                pw.SizedBox(height: 10),
                pw.Text('หน้า $pageNumber/$totalPages',
                    style: pw.TextStyle(font: font, fontSize: fontSize * 0.9)),
              ])),
          if (isLastPage)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  pw.SizedBox(
                      width: fontSize * 8.0,
                      child: pw.Text('รวม :',
                          style: pw.TextStyle(font: fontBold, fontSize: fontSize),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: fontSize * 7.0,
                      child: pw.Text(moneyFmt.format(total),
                          style: pw.TextStyle(font: font, fontSize: fontSize),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.Row(children: [
                  pw.SizedBox(
                      width: fontSize * 8.0,
                      child: pw.Text('ส่วนลด :',
                          style: pw.TextStyle(font: fontBold, fontSize: fontSize),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: fontSize * 7.0,
                      child: pw.Text(moneyFmt.format(discount),
                          style: pw.TextStyle(font: font, fontSize: fontSize),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.SizedBox(height: 2),
                pw.Row(children: [
                  pw.SizedBox(
                      width: fontSize * 8.0,
                      child: pw.Text('ยอดรวมทั้งสิ้น :',
                          style: pw.TextStyle(font: fontBold, fontSize: fontSize),
                          textAlign: pw.TextAlign.right)),
                  pw.SizedBox(
                      width: fontSize * 7.0,
                      child: pw.Text(moneyFmt.format(grandTotal),
                          style: pw.TextStyle(font: fontBold, fontSize: fontSize),
                          textAlign: pw.TextAlign.right)),
                ]),
                pw.SizedBox(height: footerSpacing),
                pw.Text(
                    '......................................................',
                    style: pw.TextStyle(font: font, fontSize: fontSize)),
                pw.SizedBox(
                    width: fontSize * 12.0,
                    child: pw.Text(signatureLabel,
                        style: pw.TextStyle(font: font, fontSize: fontSize),
                        textAlign: pw.TextAlign.center)),
              ],
            )
        ]));
  }
}
