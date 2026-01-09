import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:decimal/decimal.dart';

// Models
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/payment_record.dart';
import '../../models/label_config.dart';
import '../../models/shop_info.dart';

// Services & PDF Generators
import '../pdf/delivery_note_pdf.dart';
import '../pdf/tax_invoice_pdf.dart';
import '../pdf/thermal_receipt_pdf.dart';
import '../pdf/cash_receipt_pdf.dart';
import '../pdf/barcode_label_pdf.dart';

import 'label_printer_service.dart';
import '../shop_info_service.dart';
import '../local_settings_service.dart';

class ReceiptService {
  // Keys for Printer Settings
  static const String _keyCashPrinter = 'printer_cash_name';
  static const String _keyCashPaperSize = 'printer_cash_paper_size';
  static const String _keyCashBillPrinter = 'printer_cash_bill_name'; // New
  static const String _keyCashBillPaperSize =
      'printer_cash_bill_paper_size'; // New
  static const String _keyTaxPrinter = 'printer_tax_name';
  static const String _keyDeliveryPrinter = 'printer_delivery_name';
  static const String _keyDeliveryPaperSize = 'printer_delivery_paper_size';
  static const String _keyBarcodePrinter = 'printer_barcode_name';
  static const String _keyBarcodePaperSize = 'printer_barcode_paper_size';

  Future<ShopInfo> _getShopInfo() async {
    return ShopInfoService().getShopInfo();
  }

  Future<Printer?> _getPrinterBySettingKey(String key) async {
    final settings = LocalSettingsService();

    if (key == _keyBarcodePrinter) {
      final manualName = await settings.getPrinterManualName();
      if (manualName != null && manualName.isNotEmpty) {
        return Printer(url: manualName, name: manualName);
      }
    }

    final name = await settings.getString(key);
    if (name == null || name.isEmpty) return null;

    try {
      final printers = await Printing.listPrinters();
      final searchName = name.trim().toLowerCase();
      debugPrint('🔍 Searching for printer matching: "$searchName"');

      return printers.firstWhere(
        (p) => p.name.trim().toLowerCase() == searchName,
        orElse: () {
          debugPrint('❌ Printer "$name" not found. Trying partial match...');
          try {
            return printers.firstWhere(
              (p) => p.name.toLowerCase().contains(searchName),
            );
          } catch (e) {
            debugPrint('⚠️ Forcing manual printer object for: $name');
            return Printer(url: name, name: name);
          }
        },
      );
    } catch (e) {
      debugPrint('⚠️ _getPrinterBySettingKey error: $e');
      return Printer(url: name, name: name);
    }
  }

  // ✅ กำหนดขนาด BillA5 แบบ "ไร้ขอบ" (Zero Margin)
  static final PdfPageFormat _customA5 = PdfPageFormat(
    22.86 * PdfPageFormat.cm, // 9 นิ้ว
    13.97 * PdfPageFormat.cm, // 5.5 นิ้ว
    marginAll: 0,
  );

  static const PdfPageFormat _formatA5 = PdfPageFormat(
    148 * PdfPageFormat.mm,
    210 * PdfPageFormat.mm,
    marginAll: 0,
  );

  Future<PdfPageFormat> _getDeliveryPageFormat() async {
    final settings = LocalSettingsService();
    final size = await settings.getString(_keyDeliveryPaperSize) ?? 'A5';
    // ถ้าเลือก A4 ก็ส่ง A4 ถ้าเลือก A5 (หรืออื่นๆ) ให้ส่งค่า Custom 9x5.5 นิ้ว
    return size == 'A4' ? PdfPageFormat.a4 : _customA5;
  }

  Future<PdfPageFormat> _getCashPageFormat() async {
    final settings = LocalSettingsService();
    final size = await settings.getString(_keyCashPaperSize) ?? '80mm';

    if (size == 'A4') return PdfPageFormat.a4;
    if (size == 'A5') return _customA5;

    if (size == '58mm') {
      return PdfPageFormat(
        57 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 2 * PdfPageFormat.mm,
      );
    }

    return PdfPageFormat(
      71 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 0,
      marginTop: 2 * PdfPageFormat.mm,
      marginBottom: 2 * PdfPageFormat.mm,
    );
  }

  Future<PdfPageFormat> _getCashBillPageFormat() async {
    final settings = LocalSettingsService();
    final size = await settings.getString(_keyCashBillPaperSize) ?? 'A4';
    return size == 'A4' ? PdfPageFormat.a4 : _customA5;
  }

  // --- 1. BILLING / THERMAL RECEIPT ---
  Future<void> printReceipt({
    required int orderId,
    required List<OrderItem> items,
    required double total,
    double discount = 0.0,
    required double grandTotal,
    required double received,
    required double change,
    List<PaymentRecord>? payments,
    Customer? customer,
    Printer? printerOverride,
    PdfPageFormat? pageFormatOverride,
    bool isPreview = false,
    bool useCashBillSettings = false,
    String? cashierName, // ✅ Receive Cashier Name
  }) async {
    try {
      final pageFormat = pageFormatOverride ??
          (useCashBillSettings
              ? await _getCashBillPageFormat()
              : await _getCashPageFormat());

      final shopInfo = await _getShopInfo();
      final isThermal = pageFormat.width < 270; // Logic remains valid

      Uint8List bytes;
      if (isThermal) {
        bytes = await ThermalReceiptPdf.generate(
          orderId: orderId,
          items: items,
          total: total,
          discount: discount,
          grandTotal: grandTotal,
          received: received,
          change: change,
          payments: payments,
          customer: customer,
          pageFormat: pageFormat,
          shopInfo: shopInfo,
          cashierName: cashierName, // ✅ Pass to Thermal PDF
        );
      } else {
        bytes = await CashReceiptPdf.generate(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: discount,
          pageFormat: pageFormat,
          shopInfo: shopInfo,
          // cashierName might be used in A5 too if we decide later, but currently plan focuses on Thermal
        );
      }

      await _printOrPreview(
        bytes,
        printerOverride,
        useCashBillSettings ? _keyCashBillPrinter : _keyCashPrinter,
        isPreview,
        'Receipt_$orderId',
        format: pageFormat,
      );
    } catch (e, stack) {
      debugPrint('❌ printReceipt Error: $e\n$stack');
    }
  }

  // --- 2. TAX INVOICE ---
  Future<void> printTaxInvoice({
    required int orderId,
    required List<OrderItem> items,
    required double total,
    required double grandTotal,
    required double vatRate,
    required Customer customer,
    Printer? printerOverride,
    bool isPreview = false,
  }) async {
    final pageFormat = PdfPageFormat.a4;
    final shopInfo = await _getShopInfo();

    final bytes = await TaxInvoicePdf.generate(
      orderId: orderId,
      items: items,
      total: total,
      grandTotal: grandTotal,
      vatRate: vatRate,
      customer: customer,
      pageFormat: pageFormat,
      shopInfo: shopInfo,
    );

    await _printOrPreview(bytes, printerOverride, _keyTaxPrinter, isPreview,
        'TaxInvoice_$orderId',
        format: pageFormat);
  }

  // --- 3. DELIVERY NOTE (ใบส่งของ) ---
  Future<void> printDeliveryNote({
    required int orderId,
    required List<OrderItem> items,
    required Customer customer,
    double discount = 0.0,
    Printer? printerOverride,
    PdfPageFormat? pageFormatOverride,
    bool isPreview = false,
  }) async {
    try {
      // ✅ ดึง Format ที่ถูกต้อง (ถ้า A5 จะได้ 9x5.5 นิ้ว)
      final pageFormat = pageFormatOverride ?? await _getDeliveryPageFormat();

      final bytes = await generateDeliveryNoteData(
        orderId: orderId,
        items: items,
        customer: customer,
        discount: discount,
        pageFormatOverride: pageFormat,
        showRuler: isPreview,
      );

      // ✅ ส่ง format และ usePrinterSettings: true ไปที่ฟังก์ชันพิมพ์
      await _printOrPreview(bytes, printerOverride, _keyDeliveryPrinter,
          isPreview, 'Delivery_$orderId',
          format: pageFormat);
    } catch (e, stack) {
      debugPrint('❌ printDeliveryNote Error: $e\n$stack');
    }
  }

  Future<Uint8List> generateDeliveryNoteData({
    required int orderId,
    required List<OrderItem> items,
    required Customer customer,
    double discount = 0.0,
    PdfPageFormat? pageFormatOverride,
    bool showRuler = false,
  }) async {
    final pageFormat = pageFormatOverride ?? await _getDeliveryPageFormat();
    final shopInfo = await _getShopInfo();
    return DeliveryNotePdf.generate(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: discount,
      pageFormat: pageFormat,
      shopInfo: shopInfo,
      showRuler: showRuler,
    );
  }

  // --- TEST METHODS (ใส่กลับมาให้ครบถ้วน) ---

  Future<Uint8List> testReceiptPreview(String paperSize) async {
    final format = paperSize == 'A4'
        ? PdfPageFormat.a4
        : (paperSize == 'A5' ? _customA5 : (await _getCashPageFormat()));

    final shopInfo = await _getShopInfo();
    final dummyItems = [
      OrderItem(
          productId: 1,
          productName: 'Test Item 1',
          price: Decimal.fromInt(100),
          quantity: Decimal.fromInt(2),
          total: Decimal.fromInt(200)),
    ];

    final bool isThermal =
        format.width < 270 || paperSize == '80mm' || paperSize == '58mm';

    if (isThermal) {
      return ThermalReceiptPdf.generate(
        orderId: 99999,
        items: dummyItems,
        total: 200,
        discount: 0,
        grandTotal: 200,
        received: 200,
        change: 0,
        pageFormat: format,
        shopInfo: shopInfo,
      );
    } else {
      final customer = Customer(
        id: 1,
        firstName: 'ลูกค้า',
        lastName: 'ทดสอบ',
        address: '99/99 หมู่ 1 ต.ทดสอบ อ.เมือง จ.กรุงเทพ 10000',
        shippingAddress:
            '88/88 หมู่ บ้านจัดสรร ต.ปลายทาง อ.เมือง จ.เชียงใหม่ 50000', // Added for testing A5 logic
        phone: '081-234-5678',
        memberCode: 'MEM001',
        currentPoints: 0,
      );

      return CashReceiptPdf.generate(
        orderId: 99999,
        items: dummyItems,
        customer: customer,
        discount: 0,
        pageFormat: format,
        shopInfo: shopInfo,
        showRuler: true, // ✅ Show Ruler for Preview
      );
    }
  }

  Future<void> testReceipt(
      Printer? printer, String paperSize, bool isPreview) async {
    final bytes = await testReceiptPreview(paperSize);
    final format = paperSize == 'A4'
        ? PdfPageFormat.a4
        : (paperSize == 'A5' ? _customA5 : (await _getCashPageFormat()));

    await _printOrPreview(
        bytes, printer, _keyCashPrinter, isPreview, 'Test_Receipt',
        format: format);
  }

  Future<void> testDeliveryNote(
      Printer? printer, String paperSize, bool isPreview) async {
    final bytes = await testDeliveryNotePreview(paperSize);
    final format = paperSize == 'A4' ? PdfPageFormat.a4 : _customA5;

    await _printOrPreview(
        bytes, printer, _keyDeliveryPrinter, isPreview, 'Test_Delivery_Note',
        format: format);
  }

  Future<Uint8List> testDeliveryNotePreview(String paperSize) async {
    final format = paperSize == 'A4' ? PdfPageFormat.a4 : _customA5;
    final shopInfo = await _getShopInfo();
    final dummyItems = List.generate(
        6,
        (index) => OrderItem(
            productId: index + 1,
            productName: 'สินค้าทดสอบ ${index + 1}',
            price: Decimal.fromInt(100),
            quantity: Decimal.one,
            total: Decimal.fromInt(100)));

    final customer = Customer(
        id: 1,
        firstName: 'ลูกค้า',
        lastName: 'ทดสอบ',
        address: '99/99 หมู่ 1 ต.ทดสอบ อ.เมือง จ.กรุงเทพ 10000',
        phone: '081-234-5678',
        memberCode: 'MEM001',
        currentPoints: 0);

    return DeliveryNotePdf.generate(
        orderId: 88888,
        items: dummyItems,
        customer: customer,
        discount: 0,
        pageFormat: format,
        shopInfo: shopInfo,
        showRuler: true);
  }

  Future<Uint8List> testTaxInvoicePreview() async {
    final format = PdfPageFormat.a4;
    final shopInfo = await _getShopInfo();
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

    return TaxInvoicePdf.generate(
      orderId: 77777,
      items: dummyItems,
      total: 300,
      grandTotal: 321,
      vatRate: 0.07,
      customer: customer,
      pageFormat: format,
      shopInfo: shopInfo,
    );
  }

  Future<void> testTaxInvoice(Printer? printer, bool isPreview) async {
    final bytes = await testTaxInvoicePreview();
    await _printOrPreview(
        bytes, printer, _keyTaxPrinter, isPreview, 'Test_Tax_Invoice',
        format: PdfPageFormat.a4);
  }

  Future<void> testA5Document(Printer? printer) async {
    try {
      final pdf = pw.Document();

      // Load Thai Font (ใช้ rootBundle เพื่อโหลดฟอนต์จริง)
      final fontData =
          await rootBundle.load('assets/fonts/sarabun/Sarabun-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final style = pw.TextStyle(font: ttf, fontSize: 14);
      final headerStyle =
          pw.TextStyle(font: ttf, fontSize: 18, fontWeight: pw.FontWeight.bold);

      pdf.addPage(
        pw.Page(
          pageFormat: _formatA5,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text('ทดสอบ A5 สำหรับ Epson LQ-310',
                        style: headerStyle),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('วันที่พิมพ์: ${DateTime.now().toString()}',
                      style: style),
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

      if (printer != null) {
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) async => pdf.save(),
          name: 'Test_A5_LQ310',
          format: _formatA5,
          usePrinterSettings: true, // Force Portrait
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name: 'Test_A5_LQ310',
          format: _formatA5,
        );
      }
    } catch (e) {
      debugPrint('Error testing A5 document: $e');
    }
  }

  // --- 4. BARCODE LABEL ---
  Future<void> printBarcode({
    required String barcode,
    required String name,
    required double price,
    Printer? printerOverride,
  }) async {
    final settings = LocalSettingsService();
    final sizeStr =
        await settings.getString(_keyBarcodePaperSize) ?? '40mmx30mm';
    final printer =
        printerOverride ?? await _getPrinterBySettingKey(_keyBarcodePrinter);

    if (sizeStr == '103mmx27mm') {
      await LabelPrinterService().smartPrintBarcode(
          type: LabelType.barcode406x108,
          barcode: barcode,
          name: name,
          price: price);
      return;
    }
    if (sizeStr == '32mmx25mm') {
      await LabelPrinterService().smartPrintBarcode(
          type: LabelType.barcode32x25,
          barcode: barcode,
          name: name,
          price: price);
      return;
    }

    double width = 4.0 * PdfPageFormat.cm;
    double height = 3.0 * PdfPageFormat.cm;
    if (sizeStr == '50mmx30mm') {
      width = 5.0 * PdfPageFormat.cm;
      height = 3.0 * PdfPageFormat.cm;
    }

    final format =
        PdfPageFormat(width, height, marginAll: 2 * PdfPageFormat.mm);
    final bytes = await BarcodeLabelPdf.generate(
      barcode: barcode,
      name: name,
      price: price,
      pageFormat: format,
    );

    if (printer != null) {
      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) async => bytes,
        name: 'Label_$barcode',
        format: format,
        usePrinterSettings: true,
      );
    } else {
      await Printing.layoutPdf(
          onLayout: (_) async => bytes, name: 'Label_$barcode', format: format);
    }
  }

  // --- 5. CASH DRAWER (Logic เต็ม) ---
  Future<void> openDrawer({bool isTest = false}) async {
    final settings = LocalSettingsService();
    final bool autoOpen =
        await settings.getBool('drawer_auto_open', defaultValue: false);

    if (!isTest && !autoOpen) return;

    final bool usePrinter =
        await settings.getBool('drawer_use_printer', defaultValue: true);
    final String command =
        await settings.getString('drawer_command') ?? '27,112,0,25,250';

    try {
      if (usePrinter) {
        final printer = await _getPrinterBySettingKey(_keyCashPrinter);
        if (printer != null) {
          if (Platform.isWindows) {
            try {
              List<int> bytes = command
                  .split(',')
                  .map((e) => int.tryParse(e.trim()) ?? 0)
                  .toList();
              final tempFile =
                  File('${Directory.systemTemp.path}\\drawer_kick.bin');
              await tempFile.writeAsBytes(bytes);
              await Process.run('cmd', [
                '/c',
                'copy',
                '/b',
                tempFile.path,
                '\\\\127.0.0.1\\${printer.name}'
              ]);
            } catch (e) {
              debugPrint('Kick drawer windows error: $e');
            }
          }

          // ส่งคำสั่งผ่าน Printer Driver (กรณีไม่ใช่ Windows หรือ fallback)
          final pdf = await ThermalReceiptPdf.generate(
              orderId: 0,
              items: [],
              total: 0,
              grandTotal: 0,
              received: 0,
              change: 0,
              discount: 0,
              customer: null,
              pageFormat: PdfPageFormat.roll80,
              shopInfo: await _getShopInfo());

          await Printing.directPrintPdf(
              printer: printer,
              onLayout: (_) async => pdf,
              name: 'DrawerKick',
              usePrinterSettings: true);
        }
      } else {
        // ต่อตรงผ่าน COM Port
        final String port = await settings.getString('drawer_port') ?? 'COM1';
        List<int> bytes =
            command.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
        final file = File('\\\\.\\$port');
        await file.writeAsBytes(bytes);
      }
    } catch (e) {
      debugPrint('⚠️ Error Opening Drawer: $e');
    }
  }

  Future<void> _printOrPreview(Uint8List bytes, Printer? printerOverride,
      String keyPrinter, bool isPreview, String docName,
      {PdfPageFormat format = PdfPageFormat.standard}) async {
    if (isPreview) {
      await Printing.sharePdf(bytes: bytes, filename: '$docName.pdf');
    } else {
      Printer? printer =
          printerOverride ?? await _getPrinterBySettingKey(keyPrinter);

      if (printer == null) {
        await Printing.layoutPdf(
            onLayout: (_) async => bytes, name: docName, format: format);
        return;
      }

      final String pName = printer.name.toLowerCase();
      bool isVirtual = pName.contains('pdf') ||
          pName.contains('writer') ||
          pName.contains('virtual') ||
          pName.contains('onenote');

      if (isVirtual) {
        await Printing.layoutPdf(
            onLayout: (_) async => bytes, name: docName, format: format);
      } else {
        try {
          // ✅ บังคับใช้ usePrinterSettings: true แก้ปัญหาหมุนแนวนอน
          await Printing.directPrintPdf(
            printer: printer,
            onLayout: (_) async => bytes,
            name: docName,
            format: format,
            usePrinterSettings: true, // 👈 KEY FIX
          );
        } catch (e) {
          debugPrint('❌ Direct print failed: $e. Falling back to dialog.');
          await Printing.layoutPdf(
              onLayout: (_) async => bytes, name: docName, format: format);
        }
      }
    }
  }
}
