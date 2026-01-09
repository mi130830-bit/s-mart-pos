import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/payment_record.dart';
import '../../models/shop_info.dart';
import 'pdf_helper.dart';

class ThermalReceiptPdf {
  static Future<Uint8List> generate({
    required int orderId,
    required List<OrderItem> items,
    required double total,
    required double discount,
    required double grandTotal,
    required double received,
    required double change,
    List<PaymentRecord>? payments,
    Customer? customer,
    required PdfPageFormat pageFormat,
    required ShopInfo shopInfo,
    String? cashierName, // ✅ Receive Cashier Info
  }) async {
    // 1. เตรียม Font และ Logo
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();
    final logo = await PdfHelper.getLogo();
    final moneyFmt = NumberFormat('#,##0.00');

    // 2. ตรวจสอบขนาดกระดาษ
    final is80mm = pageFormat.width < 270;

    // 3. ปรับขนาดตัวอักษร
    final double bodySize = is80mm ? 9.0 : 11.0; // Increased base size slightly
    final double headerSize = is80mm ? 10.0 : 13.0;
    final double titleSize = is80mm ? 14.0 : 19.0;

    // 4. ตั้งค่าหัวกระดาษ
    String docTitle = is80mm
        ? "ใบเสร็จรับเงินอย่างย่อ" // ✅ Correct Title (No parentheses per request generally, or matches image)
        : "ใบเสร็จรับเงิน / ใบกำกับภาษีอย่างย่อ";

    String storeName = shopInfo.name;
    String address = shopInfo.address;
    String phone = shopInfo.phone;
    String taxId = shopInfo.taxId;
    String footer = shopInfo.footer;

    if (is80mm) {
      if (shopInfo.shortName.isNotEmpty) {
        storeName = shopInfo.shortName;
      }
      if (shopInfo.shortAddress.isNotEmpty) {
        address = shopInfo.shortAddress;
      }
    }

    // เตรียมวันที่และเวลา
    final now = DateTime.now();
    // คำนวณปี พ.ศ.
    final dateParts = DateFormat('dd/MM/yyyy').format(now).split('/');
    final dateThai =
        '${int.parse(dateParts[0])} ${_thaiMonth(dateParts[1])} ${int.parse(dateParts[2]) + 543}'; // Format ex: 6 ม.ค. 2569
    final timeStr = DateFormat('HH:mm:ss').format(now);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: is80mm ? pw.EdgeInsets.zero : const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          double? containerWidth;
          if (!is80mm) {
            containerWidth = (pageFormat.width > 400) ? 400 : pageFormat.width;
          }

          return pw.Center(
            child: pw.Container(
              width: containerWidth,
              padding: const pw.EdgeInsets.all(0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // --- HEADER REORDERED ---

                  // 1. Logo
                  if (logo != null)
                    pw.Container(
                      height: is80mm ? 60 : 80,
                      width: is80mm ? 60 : 80,
                      margin: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),

                  // 2. Document Title (Top per user request)
                  pw.Text(docTitle,
                      style: pw.TextStyle(font: fontBold, fontSize: titleSize),
                      textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 2),

                  // 3. Shop Name
                  pw.Text(
                    storeName,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: headerSize + 2,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),

                  // 4. Address Details
                  if (address.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 0),
                      child: pw.Text(
                        address,
                        style: pw.TextStyle(font: font, fontSize: bodySize),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),

                  // 5. Phone
                  if (phone.isNotEmpty || taxId.isNotEmpty)
                    pw.Text(
                        [
                          if (phone.isNotEmpty) 'โทร $phone',
                          // if (taxId.isNotEmpty) 'Tax: $taxId'
                        ].join(', '),
                        style: pw.TextStyle(font: font, fontSize: bodySize),
                        textAlign: pw.TextAlign.center),

                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 1), // Solid Line

                  // --- CUSTOMER INFO ---
                  if (customer != null) ...[
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ชื่อลูกค้า :  ${customer.name}',
                              style: pw.TextStyle(
                                  font: font,
                                  fontSize: bodySize)), // font normal per image

                          // ✅ Customer Address (Shipping first, then billing)
                          if ((customer.shippingAddress ??
                                  customer.address ??
                                  '')
                              .isNotEmpty)
                            pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('ที่อยู่ลูกค้า :  ',
                                      style: pw.TextStyle(
                                          font: font, fontSize: bodySize)),
                                  pw.Expanded(
                                      child: pw.Text(
                                          customer.shippingAddress ??
                                              customer.address ??
                                              '-',
                                          style: pw.TextStyle(
                                              font: font, fontSize: bodySize))),
                                ]),

                          if ((customer.phone ?? '').isNotEmpty)
                            pw.Text('เบอร์โทรศัพท์ :  ${customer.phone}',
                                style: pw.TextStyle(
                                    font: font, fontSize: bodySize)),
                        ],
                      ),
                    ),
                  ],

                  pw.Divider(thickness: 1), // Solid Line

                  // --- META DATA (Refactored Layout) ---
                  pw.Container(
                    width: double.infinity,
                    child: pw.Column(
                      children: [
                        // Line 1: Bill No | Cashier
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                                'เลขที่บิล: ${orderId.toString().padLeft(9, '0')}', // Pad 9 per image example? Image: 000039166 -> 9 digits
                                style: pw.TextStyle(
                                    font: font, fontSize: bodySize)),
                            if (cashierName != null)
                              pw.Text('Cashier : $cashierName',
                                  style: pw.TextStyle(
                                      font: font, fontSize: bodySize)),
                          ],
                        ),

                        // Line 2: Date | Time
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('วันที่ :  $dateThai',
                                style: pw.TextStyle(
                                    font: font, fontSize: bodySize)),
                            pw.Text('เวลา :  $timeStr',
                                style: pw.TextStyle(
                                    font: font, fontSize: bodySize)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 2),
                  pw.Divider(
                      thickness: 1,
                      borderStyle:
                          pw.BorderStyle.dashed), // Dashed line before table

                  // --- ITEMS TABLE ---
                  pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4),
                      1: const pw.FlexColumnWidth(0.8),
                      2: const pw.FlexColumnWidth(1.1),
                      3: const pw.FlexColumnWidth(1.2),
                    },
                    children: [
                      // Header
                      pw.TableRow(
                        children: [
                          _buildCell('รายการ', fontBold, headerSize,
                              align: pw.TextAlign.left),
                          _buildCell('จน.', fontBold, headerSize,
                              align: pw.TextAlign.center),
                          _buildCell('ราคา', fontBold, headerSize,
                              align: pw.TextAlign.right),
                          _buildCell('รวม', fontBold, headerSize,
                              align: pw.TextAlign.right),
                        ],
                      ),
                      // Divider under header
                      pw.TableRow(children: [
                        pw.SizedBox(height: 2),
                        pw.SizedBox(height: 2),
                        pw.SizedBox(height: 2),
                        pw.SizedBox(height: 2)
                      ]),

                      // Rows (ตัวหนา)
                      ...items.map((e) => pw.TableRow(
                            children: [
                              pw.Padding(
                                padding:
                                    const pw.EdgeInsets.symmetric(vertical: 1),
                                child: pw.Text(e.productName,
                                    style: pw.TextStyle(
                                        font: fontBold, fontSize: bodySize)),
                              ),
                              _buildCell(e.quantity.toStringAsFixed(0),
                                  fontBold, bodySize,
                                  align: pw.TextAlign.center),
                              _buildCell(moneyFmt.format(e.price.toDouble()),
                                  fontBold, bodySize,
                                  align: pw.TextAlign.right),
                              _buildCell(moneyFmt.format(e.total.toDouble()),
                                  fontBold, bodySize,
                                  align: pw.TextAlign.right),
                            ],
                          )),
                    ],
                  ),

                  pw.SizedBox(height: 2),
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                  // --- TOTALS ---
                  pw.Container(
                    width: double.infinity,
                    child: pw.Column(
                      children: [
                        if (discount > 0) ...[
                          _buildTotalRow('รวมเป็นเงิน', moneyFmt.format(total),
                              fontBold, bodySize),
                          _buildTotalRow(
                              'ส่วนลด',
                              '-${moneyFmt.format(discount)}',
                              fontBold,
                              bodySize),
                        ],
                        pw.SizedBox(height: 2),
                        _buildTotalRow('ยอดสุทธิ', moneyFmt.format(grandTotal),
                            fontBold, bodySize + 4),
                        pw.SizedBox(height: 2),
                      ],
                    ),
                  ),

                  pw.Divider(thickness: 1),

                  // --- PAYMENTS ---
                  if (payments != null && payments.isNotEmpty) ...[
                    ...payments.map((p) => _buildTotalRow(
                        'ชำระโดย (${_translatePaymentMethod(p.method)})',
                        moneyFmt.format(p.amount),
                        fontBold,
                        bodySize)),
                    if (change > 0)
                      _buildTotalRow('เงินทอน', moneyFmt.format(change),
                          fontBold, bodySize),
                  ] else ...[
                    _buildTotalRow('รับเงิน', moneyFmt.format(received),
                        fontBold, bodySize),
                    _buildTotalRow(
                        'เงินทอน', moneyFmt.format(change), fontBold, bodySize),
                  ],

                  // --- FOOTER ---
                  if (footer.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(footer,
                        style: pw.TextStyle(font: font, fontSize: bodySize),
                        textAlign: pw.TextAlign.center),
                  ],

                  // --- SIGNATURE ---
                  if (!is80mm) ...[
                    pw.SizedBox(height: 40),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildSignatureBlock('ผู้รับเงิน', font, bodySize),
                        _buildSignatureBlock(
                            'ผู้ส่งของ/ลูกค้า', font, bodySize),
                      ],
                    ),
                  ],

                  pw.SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- Helper Widgets ---

  static pw.Widget _buildCell(String text, pw.Font font, double size,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Text(text,
          style: pw.TextStyle(font: font, fontSize: size), textAlign: align),
    );
  }

  static pw.Widget _buildTotalRow(
      String label, String value, pw.Font font, double size) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: size)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: size)),
      ],
    );
  }

  static pw.Widget _buildSignatureBlock(
      String label, pw.Font font, double size) {
    return pw.Column(
      children: [
        pw.Container(width: 120, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 5),
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: size)),
      ],
    );
  }

  static String _translatePaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':
        return 'เงินสด';
      case 'QR':
        return 'โอนเงิน/QR';
      case 'CREDIT':
        return 'บัตรเครดิต';
      case 'DEBT':
        return 'เงินเชื่อ (ติดหนี้)';
      default:
        return method;
    }
  }

  static String _thaiMonth(String monthStr) {
    int month = int.tryParse(monthStr) ?? 1;
    const months = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return monthStr;
  }
}
