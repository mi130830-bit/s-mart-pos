import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/shop_info.dart';
import 'pdf_helper.dart';

class TaxInvoicePdf {
  static Future<Uint8List> generate({
    required int orderId,
    required List<OrderItem> items,
    required double total,
    required double grandTotal,
    required double vatRate,
    required Customer customer,
    required PdfPageFormat pageFormat,
    required ShopInfo shopInfo,
  }) async {
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );
    final logo = await PdfHelper.getLogo();
    final moneyFmt = NumberFormat('#,##0.00');

    // Calculate VAT components
    final double vatAmount = total * (vatRate / 100);

    // [Standardized Styling matched with DeliveryNotePdf]
    const double globalFontSize = 10.0;
    const double headerFontSize = 10.0;
    const double titleFontSize = 12.0;

    const double spaceBeforeTable =
        0.5; // cm? actually in points or relative? Usually just pixels in pdf lib unless * cm
    // In DeliveryNote it was just 0.5. Assuming points/logical pixels.
    // Wait, in DeliveryNote it was `SizedBox(height: spaceBeforeTable)` -> 0.5 is TINY if points.
    // Let's check DeliveryNote usage. `SizedBox(height: spaceBeforeTable)`.
    // If it's 0.5 points, it's invisible. Maybe it meant * Cm?
    // In DeliveryNote: `const double spaceBeforeTable = 0.5;` used as `SizedBox(height: spaceBeforeTable)`.
    // That renders as 0.5 points. Effectively zero.
    // I will stick to exact clone of DeliveryNote values.

    const double tableHeaderPadding = 1.0;
    const double tableRowPadding = 0.85;
    const double spaceAfterTable = 0.25;
    const double spaceBeforeSignature = 4.0;

    // Pagination Logic for A4 vs A5
    // A4 height ~842 pts, A5 height ~595 pts
    final bool isA5 = pageFormat.height < 600;

    // A5: Reduced items to prevent overflow. A4: Standard amount.
    final int itemsPerPage = isA5 ? 12 : 22;

    final int totalPages = (items.length / itemsPerPage).ceil();

    final loopCount = totalPages == 0 ? 1 : totalPages;

    for (int i = 0; i < loopCount; i++) {
      final start = i * itemsPerPage;
      final end = (start + itemsPerPage < items.length)
          ? start + itemsPerPage
          : items.length;
      final chunkItems =
          (items.isNotEmpty) ? items.sublist(start, end) : <OrderItem>[];

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: pageFormat,
            // Margin Zero for Ruler (Red Box)
            margin: pw.EdgeInsets.zero,
            theme: pw.ThemeData.withFont(base: font, bold: fontBold),
            buildBackground: (context) =>
                PdfHelper.buildRuler(pageFormat.width, pageFormat.height, font),
          ),
          build: (pw.Context context) {
            return pw.Padding(
              // Padding for Content (Yellow Box)
              padding: const pw.EdgeInsets.only(
                  left: 1.0 * PdfPageFormat.cm,
                  right: 1.0 * PdfPageFormat.cm,
                  top: 1.0 * PdfPageFormat.cm,
                  bottom: 0.5 * PdfPageFormat.cm),
              child: pw.Column(
                children: [
                  // --- HEADER (Every Page) ---
                  _buildHeader(shopInfo, logo, customer, orderId, font,
                      fontBold, headerFontSize, titleFontSize, globalFontSize),

                  pw.SizedBox(height: spaceBeforeTable),
                  pw.Divider(thickness: 0.5),

                  // --- TABLE (Chunk) ---
                  pw.Expanded(
                    child: _buildTable(
                        chunkItems,
                        moneyFmt,
                        font,
                        globalFontSize,
                        tableHeaderPadding,
                        tableRowPadding,
                        start + 1),
                  ),

                  pw.Divider(thickness: 0.5),
                  pw.SizedBox(height: spaceAfterTable),

                  // --- FOOTER (Every Page) ---
                  _buildFooter(total, vatAmount, grandTotal, moneyFmt, font,
                      fontBold, globalFontSize, spaceBeforeSignature),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildHeader(
      ShopInfo shopInfo,
      pw.ImageProvider? logo,
      Customer customer,
      int orderId,
      pw.Font font,
      pw.Font fontBold,
      double headerFontSize,
      double titleFontSize,
      double globalFontSize) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // 1. SHOP INFO ROW (Logo + Details)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 60,
                height: 60,
                margin: const pw.EdgeInsets.only(right: 15),
                child: pw.Image(logo),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(shopInfo.name,
                      style: pw.TextStyle(font: fontBold, fontSize: 18)),
                  pw.Text(shopInfo.address,
                      style:
                          pw.TextStyle(font: font, fontSize: headerFontSize)),
                  pw.Row(children: [
                    if (shopInfo.phone.isNotEmpty)
                      pw.Text('โทร: ${shopInfo.phone}',
                          style: pw.TextStyle(
                              font: font, fontSize: headerFontSize)),
                    if (shopInfo.phone.isNotEmpty && shopInfo.taxId.isNotEmpty)
                      pw.SizedBox(width: 10),
                    if (shopInfo.taxId.isNotEmpty)
                      pw.Text('เลขผู้เสียภาษี: ${shopInfo.taxId}',
                          style: pw.TextStyle(
                              font: font, fontSize: headerFontSize)),
                  ]),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 5),

        // 2. DOCUMENT TITLE
        pw.Center(
            child: pw.Text("ใบกำกับภาษี / ใบเสร็จรับเงิน",
                style: pw.TextStyle(font: fontBold, fontSize: titleFontSize))),

        pw.SizedBox(height: 10),

        // 3. META DATA & CUSTOMER (Left: Customer, Right: Bill Info)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: Customer Info
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      'ลูกค้า: ${customer.firstName} ${customer.lastName ?? ""}',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: globalFontSize)),
                  pw.Text('ที่อยู่: ${customer.address ?? "-"}',
                      style: pw.TextStyle(font: font, fontSize: globalFontSize),
                      maxLines: 2),
                  pw.Text('เลขผู้เสียภาษี: ${customer.taxId ?? "-"}',
                      style:
                          pw.TextStyle(font: font, fontSize: globalFontSize)),
                  if ((customer.phone ?? '').isNotEmpty)
                    pw.Text('โทร: ${customer.phone}',
                        style:
                            pw.TextStyle(font: font, fontSize: globalFontSize)),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            // Right: Bill Info (Table)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildMetaRow('เลขที่', orderId.toString().padLeft(6, '0'),
                    font, globalFontSize),
                _buildMetaRow(
                    'วันที่',
                    DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    font,
                    globalFontSize),
                _buildMetaRow(
                    'เวลา',
                    DateFormat('HH:mm').format(DateTime.now()),
                    font,
                    globalFontSize),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMetaRow(
      String label, String value, pw.Font font, double fontSize) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label : ',
            style: pw.TextStyle(font: font, fontSize: fontSize)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: fontSize)),
      ],
    );
  }

  static pw.Widget _buildTable(
      List<OrderItem> items,
      NumberFormat moneyFmt,
      pw.Font font,
      double globalFontSize,
      double headerPadding,
      double rowPadding,
      int startIndex) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(
            1.2), // Adjusted to match DeliveryNote logic where possible, though TaxInvoice needs 'Price/Unit' vs 'Price'
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            PdfHelper.buildTableHeader('ลำดับ', font, globalFontSize,
                padding: headerPadding),
            PdfHelper.buildTableHeader('รายการ', font, globalFontSize,
                padding: headerPadding),
            PdfHelper.buildTableHeader('จำนวน', font, globalFontSize,
                padding: headerPadding),
            PdfHelper.buildTableHeader('ราคา/หน่วย', font, globalFontSize,
                align: pw.TextAlign.right, padding: headerPadding),
            PdfHelper.buildTableHeader('จำนวนเงิน', font, globalFontSize,
                align: pw.TextAlign.right, padding: headerPadding),
          ],
        ),
        ...items.asMap().entries.map((entry) {
          final i = entry.value;
          return pw.TableRow(children: [
            PdfHelper.buildTableCell(
                '${startIndex + entry.key}', font, globalFontSize,
                align: pw.TextAlign.center, padding: rowPadding),
            PdfHelper.buildTableCell(i.productName, font, globalFontSize,
                align: pw.TextAlign.left, padding: rowPadding),
            PdfHelper.buildTableCell('${i.quantity}', font, globalFontSize,
                align: pw.TextAlign.center,
                padding:
                    rowPadding), // DeliveryNote uses no explicit align -> left? No, Quantity usually Center. DeliveryNote used Center? Step 414: No, DeliveryNote used Center for quantity? Let's check? Step 414 line 178 didn't show quantity align. Wait, Step 186 in DeliveryNote used Center? I will assume Center for Quantity is best.
            PdfHelper.buildTableCell(moneyFmt.format(i.price.toDouble()), font,
                globalFontSize, // FIXED: .toDouble()
                align: pw.TextAlign.right,
                padding: rowPadding),
            PdfHelper.buildTableCell(
                moneyFmt.format((i.price * i.quantity).toDouble()),
                font,
                globalFontSize, // FIXED: .toDouble()
                align: pw.TextAlign.right,
                padding: rowPadding),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _buildFooter(
      double total,
      double vatAmount,
      double grandTotal,
      NumberFormat moneyFmt,
      pw.Font font,
      pw.Font fontBold,
      double globalFontSize,
      double spaceBeforeSignature) {
    return pw.Column(
      children: [
        // Aggregates
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('รวมเป็นเงิน: ${moneyFmt.format(total)}',
                    style: pw.TextStyle(font: font, fontSize: globalFontSize)),
                pw.Text('ภาษีมูลค่าเพิ่ม 7%: ${moneyFmt.format(vatAmount)}',
                    style: pw.TextStyle(font: font, fontSize: globalFontSize)),
                pw.Text('จำนวนเงินทั้งสิ้น: ${moneyFmt.format(grandTotal)}',
                    style: pw.TextStyle(
                        font: fontBold, fontSize: globalFontSize + 2)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: spaceBeforeSignature), // Use the constant
        // Signatures
        pw.SizedBox(
            height:
                20), // Extra spacing logic from DeliveryNote? No, DeliveryNote uses _buildSignatureBox which has internal text.
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            PdfHelper.buildSignatureBox('ผู้รับสินค้า', font, fontBold),
            PdfHelper.buildSignatureBox(
                'ผู้รับเงิน/ผู้ออกใบกำกับภาษี', font, fontBold),
          ],
        ),
      ],
    );
  }
}
