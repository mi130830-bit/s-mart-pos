import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../models/billing_note.dart';
import '../shop_info_service.dart';

// Service class remains the public interface
class PdfDocumentService {
  final _PurchaseOrderPdfGenerator _poGenerator = _PurchaseOrderPdfGenerator();
  final _BillingNotePdfGenerator _billingGenerator = _BillingNotePdfGenerator();

  Future<Uint8List> generateBillingNote({
    required BillingNote note,
    required List<Map<String, dynamic>> items,
  }) async {
    return await _billingGenerator.generate(note: note, items: items);
  }

  Future<Uint8List> generatePurchaseOrder({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> items,
  }) async {
    return await _poGenerator.generate(header: header, items: items);
  }
}

// Private abstract base class for PDF templates
abstract class _PdfTemplate {
  static pw.Font? _baseFont;
  static pw.Font? _boldFont;
  static bool _fontsLoaded = false;

  Future<void> _loadFonts() async {
    if (_fontsLoaded) return;
    try {
      final fontData = await rootBundle.load('assets/fonts/THSarabunNew.ttf');
      _baseFont = pw.Font.ttf(fontData);
      final boldFontData =
          await rootBundle.load('assets/fonts/THSarabunNew Bold.ttf');
      _boldFont = pw.Font.ttf(boldFontData);
      _fontsLoaded = true;
    } catch (e) {
      // Font loading can fail, handle this gracefully.
      // For now, we'll print an error. In a real app, you might want to
      // fall back to a default font or show an error to the user.
      // ignore: avoid_print
      print('Error loading PDF fonts: $e');
    }
  }

  pw.TextStyle _style(String type, {PdfColor? color}) {
    // Fallback to a default font if custom fonts fail to load
    final base = _baseFont ?? pw.Font.helvetica();
    final bold = _boldFont ?? pw.Font.helveticaBold();

    switch (type) {
      case 'h1':
        return pw.TextStyle(font: bold, fontSize: 30, color: color);
      case 'h2':
        return pw.TextStyle(font: bold, fontSize: 24, color: color);
      case 'h3':
        return pw.TextStyle(font: bold, fontSize: 16, color: color);
      case 'body':
        return pw.TextStyle(font: base, fontSize: 14, color: color);
      case 'body-bold':
        return pw.TextStyle(font: bold, fontSize: 14, color: color);
      case 'small':
        return pw.TextStyle(font: base, fontSize: 12, color: color);
      default:
        return pw.TextStyle(font: base, fontSize: 14, color: color);
    }
  }

  pw.Widget _buildHeader(String docTitle, String docSubtitle,
      List<pw.Widget> leftInfo, List<pw.Widget> rightInfo) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: leftInfo),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(docTitle, style: _style('h1')),
              pw.Text(docSubtitle,
                  style: _style('body-bold', color: PdfColors.grey)),
              pw.SizedBox(height: 8),
              ...rightInfo,
            ],
          ),
        ],
      ),
      pw.Divider(),
    ]);
  }

  pw.Widget _buildSignatureBox(String label) {
    return pw.Column(children: [
      pw.Container(
        width: 150,
        height: 1,
        color: PdfColors.black,
      ),
      pw.SizedBox(height: 5),
      pw.Text(label, style: _style('body')),
      pw.SizedBox(height: 20),
      pw.Text('(___ / ___ / ___)', style: _style('small')),
    ]);
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: _style('body-bold'), textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget _tableCell(String text, {pw.TextAlign? align}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: _style('body'), textAlign: align),
    );
  }
}

// Implementation for Purchase Orders
class _PurchaseOrderPdfGenerator extends _PdfTemplate {
  Future<Uint8List> generate({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> items,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    final shopInfo = await ShopInfoService().getShopInfo();
    final shopName = shopInfo.name;
    final shopAddress = shopInfo.address;
    final shopPhone = shopInfo.phone;
    final shopTaxId = shopInfo.taxId;

    final poId = header['id'];
    final supplierName = header['supplierName'] ?? 'Unknown Supplier';
    final createdDate =
        DateTime.tryParse(header['createdAt'].toString()) ?? DateTime.now();
    final totalAmount =
        double.tryParse(header['totalAmount'].toString()) ?? 0.0;
    final note = header['note'] ?? '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                'ใบสั่งซื้อ',
                'PURCHASE ORDER',
                [
                  pw.Text(shopName, style: _style('h2')),
                  if (shopAddress.isNotEmpty)
                    pw.Text(shopAddress, style: _style('body')),
                  if (shopPhone.isNotEmpty)
                    pw.Text('Tel: $shopPhone', style: _style('body')),
                  if (shopTaxId.isNotEmpty)
                    pw.Text('Tax ID: $shopTaxId', style: _style('body')),
                ],
                [
                  pw.Text('เลขที่: PO-$poId', style: _style('body')),
                  pw.Text(
                      'วันที่: ${DateFormat('dd/MM/yyyy').format(createdDate)}',
                      style: _style('body')),
                ],
              ),
              pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 10),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(children: [
                    pw.Text('ผู้จำหน่าย (Supplier): ', style: _style('h3')),
                    pw.Expanded(
                      child: pw.Text(supplierName, style: _style('body')),
                    ),
                  ])),
              pw.SizedBox(height: 10),
              _buildItemsTable(items),
              pw.SizedBox(height: 20),
              _buildGrandTotal(totalAmount),
              pw.Spacer(),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSignatureBox('ผู้จัดทำ/Prepared By'),
                    _buildSignatureBox('ผู้อนุมัติ/Approved By'),
                    _buildSignatureBox('ผู้รับของ/Received By'),
                  ]),
              pw.SizedBox(height: 10),
              if (note.isNotEmpty)
                pw.Text('หมายเหตุ: $note',
                    style: _style('small', color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    final nf = NumberFormat('#,##0.00');
    final nfQty = NumberFormat('#,##0');

    return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(4),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(2),
          4: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableHeader('ลำดับ\nNo.'),
                _tableHeader('รายการ\nDescription'),
                _tableHeader('จำนวน\nQty'),
                _tableHeader('ราคา/หน่วย\nUnit Price'),
                _tableHeader('รวม\nTotal'),
              ]),
          ...items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            return pw.TableRow(children: [
              _tableCell('$index', align: pw.TextAlign.center),
              _tableCell(item['productName'] ?? '-'),
              _tableCell(
                  nfQty.format(
                      double.tryParse(item['quantity'].toString()) ?? 0),
                  align: pw.TextAlign.center),
              _tableCell(
                  nf.format(double.tryParse(item['costPrice'].toString()) ?? 0),
                  align: pw.TextAlign.right),
              _tableCell(
                  nf.format(double.tryParse(item['total'].toString()) ?? 0),
                  align: pw.TextAlign.right),
            ]);
          }),
        ]);
  }

  pw.Widget _buildGrandTotal(double totalAmount) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Container(
          width: 250,
          child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('รวมเงินทั้งสิ้น', style: _style('h3'))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                          NumberFormat('#,##0.00').format(totalAmount),
                          style: _style('h3'),
                          textAlign: pw.TextAlign.right)),
                ])
              ]))
    ]);
  }
}

// Implementation for Billing Notes
class _BillingNotePdfGenerator extends _PdfTemplate {
  Future<Uint8List> generate({
    required BillingNote note,
    required List<Map<String, dynamic>> items,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();

    final shopInfo = await ShopInfoService().getShopInfo();
    final shopName = shopInfo.name;
    final shopAddress = shopInfo.address;
    final shopPhone = shopInfo.phone;
    final shopTaxId = shopInfo.taxId;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                'ใบวางบิล',
                'BILLING NOTE',
                [
                  pw.Text(shopName, style: _style('h2')),
                  if (shopAddress.isNotEmpty)
                    pw.Text(shopAddress, style: _style('body')),
                  if (shopPhone.isNotEmpty)
                    pw.Text('Tel: $shopPhone', style: _style('body')),
                  if (shopTaxId.isNotEmpty)
                    pw.Text('Tax ID: $shopTaxId', style: _style('body')),
                ],
                [
                  pw.Text('เลขที่: ${note.documentNo}', style: _style('body')),
                  pw.Text(
                      'วันที่: ${DateFormat('dd/MM/yyyy').format(note.issueDate)}',
                      style: _style('body')),
                  pw.Text(
                      'ครบกำหนด: ${DateFormat('dd/MM/yyyy').format(note.dueDate)}',
                      style: _style('body')),
                ],
              ),
              pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 10),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(children: [
                    pw.Text('ลูกค้า (Customer): ', style: _style('h3')),
                    pw.Expanded(
                      child: pw.Text(note.customerName ?? '-',
                          style: _style('body')),
                    ),
                  ])),
              pw.SizedBox(height: 10),
              _buildItemsTable(items),
              pw.SizedBox(height: 20),
              _buildGrandTotal(note.totalAmount),
              pw.Spacer(),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSignatureBox('ผู้ผู้วางบิล/Collector'),
                    _buildSignatureBox('ผู้รับวางบิล/Customer'),
                  ]),
              pw.SizedBox(height: 20),
              pw.Text('หมายเหตุ: ${note.note ?? "-"}',
                  style: _style('small', color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(4),
          2: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableHeader('ลำดับ\nNo.'),
                _tableHeader('รายการ\nDescription'),
                _tableHeader('จำนวนเงิน\nAmount'),
              ]),
          ...items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            final desc = item['description'] ?? 'Bill #${item['orderId']}';
            final amount = double.tryParse(item['amount'].toString()) ?? 0.0;
            return pw.TableRow(children: [
              _tableCell('$index', align: pw.TextAlign.center),
              _tableCell(desc),
              _tableCell(NumberFormat('#,##0.00').format(amount),
                  align: pw.TextAlign.right),
            ]);
          }),
        ]);
  }

  pw.Widget _buildGrandTotal(double totalAmount) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Container(
          width: 200,
          child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('รวมเงิน (Total)', style: _style('h3'))),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                          NumberFormat('#,##0.00').format(totalAmount),
                          style: _style('h3'),
                          textAlign: pw.TextAlign.right)),
                ])
              ]))
    ]);
  }
}
