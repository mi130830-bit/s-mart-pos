import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_helper.dart';
import '../../models/barcode_template.dart';

class BarcodeLabelPdf {
  /// ฟังก์ชันหลักสำหรับพิมพ์จาก Template พร้อมระบบแก้ปัญหาขอบขาด
  static Future<Uint8List> generateFromTemplate({
    required BarcodeTemplate template,
    required List<Map<String, dynamic>> products,
    bool showRuler = false,
  }) async {
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );

    // ✅ Method 1: กำหนดขอบเขตกระดาษจริงและ Margin ในระดับ PDF (Native PDF Margins)
    PdfPageFormat pageFormat = PdfPageFormat(
      template.paperWidth * PdfPageFormat.mm,
      template.paperHeight * PdfPageFormat.mm,
      marginLeft: template.marginLeft * PdfPageFormat.mm,
      marginRight: template.marginRight * PdfPageFormat.mm,
      marginTop: template.marginTop * PdfPageFormat.mm,
      marginBottom: template.marginBottom * PdfPageFormat.mm,
    );

    // ✅ เพิ่มการหมุนตามการตั้งค่าแม่แบบ
    if (template.orientation == 'landscape') {
      pageFormat = pageFormat.landscape;
    }

    int perPage = template.columns * template.rows;
    for (int i = 0; i < products.length; i += perPage) {
      final chunk = products.skip(i).take(perPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          // ✅ ใช้ Margin ตามโครงสร้าง PdfPageFormat เพื่อให้ Printer Driver รับทราบพื้นที่ปลอดภัย
          margin: pw.EdgeInsets.fromLTRB(
            template.marginLeft * PdfPageFormat.mm,
            template.marginTop * PdfPageFormat.mm,
            template.marginRight * PdfPageFormat.mm,
            template.marginBottom * PdfPageFormat.mm,
          ),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // ✅ Method 3: วาดกรอบสีแดงรอบพื้นที่พิมพ์ได้ (เฉพาะตอนเปิด Debug)
                if (template.printDebug)
                  pw.Positioned.fill(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.red, width: 0.5),
                      ),
                    ),
                  ),

                ...List.generate(chunk.length, (index) {
                  final product = chunk[index];
                  int col = index % template.columns;
                  int row = index ~/ template.columns;

                  // ✅ คำนวณตำแหน่ง X, Y โดยอ้างอิงจากระยะภายใน Margin (0,0 คือหลังขอบซ้าย/บน)
                  double xOffset =
                      (col * (template.labelWidth + template.horizontalGap));
                  double yOffset =
                      (row * (template.labelHeight + template.verticalGap));

                  return pw.Positioned(
                    left: xOffset * PdfPageFormat.mm,
                    top: yOffset * PdfPageFormat.mm,
                    child: _buildLabel(template, product, font, fontBold),
                  );
                }),
                if (showRuler)
                  _buildPageRuler(template.paperWidth, template.paperHeight),
              ],
            );
          },
        ),
      );
    }
    return pdf.save();
  }

  /// ✅ สร้างไม้บรรทัดวัดขนาด (หน่วย mm) สำหรับช่วยกะระยะใน PDF
  static pw.Widget _buildPageRuler(double widthMm, double heightMm) {
    return pw.Stack(
      children: [
        // ไม้บรรทัดแนวนอน (ด้านบน)
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Row(
            children: List.generate(widthMm.floor() + 1, (i) {
              bool isMajor = i % 10 == 0;
              bool isMid = i % 5 == 0 && !isMajor;
              return pw.Container(
                width: 1 * PdfPageFormat.mm,
                height: isMajor
                    ? 5 * PdfPageFormat.mm
                    : (isMid ? 3 * PdfPageFormat.mm : 1.5 * PdfPageFormat.mm),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      left: pw.BorderSide(color: PdfColors.red, width: 0.2)),
                ),
                child: isMajor
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 1),
                        child: pw.Text('$i',
                            style: const pw.TextStyle(
                                fontSize: 4, color: PdfColors.red)),
                      )
                    : null,
              );
            }),
          ),
        ),
        // ไม้บรรทัดแนวตั้ง (ด้านซ้าย)
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Column(
            children: List.generate(heightMm.floor() + 1, (i) {
              bool isMajor = i % 10 == 0;
              bool isMid = i % 5 == 0 && !isMajor;
              return pw.Container(
                height: 1 * PdfPageFormat.mm,
                width: isMajor
                    ? 5 * PdfPageFormat.mm
                    : (isMid ? 3 * PdfPageFormat.mm : 1.5 * PdfPageFormat.mm),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.red, width: 0.2)),
                ),
                child: isMajor
                    ? pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 1),
                        child: pw.Text('$i',
                            style: const pw.TextStyle(
                                fontSize: 4, color: PdfColors.red)),
                      )
                    : null,
              );
            }),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildLabel(BarcodeTemplate template,
      Map<String, dynamic> product, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      width: template.labelWidth * PdfPageFormat.mm,
      height: template.labelHeight * PdfPageFormat.mm,
      decoration: pw.BoxDecoration(
        border: template.printBorder
            ? pw.Border.all(width: template.borderWidth * PdfPageFormat.mm)
            : null,
      ),
      child: pw.Stack(
        children: template.elements.map((el) {
          String content = el.content;
          if (el.dataSource == BarcodeDataSource.productName) {
            content = product['name']?.toString() ?? '';
          } else if (el.dataSource == BarcodeDataSource.barcode) {
            content = product['barcode']?.toString() ?? '';
          } else if (el.dataSource == BarcodeDataSource.retailPrice) {
            double price = (product['retailPrice'] as num?)?.toDouble() ?? 0.0;
            content = '฿${price.toStringAsFixed(2)}';
          }

          return pw.Positioned(
            left: el.x * PdfPageFormat.mm,
            top: el.y * PdfPageFormat.mm,
            child: pw.SizedBox(
              width: el.width * PdfPageFormat.mm,
              height: el.height * PdfPageFormat.mm,
              child: _buildElement(el, content, font, fontBold),
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _buildElement(
      BarcodeElement el, String content, pw.Font font, pw.Font fontBold) {
    switch (el.type) {
      case BarcodeElementType.text:
        return pw.Align(
          alignment: el.textAlign == 'center'
              ? pw.Alignment.center
              : (el.textAlign == 'right'
                  ? pw.Alignment.centerRight
                  : pw.Alignment.centerLeft),
          child: pw.Text(
            content,
            style: pw.TextStyle(font: fontBold, fontSize: el.fontSize),
            textAlign: el.textAlign == 'center'
                ? pw.TextAlign.center
                : (el.textAlign == 'right'
                    ? pw.TextAlign.right
                    : pw.TextAlign.left),
          ),
        );
      case BarcodeElementType.barcode:
        return pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: content,
          drawText: true,
          textStyle: pw.TextStyle(font: font, fontSize: 7),
        );
      case BarcodeElementType.qrCode:
        return pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: content,
        );
      default:
        return pw.SizedBox();
    }
  }

  // ✅ ฟังก์ชันสนับสนุน Legacy สำหรับส่วนงานเดิม
  static Future<Uint8List> generate({
    required String barcode,
    required String name,
    required double price,
    required PdfPageFormat pageFormat,
    bool showRuler = false,
  }) async {
    final template = BarcodeTemplate(
      id: 'legacy',
      name: 'Legacy Single',
      paperWidth: pageFormat.width / PdfPageFormat.mm,
      paperHeight: pageFormat.height / PdfPageFormat.mm,
      columns: 1,
      rows: 1,
      labelWidth: pageFormat.width / PdfPageFormat.mm,
      labelHeight: pageFormat.height / PdfPageFormat.mm,
      elements: [
        BarcodeElement(
            id: 'n',
            type: BarcodeElementType.text,
            x: 0,
            y: 0,
            width: 30,
            height: 8,
            dataSource: BarcodeDataSource.productName,
            fontSize: 8),
        BarcodeElement(
            id: 'b',
            type: BarcodeElementType.barcode,
            x: 0,
            y: 8,
            width: 30,
            height: 12,
            dataSource: BarcodeDataSource.barcode),
        BarcodeElement(
            id: 'p',
            type: BarcodeElementType.text,
            x: 0,
            y: 20,
            width: 30,
            height: 5,
            dataSource: BarcodeDataSource.retailPrice,
            fontSize: 9),
      ],
    );
    return generateFromTemplate(
      template: template,
      products: [
        {'barcode': barcode, 'name': name, 'retailPrice': price}
      ],
      showRuler: showRuler,
    );
  }

  // ✅ เพิ่มฟังก์ชัน generateTest กลับคืนมาเพื่อแก้ Error ใน receipt_service.dart
  static Future<Uint8List> generateTest({
    required PdfPageFormat pageFormat,
    bool showRuler = false,
  }) async {
    return generate(
      barcode: '12345678',
      name: 'ทดสอบการพิมพ์ (Test)',
      price: 99.0,
      pageFormat: pageFormat,
      showRuler: showRuler,
    );
  }

  /// ✅ สร้าง PDF ขนาด A6 (100x150mm) สำหรับ XPrinter XP-420B
  /// จัดวางสติ๊กเกอร์ 32x25mm จำนวน 3 ดวงเรียงแนวตั้ง (กึ่งกลางหน้า)
  static Future<Uint8List> generateA6With3Stickers({
    required List<Map<String, dynamic>> products,
  }) async {
    final font = await PdfHelper.getFontRegular();
    final fontBold = await PdfHelper.getFontBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );

    // A6: 100x150 mm
    final pageFormat = PdfPageFormat(
      100 * PdfPageFormat.mm,
      150 * PdfPageFormat.mm,
      marginAll: 0,
    );

    // Group products into chunks of 3
    for (int i = 0; i < products.length; i += 3) {
      final chunk = products.skip(i).take(3).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            const double stickerHeight = 25.0;
            const double spacing = 2.0;

            // Calculate centering
            // Width: 100mm, Sticker: 32mm -> Left = (100-32)/2 = 34mm
            const double leftOffset = 34.0 * PdfPageFormat.mm;

            // Height: 150mm, Content: 3*25 + 2*2 = 79mm -> Top = (150-79)/2 = 35.5mm
            const double topOffset = 35.5 * PdfPageFormat.mm;

            return pw.Stack(
              children: [
                for (int j = 0; j < chunk.length; j++)
                  pw.Positioned(
                    left: leftOffset,
                    top: topOffset +
                        (j * (stickerHeight + spacing) * PdfPageFormat.mm),
                    child: _buildFixedSticker32x25(chunk[j], font, fontBold),
                  ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildFixedSticker32x25(
      Map<String, dynamic> product, pw.Font font, pw.Font fontBold) {
    final name = product['name']?.toString() ?? '';
    final barcode = product['barcode']?.toString() ?? '';
    final price = (product['retailPrice'] as num?)?.toDouble() ?? 0.0;

    return pw.Container(
      width: 32 * PdfPageFormat.mm,
      height: 25 * PdfPageFormat.mm,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            name,
            style: pw.TextStyle(font: font, fontSize: 8),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 1 * PdfPageFormat.mm),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: barcode,
            width: 28 * PdfPageFormat.mm,
            height: 10 * PdfPageFormat.mm,
            drawText: true,
            textStyle: pw.TextStyle(font: font, fontSize: 6),
          ),
          pw.SizedBox(height: 1 * PdfPageFormat.mm),
          pw.Text(
            '${price.toStringAsFixed(0)}.-',
            style: pw.TextStyle(font: fontBold, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
