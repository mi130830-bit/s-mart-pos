import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import 'pdf_helper.dart';

class CashReceiptPdf {
  static Future<Uint8List> generate({
    required int orderId,
    required List<OrderItem> items,
    Customer? customer,
    double discount = 0.0,
    required PdfPageFormat pageFormat,
    required ShopInfo shopInfo,
    bool showRuler = false,
  }) async {
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();
    final logo = await PdfHelper.getLogo();

    final moneyFmt = NumberFormat('#,##0.00');
    final double total = items
        .fold<Decimal>(Decimal.zero, (sum, i) => sum + (i.price * i.quantity))
        .toDouble();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );

    // ขนาดกระดาษ 9 x 5.5 นิ้ว (22.86 ซม. x 13.97 ซม.)
    final double paperWidth = 228.6 * PdfPageFormat.mm;
    final double paperHeight = 139.7 * PdfPageFormat.mm;

    // ✅ ปรับแก้ Margin (ตาม DeliveryNote):
    final exactFormat = PdfPageFormat(
      paperWidth,
      paperHeight,
      marginLeft: 2.75 * PdfPageFormat.mm, // ลดจาก 3 -> 0 (ชิดซ้ายสุด)
      marginRight:
          30.0 * PdfPageFormat.mm, // เพิ่มจาก 35 -> 40 (กันตกขอบขวามากขึ้น)
      marginTop: 4.0 * PdfPageFormat.mm,
      marginBottom: 6.0 * PdfPageFormat.mm,
    );

    // จำนวนรายการต่อหน้า (4-5 กำลังดีสำหรับครึ่ง A4)
    const int itemsPerPage = 7;

    const double fontSizeNormal = 11;
    const double fontSizeTitle = 14.0;

    final List<OrderItem> safeItems = items.isEmpty ? [] : items;
    final int totalPages =
        safeItems.isEmpty ? 1 : (safeItems.length / itemsPerPage).ceil();

    for (int i = 0; i < totalPages; i++) {
      final int start = i * itemsPerPage;
      final int end = (start + itemsPerPage < safeItems.length)
          ? start + itemsPerPage
          : safeItems.length;
      final List<OrderItem> chunkItems = safeItems.sublist(start, end);

      final bool isLastPage = (i == totalPages - 1);
      final int startIndex = start + 1;

      pdf.addPage(pw.Page(
          pageFormat: exactFormat, // ใช้ exactFormat ตาม DeliveryNote
          build: (context) {
            // ใช้ Column จัด layout บน-ล่าง (ป้องกัน Error NaN)
            final content = pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // --- ส่วนบน: Header + ตาราง ---
                pw.Column(
                  children: [
                    _buildHeader(shopInfo, logo, customer, orderId, font,
                        fontBold, fontSizeNormal, fontSizeTitle),
                    pw.SizedBox(height: 5),
                    pw.Container(height: 0.5, color: PdfColors.black),
                    _buildTable(chunkItems, startIndex, moneyFmt, font,
                        fontBold, fontSizeNormal),
                    pw.Container(height: 0.5, color: PdfColors.black),
                  ],
                ),

                // --- ส่วนล่าง: สรุปยอด + ลายเซ็น ---
                _buildFooterSection(
                    total, discount, moneyFmt, font, fontBold, fontSizeNormal,
                    isLastPage: isLastPage,
                    pageNumber: i + 1,
                    totalPages: totalPages),
              ],
            );

            if (showRuler) {
              return pw.Stack(
                children: [
                  content,
                  _buildRuler(exactFormat),
                ],
              );
            }
            return content;
          }));
    }

    return pdf.save();
  }

  // --- Ruler Overlay ---
  static pw.Widget _buildRuler(PdfPageFormat pageFormat) {
    return pw.Stack(children: [
      // Horizontal Ruler (Top)
      ...List.generate((pageFormat.width / PdfPageFormat.cm).ceil(), (index) {
        final x = index * PdfPageFormat.cm;
        return pw.Positioned(
          left: x,
          top: 0,
          child: pw.Container(
            height: index % 5 == 0 ? 15 : 8,
            width: 0.5,
            color: PdfColors.red,
          ),
        );
      }),
      ...List.generate((pageFormat.width / PdfPageFormat.cm).ceil(), (index) {
        if (index == 0) return pw.Container();
        final x = index * PdfPageFormat.cm;
        return pw.Positioned(
          left: x + 2,
          top: 5,
          child: pw.Text('$index',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.red)),
        );
      }),

      // Vertical Ruler (Left)
      ...List.generate((pageFormat.height / PdfPageFormat.cm).ceil(), (index) {
        final y = index * PdfPageFormat.cm;
        return pw.Positioned(
          top: y,
          left: 0,
          child: pw.Container(
            width: index % 5 == 0 ? 15 : 8,
            height: 0.5,
            color: PdfColors.red,
          ),
        );
      }),
      ...List.generate((pageFormat.height / PdfPageFormat.cm).ceil(), (index) {
        if (index == 0) return pw.Container();
        final y = index * PdfPageFormat.cm;
        return pw.Positioned(
          top: y + 2,
          left: 5,
          child: pw.Text('$index',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.red)),
        );
      }),
    ]);
  }

  // --- ส่วน Header ---
  static pw.Widget _buildHeader(
      ShopInfo shopInfo,
      pw.ImageProvider? logo,
      Customer? customer,
      int orderId,
      pw.Font font,
      pw.Font fontBold,
      double fontSize,
      double titleSize) {
    // เตรียมวันที่และเวลา
    final now = DateTime.now();
    final dateStr = '${now.day} ${_thaiMonth(now.month)} ${now.year + 543}';
    final timeStr = DateFormat('HH:mm:ss').format(now);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                  width: 55,
                  height: 55,
                  margin: const pw.EdgeInsets.only(right: 8),
                  child: pw.Image(logo)),
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(shopInfo.name,
                        style: pw.TextStyle(font: fontBold, fontSize: 14),
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip),
                    pw.Text(shopInfo.address,
                        style: pw.TextStyle(font: font, fontSize: fontSize),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip),
                    pw.Text('โทร - ${shopInfo.phone}',
                        style: pw.TextStyle(font: font, fontSize: fontSize)),
                  ]),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Center(
            child: pw.Text("ใบเสร็จรับเงิน", // เปลี่ยนจาก "ใบส่งของ"
                style: pw.TextStyle(font: fontBold, fontSize: titleSize))),
        pw.SizedBox(height: 4),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
              flex: 6,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildLabelValue(
                        "ชื่อลูกค้า", // "ลูกค้า" -> "ชื่อลูกค้า"
                        customer != null
                            ? "${customer.firstName} ${customer.lastName ?? ""}"
                            : "ลูกค้าทั่วไป",
                        font,
                        fontSize),
                    _buildLabelValue(
                        "ที่อยู่",
                        // ✅ Use Shipping Address first if available
                        customer?.shippingAddress ?? customer?.address ?? "-",
                        font,
                        fontSize),
                  ])),
          pw.SizedBox(width: 10),
          pw.Expanded(
              flex: 4,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildLabelValue("เลขที่",
                        orderId.toString().padLeft(8, '0'), font, fontSize),
                    _buildLabelValue("วันที่", dateStr, font, fontSize),
                    _buildLabelValue(
                        // เพิ่มเวลา
                        "เวลา",
                        timeStr,
                        font,
                        fontSize),
                  ])),
        ]),
      ],
    );
  }

  static pw.Widget _buildLabelValue(
      String label, String value, pw.Font font, double fontSize) {
    return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1.0),
        child:
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
              width: 40, // เพิ่มความกว้างนิดนึง
              child: pw.Text("$label :",
                  style: pw.TextStyle(font: font, fontSize: fontSize))),
          pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(font: font, fontSize: fontSize),
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip)),
        ]));
  }

  // --- ส่วน Table ---
  static pw.Widget _buildTable(List<OrderItem> items, int startIndex,
      NumberFormat moneyFmt, pw.Font font, pw.Font fontBold, double fontSize) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(0.7), // ลำดับ
        1: const pw.FlexColumnWidth(4.1), // รายการ
        2: const pw.FlexColumnWidth(0.8), // จำนวน
        3: const pw.FlexColumnWidth(1.2), // ราคา
        4: const pw.FlexColumnWidth(1.2), // ส่วนลด (New)
        5: const pw.FlexColumnWidth(1.5), // รวม
      },
      border: pw.TableBorder.all(color: PdfColors.white, width: 0),
      children: [
        pw.TableRow(
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
            children: [
              _cell('ลำดับที่', font, fontSize, align: pw.TextAlign.center),
              _cell('รายการ', font, fontSize, align: pw.TextAlign.left),
              _cell('จำนวน', font, fontSize, align: pw.TextAlign.center),
              _cell('ราคา', font, fontSize, align: pw.TextAlign.right),
              _cell('ส่วนลด', font, fontSize, align: pw.TextAlign.right), // New
              _cell('ราคารวม', font, fontSize, align: pw.TextAlign.right),
            ]),
        ...items.asMap().entries.map((entry) {
          final index = startIndex + entry.key;
          final item = entry.value;
          final totalRow = item.price * item.quantity;
          return pw.TableRow(children: [
            _cell('$index', font, fontSize, align: pw.TextAlign.center),
            _cell(item.productName, font, fontSize, align: pw.TextAlign.left),
            _cell('${item.quantity.toDouble().toInt()}', font, fontSize,
                align: pw.TextAlign.center),
            _cell(moneyFmt.format(item.price.toDouble()), font, fontSize,
                align: pw.TextAlign.right),
            _cell('0.00', font, fontSize,
                align: pw.TextAlign.right), // Placeholder Discount
            _cell(moneyFmt.format(totalRow.toDouble()), font, fontSize,
                align: pw.TextAlign.right),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font, double fontSize,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, fontSize: fontSize),
            textAlign: align,
            maxLines: 1,
            overflow: pw.TextOverflow.clip));
  }

  // --- ส่วน Footer ---
  static pw.Widget _buildFooterSection(double total, double discount,
      NumberFormat moneyFmt, pw.Font font, pw.Font fontBold, double fontSize,
      {required bool isLastPage,
      required int pageNumber,
      required int totalPages}) {
    return pw.Column(children: [
      pw.SizedBox(height: 5),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
            flex: 6,
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("หมายเหตุ -",
                      style: pw.TextStyle(font: font, fontSize: fontSize)),
                  // ไม่เอาเส้นประสำหรับหมายเหตุตามรูปแบบ A5 Bill Image
                ])),
        pw.SizedBox(width: 10),
        pw.Expanded(
            flex: 4,
            child: isLastPage
                ? pw.Column(children: [
                    _summaryRow(
                        'รวม :', moneyFmt.format(total), fontBold, fontSize),
                    _summaryRow('ส่วนลด :', moneyFmt.format(discount), fontBold,
                        fontSize),
                    pw.Divider(height: 4, thickness: 0.5),
                    _summaryRow('ยอดรวม :', moneyFmt.format(total - discount),
                        fontBold, fontSize), // ✅ Bold for Net Total
                  ])
                : pw.SizedBox(height: 20)),
      ]),
      pw.SizedBox(height: 10),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        // ลายเซ็นเดียว "ผู้รับเงิน"
        _buildSignature("ผู้รับเงิน", font, fontSize),
      ]),
    ]);
  }

  static pw.Widget _summaryRow(
      String label, String value, pw.Font font, double fontSize) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(font: font, fontSize: fontSize)),
              pw.Text(value,
                  style: pw.TextStyle(font: font, fontSize: fontSize)),
            ]));
  }

  static pw.Widget _buildSignature(
      String label, pw.Font font, double fontSize) {
    return pw.Column(children: [
      pw.Text(label, style: pw.TextStyle(font: font, fontSize: fontSize)),
      pw.SizedBox(height: 4),
      pw.Text(".............................................",
          style:
              pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
    ]);
  }

  static String _thaiMonth(int month) {
    const months = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '$month';
  }
}
