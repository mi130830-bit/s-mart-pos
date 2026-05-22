import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../../models/billing_note.dart';
import '../shop_info_service.dart';
import 'pdf_template.dart';

class BillingNotePdfGenerator extends PdfTemplate {
  Future<Uint8List> generate({
    required BillingNote note,
    required List<Map<String, dynamic>> items,
  }) async {
    await loadFonts();
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
              buildHeader(
                'ใบวางบิล',
                'BILLING NOTE',
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
                  pw.Text('เลขที่: ${note.documentNo}', style: style('body')),
                  pw.Text(
                      'วันที่: ${DateFormat('dd/MM/yyyy').format(note.issueDate)}',
                      style: style('body')),
                  pw.Text(
                      'ครบกำหนด: ${DateFormat('dd/MM/yyyy').format(note.dueDate)}',
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
                    pw.Text('ลูกค้า (Customer): ', style: style('h3')),
                    pw.Expanded(
                      child: pw.Text(note.customerName ?? '-',
                          style: style('body')),
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
                    buildSignatureBox('ผู้ผู้วางบิล/Collector'),
                    buildSignatureBox('ผู้รับวางบิล/Customer'),
                  ]),
              pw.SizedBox(height: 20),
              pw.Text('หมายเหตุ: ${note.note ?? "-"}',
                  style: style('small', color: PdfColors.grey700)),
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
                tableHeader('ลำดับ\nNo.'),
                tableHeader('รายการ\nDescription'),
                tableHeader('จำนวนเงิน\nAmount'),
              ]),
          ...items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            final desc = item['description'] ?? 'Bill #${item['orderId']}';
            final amount = double.tryParse(item['amount'].toString()) ?? 0.0;
            return pw.TableRow(children: [
              tableCell('$index', align: pw.TextAlign.center),
              tableCell(desc),
              tableCell(NumberFormat('#,##0.00').format(amount),
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
                      child: pw.Text('รวมเงิน (Total)', style: style('h3'))),
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
