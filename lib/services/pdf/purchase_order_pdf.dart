import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../shop_info_service.dart';
import 'pdf_template.dart';

class PurchaseOrderPdfGenerator extends PdfTemplate {
  Future<Uint8List> generate({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> items,
  }) async {
    await loadFonts();
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
              buildHeader(
                'ใบสั่งซื้อ',
                'PURCHASE ORDER',
                [
                  pw.Text(shopName, style: style('h2')),
                  if (shopAddress.isNotEmpty)
                    pw.Text(shopAddress, style: style('body')),
                  if (shopPhone.isNotEmpty)
                    pw.Text('Tel: $shopPhone', style: style('body')),
                  if (shopTaxId.isNotEmpty)
                    pw.Text('Tax ID: $shopTaxId', style: style('body')),
                ],
                [
                  pw.Text('เลขที่: PO-$poId', style: style('body')),
                  pw.Text(
                      'วันที่: ${DateFormat('dd/MM/yyyy').format(createdDate)}',
                      style: style('body')),
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
                    pw.Text('ผู้จำหน่าย (Supplier): ', style: style('h3')),
                    pw.Expanded(
                      child: pw.Text(supplierName, style: style('body')),
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
                    buildSignatureBox('ผู้จัดทำ/Prepared By'),
                    buildSignatureBox('ผู้อนุมัติ/Approved By'),
                    buildSignatureBox('ผู้รับของ/Received By'),
                  ]),
              pw.SizedBox(height: 10),
              if (note.isNotEmpty)
                pw.Text('หมายเหตุ: $note',
                    style: style('small', color: PdfColors.grey700)),
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
                tableHeader('ลำดับ\nNo.'),
                tableHeader('รายการ\nDescription'),
                tableHeader('จำนวน\nQty'),
                tableHeader('ราคา/หน่วย\nUnit Price'),
                tableHeader('รวม\nTotal'),
              ]),
          ...items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            return pw.TableRow(children: [
              tableCell('$index', align: pw.TextAlign.center),
              tableCell(item['productName'] ?? '-'),
              tableCell(
                  nfQty.format(
                      double.tryParse(item['quantity'].toString()) ?? 0),
                  align: pw.TextAlign.center),
              tableCell(
                  nf.format(double.tryParse(item['costPrice'].toString()) ?? 0),
                  align: pw.TextAlign.right),
              tableCell(
                  nf.format(double.tryParse(item['total'].toString()) ?? 0),
                  align: pw.TextAlign.right),
            ]);
          }),
        ]);
  }

  pw.Widget _buildGrandTotal(double totalAmount) {
    return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
              width: 250,
              child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('รวมเงินทั้งสิ้น', style: style('h3'))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              NumberFormat('#,##0.00').format(totalAmount),
                              style: style('h3'),
                              textAlign: pw.TextAlign.right)),
                    ])
                  ]))
        ]);
  }
}
