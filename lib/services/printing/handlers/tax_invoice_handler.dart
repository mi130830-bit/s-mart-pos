import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:decimal/decimal.dart';

import '../../../models/order_item.dart';
import '../../../models/customer.dart';
import '../core/print_core_service.dart';
import '../utils/print_settings_helper.dart';
import '../utils/print_data_helper.dart';

import '../../pdf/tax_invoice_pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class TaxInvoiceHandler {
  static Future<void> printTaxInvoice({
    required int orderId,
    required List<OrderItem> items,
    required double total,
    required double grandTotal,
    required double vatRate,
    required Customer customer,
    Printer? printerOverride,
    bool isPreview = false,
  }) async {
    try {
      final pageFormat = PdfPageFormat.a4;
      final shopInfo = await PrintDataHelper.getShopInfo();
      final shopLogoBytes = await PrintDataHelper.getShopLogoBytes();
      final validCustomer = await PrintDataHelper.refreshCustomer(customer);

      final Uint8List bytes = await TaxInvoicePdf.generate(
        orderId: orderId,
        items: items,
        total: total,
        grandTotal: grandTotal,
        vatRate: vatRate,
        customer: validCustomer!,
        shopInfo: shopInfo,
        shopLogoBytes: shopLogoBytes,
        pageFormat: pageFormat,
      );

      final printer = printerOverride ?? await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyTaxPrinter);

      await PrintCoreService.printDocument(
        bytes: bytes,
        docName: 'TaxInvoice_$orderId',
        format: pageFormat,
        printer: printer,
        isPreview: isPreview,
      );
    } catch (e) {
      debugPrint('❌ printTaxInvoice Error: $e');
    }
  }

  static Future<void> testA5Document(Printer? printer) async {
    try {
      final pdf = pw.Document();
      final fontData = await rootBundle.load('assets/fonts/sarabun/Sarabun-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final style = pw.TextStyle(font: ttf, fontSize: 14);
      final headerStyle = pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold);

      pdf.addPage(
        pw.Page(
          pageFormat: PrintSettingsHelper.formatA5,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text('ทดสอบ A5 สำหรับ Epson LQ-310', style: headerStyle),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('วันที่พิมพ์: ${DateTime.now().toString()}', style: style),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Text('รายการสินค้าทดสอบ (Test Items):', style: style),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('1. สินค้าตัวอย่าง A', style: style),
                      pw.Text('100.00', style: style),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('2. สินค้าตัวอย่าง B', style: style),
                      pw.Text('250.00', style: style),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text('รวมทั้งสิ้น: 350.00 บาท', style: headerStyle),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Center(
                      child: pw.Text('... End of Test ...',
                          style: style.copyWith(fontSize: 10))),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();

      await PrintCoreService.printDocument(
        bytes: bytes,
        docName: 'Test_A5_LQ310',
        format: PrintSettingsHelper.formatA5,
        printer: printer,
        isPreview: false,
      );
    } catch (e) {
      debugPrint('Error testing A5 document: $e');
    }
  }

  static Future<Uint8List> testTaxInvoicePreview() async {
    final format = PdfPageFormat.a4;
    final shopInfo = await PrintDataHelper.getShopInfo();
    final dummyItems = List.generate(
        3,
        (index) => OrderItem(
            productId: index + 1,
            productName: 'สินค้ามี VAT ${index + 1}',
            price: Decimal.fromInt(107),
            quantity: Decimal.one,
            total: Decimal.fromInt(107)));

    final customer = Customer(
        id: 1,
        firstName: 'บริษัท',
        lastName: 'ตัวอย่าง จำกัด (สำนักงานใหญ่)',
        address: '123 ถนนตัวอย่าง แขวงตัวอย่าง เขตตัวอย่าง กทม. 10000',
        phone: '02-123-4567',
        taxId: '1234567890123',
        email: 'test@example.com',
        memberCode: 'TEST001',
        currentPoints: 0);

    final shopLogoBytes = await PrintDataHelper.getShopLogoBytes();
    return TaxInvoicePdf.generate(
      orderId: 77777,
      items: dummyItems,
      total: 300,
      grandTotal: 321,
      vatRate: 0.07,
      customer: customer,
      shopInfo: shopInfo,
      shopLogoBytes: shopLogoBytes,
      pageFormat: format,
    );
  }

  static Future<void> testTaxInvoice(Printer? printer, bool isPreview) async {
    final bytes = await testTaxInvoicePreview();
    await PrintCoreService.printDocument(
      bytes: bytes,
      printer: printer,
      docName: 'Test_Tax_Invoice',
      format: PdfPageFormat.a4,
      isPreview: isPreview,
    );
  }
}
