import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

// Models
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/payment_record.dart';
import '../../models/label_config.dart';
import '../../models/shop_info.dart';
import '../../repositories/customer_repository.dart';

// Services & PDF Generators
import 'delivery_note_a5_pdf.dart';
import '../pdf/tax_invoice_a5_pdf.dart';
import '../pdf/thermal_receipt_pdf.dart';
import '../pdf/barcode_label_pdf.dart';
import 'cash_receipt_a4_pdf.dart';
import 'cash_receipt_pdf.dart';
import '../pdf/tax_invoice_a4_pdf.dart';
import 'delivery_note_a4_pdf.dart';
import 'shift_report_pdf.dart';
import '../../repositories/shift_repository.dart';

import 'label_printer_service.dart';
import '../shop_info_service.dart';
import '../local_settings_service.dart';
import '../../services/alert_service.dart';

class ReceiptService {
  // ... (Keys) ...

  Future<void> printPickingList(List<OrderItem> items) async {
    try {
      // Use Cash Printer
      final printer = await _getPrinterBySettingKey(_keyCashPrinter) ??
          await _getPrinterBySettingKey(_keyCashBillPrinter);

      if (printer == null) {
        debugPrint('⚠️ No printer found for Picking List.');
        return;
      }

      final pageFormat = await _getCashPageFormat();
      final now = DateTime.now();

      final pdf = pw.Document();
      // Load Font (Assuming Sarabun is available as checked in other methods)
      final fontData =
          await rootBundle.load('assets/fonts/sarabun/Sarabun-Regular.ttf');
      final ttf = pw.Font.ttf(fontData);
      final style =
          pw.TextStyle(font: ttf, fontSize: 18); // Larger text for reading
      final headerStyle =
          pw.TextStyle(font: ttf, fontSize: 22, fontWeight: pw.FontWeight.bold);

      pdf.addPage(pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                    child: pw.Text('ใบจัดเตรียมสินค้า (Picking List)',
                        style: headerStyle)),
                pw.Center(
                    child:
                        pw.Text('หน้าร้าน (Front Store)', style: headerStyle)),
                pw.Divider(),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          'วันที่: ${DateFormat('dd/MM/yyyy HH:mm', 'th').format(now)}',
                          style: style.copyWith(fontSize: 14)),
                      pw.Text('Items: ${items.length}',
                          style: style.copyWith(fontSize: 14)),
                    ]),
                pw.Divider(),
                pw.SizedBox(height: 5),
                ...items.map((item) {
                  return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item.productName,
                              style: style.copyWith(
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                    'จำนวน: ${NumberFormat('#,##0.##').format(item.quantity)}',
                                    style: style),
                                if (item.product?.shelfLocation != null &&
                                    item.product!.shelfLocation!.isNotEmpty)
                                  pw.Container(
                                      color: PdfColors.black,
                                      padding: const pw.EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: pw.Text(
                                          'Shelf: ${item.product!.shelfLocation}',
                                          style: style.copyWith(
                                              color: PdfColors.white)))
                              ]),
                          pw.Divider(
                              thickness: 0.5,
                              borderStyle: pw.BorderStyle.dashed),
                        ],
                      ));
                }),
                pw.SizedBox(height: 20),
                pw.Center(
                    child: pw.Text('___ จัดสินค้าเรียบร้อย ___',
                        style: style.copyWith(fontSize: 14))),
              ],
            );
          }));

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdf.save(),
        name: 'PickingList',
        format: pageFormat,
        usePrinterSettings: true,
      );
    } catch (e) {
      debugPrint('Error printing Picking List: $e');
      AlertService.show(message: 'พิมพ์ใบจัดของไม่สำเร็จ: $e', type: 'error');
    }
  }

  // คีย์สำหรับการตั้งค่าเครื่องพิมพ์ (ใช้สำหรับ Mapping)
  static const String _keyCashPrinter = 'printer_cash_name';
  static const String _keyCashBillPrinter = 'printer_cash_bill_name';
  static const String _keyTaxPrinter = 'printer_tax_name';
  static const String _keyDeliveryPrinter = 'printer_delivery_name';
  static const String _keyBarcodePrinter = 'printer_barcode_name';

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

    String? name;
    if (key == _keyCashPrinter) {
      name = await settings.getCashPrinterName();
    } else if (key == _keyCashBillPrinter) {
      name = await settings.getCashBillPrinterName();
    } else if (key == _keyTaxPrinter) {
      name = await settings.getTaxPrinterName();
    } else if (key == _keyDeliveryPrinter) {
      name = await settings.getDeliveryPrinterName();
    } else if (key == _keyBarcodePrinter) {
      name = await settings.getBarcodePrinterName();
    } else {
      name = await settings.getString(key);
    }

    if (name == null || name.isEmpty) return null;

    // ✅ Simplified Logic: Just use the saved name directly.
    // This avoids the slow `Printing.listPrinters()` call entirely.
    return Printer(url: name, name: name);
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
    final size = await settings.getDeliveryPaperSize();

    if (size == 'A4') return PdfPageFormat.a4;
    if (size == 'A5') return PdfPageFormat.a5; // Standard A5 (Laser)
    if (size == 'Continuous') return _customA5; // 9x5.5" (Dot-Matrix)

    // Default/Fallback
    return _customA5;
  }

  Future<PdfPageFormat> _getCashPageFormat() async {
    final settings = LocalSettingsService();
    final size = await settings.getCashPaperSize();

    if (size == 'A4') return PdfPageFormat.a4;
    if (size == 'A5') return PdfPageFormat.a5; // Standard A5 (Laser)
    if (size == 'Continuous') return _customA5; // 9x5.5" (Dot-Matrix)

    if (size == '58mm') {
      return PdfPageFormat(
        57 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 2 * PdfPageFormat.mm,
      );
    }

    if (size == '80mm') {
      return PdfPageFormat(
        72 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 1 * PdfPageFormat.mm,
      );
    }

    return PdfPageFormat(
      72 * PdfPageFormat.mm, // Default to 72mm instead of 71mm to prevent cutoff/rejection
      double.infinity,
      marginAll: 1 * PdfPageFormat.mm,
    );
  }

  Future<PdfPageFormat> _getCashBillPageFormat() async {
    final settings = LocalSettingsService();
    final size = await settings.getCashBillPaperSize();
    return size == 'A4' ? PdfPageFormat.a4 : _customA5;
  }

// ... overrides ...

  // ✅ Helper: Refresh Customer Data to ensure Address is present
  Future<Customer?> _refreshCustomer(Customer? customer) async {
    if (customer == null || customer.id <= 0) return customer;
    try {
      // Create Repo instance (MySQLService is singleton)
      final repo = CustomerRepository();
      // ✅ Add Timeout to prevent hanging if DB locked
      final fetched = await repo
          .getCustomerById(customer.id)
          .timeout(const Duration(seconds: 2));

      if (fetched != null) {
        // debugPrint('🔄 [ReceiptService] Refreshed customer data for ID: ${customer.id}');
        return fetched;
      }
    } catch (e) {
      debugPrint(
          '⚠️ [ReceiptService] Failed to refresh customer (Timeout/Error): $e');
    }
    return customer;
  }

  // --- 1. ใบเสร็จ / ใบเสร็จความร้อน ---
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
    String? cashierName,
    String? remark,
  }) async {
    try {
      // ✅ Refresh Customer
      final validCustomer = await _refreshCustomer(customer);

      final pageFormat = pageFormatOverride ??
          (useCashBillSettings
              ? await _getCashBillPageFormat()
              : await _getCashPageFormat());

      final shopInfo = await _getShopInfo();
      final isThermal = pageFormat.width < 270;

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
          customer: validCustomer, // ✅ Use refreshed
          pageFormat: pageFormat,
          shopInfo: shopInfo,
          cashierName: cashierName,
        );
      } else {
        if (pageFormat == PdfPageFormat.a4) {
          bytes = await CashReceiptA4Pdf.generate(
            orderId: orderId,
            items: items,
            customer: validCustomer,
            discount: discount,
            shopInfo: shopInfo,
            remark: remark,
          );
        } else if (pageFormat == PdfPageFormat.a5 ||
            pageFormat.width < 160 * PdfPageFormat.mm) {
          // ✅ Standard Laser A5 ( modular generator)
          bytes = await CashReceiptA5Pdf.generate(
            orderId: orderId,
            items: items,
            customer: validCustomer,
            discount: discount,
            shopInfo: shopInfo,
            remark: remark,
          );
        } else {
          // ✅ Dot matrix / Continuous — ใช้ layout เดียวกับใบส่งของ
          bytes = await CashReceiptA5Pdf.generate(
            orderId: orderId,
            items: items,
            customer: validCustomer,
            discount: discount,
            shopInfo: shopInfo,
            remark: remark,
          );
        }
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
      AlertService.show(
          message: 'พิมพ์ใบเสร็จไม่สำเร็จ: ${e.toString()}', type: 'error');
    }
  }

  // ✅ New Method: Capture Receipt as Image
  Future<Uint8List?> captureReceiptImage({
    required int orderId,
    required List<OrderItem> items,
    required double total,
    required double grandTotal,
    required double received,
    required double change,
    List<PaymentRecord>? payments,
    Customer? customer,
    String? cashierName,
  }) async {
    try {
      // ✅ Refresh Customer
      final validCustomer = await _refreshCustomer(customer);

      final pageFormat = await _getCashPageFormat();
      final shopInfo = await _getShopInfo();

      final bytes = await ThermalReceiptPdf.generate(
        orderId: orderId,
        items: items,
        total: total,
        discount: 0,
        grandTotal: grandTotal,
        received: received,
        change: change,
        payments: payments,
        customer: validCustomer, // ✅ Use refreshed
        pageFormat: pageFormat,
        shopInfo: shopInfo,
        cashierName: cashierName,
      );

      // 💡 ลด DPI ลงเหลือ 120 สำหรับสลิป (เล็กที่สุดที่ยังอ่านชัดบนจอ)
      await for (final page in Printing.raster(bytes, pages: [0], dpi: 120)) {
        return await page.toPng();
      }
      return null;
    } catch (e) {
      debugPrint('❌ captureReceiptImage Error: $e');
      return null;
    }
  }

  // ✅ New Method: Capture Delivery Note as Image (For Line OA)
  Future<Uint8List?> captureDeliveryNoteImage({
    required int orderId,
    required List<OrderItem> items,
    required Customer customer,
    double discount = 0.0,
    double vatAmount = 0.0,
    double? grandTotalOverride,
    String? remark,
  }) async {
    try {
      final validCustomer = await _refreshCustomer(customer) ?? customer;
      final pageFormat =
          _customA5; // ใช้ฟอร์แมตกระดาษแนวนอนแบบ Continuous (Legacy - อันบน)

      final bytes = await generateDeliveryNoteData(
        orderId: orderId,
        items: items,
        customer: validCustomer,
        discount: discount,
        vatAmount: vatAmount,
        grandTotalOverride: grandTotalOverride,
        pageFormatOverride: pageFormat,
        showRuler: false,
        remark: remark,
      );

      // 💡 ลด DPI ลงเหลือ 100 เพื่อให้ได้ไฟล์ภาพขนาดเล็ก (ตามที่ผู้ใช้รีเควส)
      await for (final page in Printing.raster(bytes, pages: [0], dpi: 100)) {
        return await page.toPng();
      }
      return null;
    } catch (e) {
      debugPrint('❌ captureDeliveryNoteImage Error: $e');
      return null;
    }
  }

  // ✅ เมนูใหม่สำหรับปริ้นใบเสร็จชำระหนี้ (เวอร์ชัน 1.1 ใหม่)
  Future<void> printDebtPayment({
    required int transactionId,
    required Customer customer,
    required double amount,
    required DateTime date,
    String? paperSizeOverride,
  }) async {
    final settings = LocalSettingsService();
    Printer? printer = await _getPrinterBySettingKey(_keyCashPrinter) ??
        await _getPrinterBySettingKey(_keyCashBillPrinter);

    String paperSize = paperSizeOverride ?? await settings.getCashPaperSize();

    if (printer == null) {
      debugPrint(
          '⚠️ ไม่พบการตั้งค่าเครื่องพิมพ์สำหรับการชำระหนี้ ข้ามการพิมพ์');
      return;
    }

    // ✅ Refresh Customer
    final validCustomer = (await _refreshCustomer(customer))!;

    final PdfPageFormat format = await _getCashPageFormat();
    final shopInfo = await _getShopInfo();
    final bool isThermal =
        format.width < 270 || paperSize == '80mm' || paperSize == '58mm';

    final dummyItem = OrderItem(
      productId: 0,
      productName: 'ชำระหนี้ (Debt Payment)',
      price: Decimal.parse(amount.toString()),
      quantity: Decimal.one,
      total: Decimal.parse(amount.toString()),
    );

    Uint8List bytes;
    if (isThermal) {
      bytes = await ThermalReceiptPdf.generate(
        orderId: transactionId,
        items: [dummyItem],
        total: amount,
        discount: 0,
        grandTotal: amount,
        received: amount,
        change: 0,
        pageFormat: format,
        shopInfo: shopInfo,
        cashierName: 'Admin',
      );
    } else {
      if (format == PdfPageFormat.a4) {
        bytes = await CashReceiptA4Pdf.generate(
          orderId: transactionId,
          items: [dummyItem],
          customer: validCustomer,
          discount: 0,
          shopInfo: shopInfo,
        );
      } else if (format == PdfPageFormat.a5) {
        bytes = await CashReceiptA5Pdf.generate(
          orderId: transactionId,
          items: [dummyItem],
          customer: validCustomer,
          discount: 0,
          shopInfo: shopInfo,
        );
      } else {
        // ✅ Continuous — ใช้ layout เดียวกับใบส่งของ
        bytes = await CashReceiptA5Pdf.generate(
          orderId: transactionId,
          items: [dummyItem],
          customer: validCustomer,
          discount: 0,
          shopInfo: shopInfo,
        );
      }
    }

    await _printOrPreview(
        bytes, printer, _keyCashPrinter, false, 'DebtReceipt_$transactionId',
        format: format);
  }

  // ✅ เมนูใหม่สำหรับปริ้นบิล (เวอร์ชัน 1.1 ใหม่)
  Future<void> printBill({
    required int orderId,
    required List<OrderItem> items,
    required Customer? customer,
    required double discount,
    required double grandTotal,
    required double received,
    required double change,
    required String paymentMethod,
    bool isReprint = false,
  }) async {
    final settings = LocalSettingsService();
    Printer? printer = await _getPrinterBySettingKey(_keyCashBillPrinter) ??
        await _getPrinterBySettingKey(_keyCashPrinter);
    String paperSize = await settings.getCashBillPaperSize();

    if (printer == null) {
      debugPrint('⚠️ ไม่พบการตั้งค่าเครื่องพิมพ์บิล ข้ามการพิมพ์');
      return;
    }

    // ✅ Refresh Customer
    final validCustomer = await _refreshCustomer(customer);

    final PdfPageFormat format = await _getCashPageFormat();
    final shopInfo = await _getShopInfo();

    final bool isThermal =
        format.width < 270 || paperSize == '80mm' || paperSize == '58mm';

    Uint8List bytes;
    if (isThermal) {
      bytes = await ThermalReceiptPdf.generate(
        orderId: orderId,
        items: items,
        total: grandTotal,
        discount: discount,
        grandTotal: grandTotal,
        received: received,
        change: change,
        pageFormat: format,
        shopInfo: shopInfo,
        cashierName: 'Admin',
      );
    } else {
      if (format == PdfPageFormat.a4) {
        bytes = await CashReceiptA4Pdf.generate(
          orderId: orderId,
          items: items,
          customer: validCustomer,
          discount: discount,
          shopInfo: shopInfo,
        );
      } else if (format == PdfPageFormat.a5) {
        bytes = await CashReceiptA5Pdf.generate(
          orderId: orderId,
          items: items,
          customer: validCustomer,
          discount: discount,
          shopInfo: shopInfo,
        );
      } else {
        // ✅ Continuous — ใช้ layout เดียวกับใบส่งของ
        bytes = await CashReceiptA5Pdf.generate(
          orderId: orderId,
          items: items,
          customer: validCustomer,
          discount: discount,
          shopInfo: shopInfo,
        );
      }
    }
    await _printOrPreview(
        bytes, printer, _keyCashBillPrinter, false, 'Bill_$orderId',
        format: format);
  }

  // --- 2. ใบกำกับภาษี ---
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

    // ✅ Refresh Customer
    final validCustomer = (await _refreshCustomer(customer))!;

    Uint8List bytes;
    if (pageFormat == PdfPageFormat.a4) {
      bytes = await TaxInvoiceA4Pdf.generate(
        orderId: orderId,
        items: items,
        total: total,
        grandTotal: grandTotal,
        vatRate: vatRate,
        customer: validCustomer,
        shopInfo: shopInfo,
      );
    } else {
      bytes = await TaxInvoiceA5Pdf.generate(
        orderId: orderId,
        items: items,
        total: total,
        grandTotal: grandTotal,
        vatRate: vatRate,
        customer: validCustomer,
        shopInfo: shopInfo,
      );
    }

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
    String? remark,
  }) async {
    try {
      // ✅ Refresh Customer
      final validCustomer = (await _refreshCustomer(customer))!;

      final pageFormat = pageFormatOverride ?? await _getDeliveryPageFormat();

      final bytes = await generateDeliveryNoteData(
        orderId: orderId,
        items: items,
        customer: validCustomer, // ✅ Use refreshed
        discount: discount,
        pageFormatOverride: pageFormat,
        showRuler: isPreview,
        remark: remark,
      );

      await _printOrPreview(bytes, printerOverride, _keyDeliveryPrinter,
          isPreview, 'Delivery_$orderId',
          format: pageFormat);
    } catch (e, stack) {
      debugPrint('❌ printDeliveryNote Error: $e\n$stack');
      AlertService.show(
          message: 'พิมพ์ใบส่งของไม่สำเร็จ: ${e.toString()}', type: 'error');
    }
  }

  Future<Uint8List> generateDeliveryNoteData({
    required int orderId,
    required List<OrderItem> items,
    required Customer customer,
    double discount = 0.0,
    double vatAmount = 0.0,
    double? grandTotalOverride,
    PdfPageFormat? pageFormatOverride,
    bool showRuler = false,
    String? remark,
  }) async {
    final pageFormat = pageFormatOverride ?? await _getDeliveryPageFormat();
    final shopInfo = await _getShopInfo();

    if (pageFormat == PdfPageFormat.a4) {
      return DeliveryNoteA4Pdf.generate(
        orderId: orderId,
        items: items,
        customer: customer,
        discount: discount,
        vatAmount: vatAmount,
        grandTotalOverride: grandTotalOverride,
        shopInfo: shopInfo,
        showRuler: showRuler,
        remark: remark,
      );
    } else {
      // ✅ ใช้ DeliveryNoteA5Pdf สำหรับทั้ง A5 และกระดาษต่อเนื่อง (เพราะเราแก้ให้รับ pageFormat ได้แล้ว)
      // ✅ ใช้ DeliveryNoteA5Pdf สำหรับทั้ง A5 และกระดาษต่อเนื่อง
      // ถ้าเป็น Continuous (กว้าง > 200mm) ให้ส่ง null เพื่อใช้ค่า Default ใน Class ที่ตั้งค่าขอบไว้แล้ว
      final isContinuous = pageFormat.width > 200 * PdfPageFormat.mm;
      return DeliveryNoteA5Pdf.generate(
        orderId: orderId,
        items: items,
        customer: customer,
        discount: discount,
        vatAmount: vatAmount,
        grandTotalOverride: grandTotalOverride,
        shopInfo: shopInfo,
        remark: remark,
        pageFormat: isContinuous
            ? null
            : pageFormat, // ถ้าต่อเนื่อง ให้ใช้ Default ของ Class
      );
    }
  }

  Future<Uint8List> testReceiptPreview(String paperSize) async {
    PdfPageFormat format;
    if (paperSize == 'A4') {
      format = PdfPageFormat.a4;
    } else if (paperSize == 'A5') {
      format = PdfPageFormat.a5;
    } else if (paperSize == 'Continuous') {
      format = _customA5;
    } else if (paperSize == '58mm') {
      format = PdfPageFormat(
        57 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 2 * PdfPageFormat.mm,
      );
    } else if (paperSize == '80mm') {
      format = PdfPageFormat(
        71 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 0,
        marginTop: 2 * PdfPageFormat.mm,
        marginBottom: 2 * PdfPageFormat.mm,
      );
    } else {
      format = await _getCashPageFormat();
    }

    final shopInfo = await _getShopInfo();
    final dummyItems = [
      OrderItem(
          productId: 1,
          productName: 'สินค้าทดสอบ 1',
          price: Decimal.fromInt(100),
          quantity: Decimal.fromInt(2),
          total: Decimal.fromInt(200)),
    ];

    final bool isThermal = format.width < 270;

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
        phone: '081-234-5678',
        memberCode: 'MEM001',
        currentPoints: 0,
      );

      if (format == PdfPageFormat.a4) {
        return CashReceiptA4Pdf.generate(
          orderId: 99999,
          items: dummyItems,
          customer: customer,
          discount: 0,
          shopInfo: shopInfo,
          showRuler: true,
        );
      } else if (format == PdfPageFormat.a5) {
        return CashReceiptA5Pdf.generate(
          orderId: 99999,
          items: dummyItems,
          customer: customer,
          discount: 0,
          shopInfo: shopInfo,
          showRuler: true,
        );
      } else {
        return CashReceiptPdf.generate(
          orderId: 99999,
          items: dummyItems,
          customer: customer,
          discount: 0,
          shopInfo: shopInfo,
          pageFormat: format,
          showRuler: true,
        );
      }
    }
  }

  Future<void> testReceipt(
      Printer? printer, String paperSize, bool isPreview) async {
    final bytes = await testReceiptPreview(paperSize);
    PdfPageFormat format;
    if (paperSize == 'A4') {
      format = PdfPageFormat.a4;
    } else if (paperSize == 'A5') {
      format = PdfPageFormat.a5;
    } else if (paperSize == 'Continuous') {
      format = _customA5;
    } else if (paperSize == '58mm') {
      format = PdfPageFormat(
        57 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 2 * PdfPageFormat.mm,
      );
    } else if (paperSize == '80mm') {
      format = PdfPageFormat(
        72 * PdfPageFormat.mm,
        double.infinity,
        marginAll: 1 * PdfPageFormat.mm,
      );
    } else {
      format = await _getCashPageFormat();
    }

    await _printOrPreview(
        bytes, printer, _keyCashPrinter, isPreview, 'Test_Receipt',
        format: format);
  }

  Future<void> testDeliveryNote(
      Printer? printer, String paperSize, bool isPreview) async {
    final bytes = await testDeliveryNotePreview(paperSize);
    final format = paperSize == 'A4'
        ? PdfPageFormat.a4
        : (paperSize == 'A5' ? PdfPageFormat.a5 : _customA5);

    await _printOrPreview(
        bytes, printer, _keyDeliveryPrinter, isPreview, 'Test_Delivery_Note',
        format: format);
  }

  Future<Uint8List> testDeliveryNotePreview(String paperSize) async {
    final format = paperSize == 'A4'
        ? PdfPageFormat.a4
        : (paperSize == 'A5' ? PdfPageFormat.a5 : _customA5);
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
        address:
            '99/99 หมู่ 1 ต.ทดสอบ อ.เมือง จ.กรุงเทพ 10000 (ที่อยู่เปิดบิล)',
        shippingAddress:
            '88/88 หมู่ บ้านจัดสรร ต.ปลายทาง อ.เมือง จ.เชียงใหม่ 50000 (ที่อยู่ส่งของ)',
        phone: '081-234-5678',
        memberCode: 'MEM001',
        currentPoints: 0);

    if (format == PdfPageFormat.a4) {
      return DeliveryNoteA4Pdf.generate(
          orderId: 88888,
          items: dummyItems,
          customer: customer,
          discount: 0,
          shopInfo: shopInfo,
          showRuler: true);
    } else if (format == PdfPageFormat.a5) {
      return DeliveryNoteA5Pdf.generate(
          orderId: 88888,
          items: dummyItems,
          customer: customer,
          discount: 0,
          shopInfo: shopInfo,
          showRuler: true);
    } else {
      // ✅ แก้ไข: ใช้ DeliveryNoteA5Pdf สำหรับกระดาษต่อเนื่อง (Continuous) ให้เหมือนกับตอนพิมพ์จริง
      // ถ้าเป็น Continuous ให้ส่ง null เพื่อใช้ Default Format ใน Class
      final isContinuous = format.width > 200 * PdfPageFormat.mm;
      return DeliveryNoteA5Pdf.generate(
          orderId: 88888,
          items: dummyItems,
          customer: customer,
          discount: 0,
          shopInfo: shopInfo,
          pageFormat: isContinuous ? null : format,
          showRuler: true);
    }
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

    if (format == PdfPageFormat.a4) {
      return TaxInvoiceA4Pdf.generate(
        orderId: 77777,
        items: dummyItems,
        total: 300,
        grandTotal: 321,
        vatRate: 0.07,
        customer: customer,
        shopInfo: shopInfo,
      );
    } else {
      return TaxInvoiceA5Pdf.generate(
        orderId: 77777,
        items: dummyItems,
        total: 300,
        grandTotal: 321,
        vatRate: 0.07,
        customer: customer,
        shopInfo: shopInfo,
      );
    }
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
    final sizeStr = await settings.getBarcodePaperSize();
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
    
    bool autoOpen = await settings.getDrawerAutoOpen();
    if (!isTest && !autoOpen) return;

    bool usePrinter = await settings.getDrawerUsePrinter();
    final String command = await settings.getDrawerCommand();

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
        // ต่อตรงผ่าน COM Port หรือ IP
        final String port = await settings.getDrawerPort();
        List<int> bytes =
            command.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
        
        if (port.contains('.')) {
          // IP Address Printer
          String ip = port.trim();
          int p = 9100;
          if (ip.contains(':')) {
            final parts = ip.split(':');
            ip = parts[0];
            p = int.tryParse(parts[1]) ?? 9100;
          }
          final socket = await Socket.connect(ip, p, timeout: const Duration(seconds: 3));
          socket.add(bytes);
          await socket.flush();
          await socket.close();
        } else if (port.startsWith(r'\\') || port.startsWith('//')) {
          // Network Shared Printer Path (UNC)
          try {
             final logFile = File('C:\\pos_desktop\\drawer_log.txt');
             await logFile.writeAsString('[${DateTime.now()}] UNC Path sending to $port...\n', mode: FileMode.append);
          } catch (_) {}

          try {
             final tempFile = File('${Directory.systemTemp.path}\\drawer_kick.bin');
             await tempFile.writeAsBytes(bytes);
             final result = await Process.run('cmd', ['/c', 'copy', '/b', tempFile.path, port]);
             try {
                final logFile = File('C:\\pos_desktop\\drawer_log.txt');
                await logFile.writeAsString('[${DateTime.now()}] UNC SUCCESS exitCode: ${result.exitCode}\n', mode: FileMode.append);
             } catch (_) {}
          } catch (e) {
             debugPrint('UNC ERROR: $e');
             try {
                final logFile = File('C:\\pos_desktop\\drawer_log.txt');
                await logFile.writeAsString('[${DateTime.now()}] ERROR (UNC): $e\n', mode: FileMode.append);
             } catch (_) {}
          }
        } else {
          // COM Port
          try {
             final file = File('\\\\.\\$port');
             await file.writeAsBytes(bytes);
          } catch (e) {
             debugPrint('COM ERROR: $e');
          }
        }
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

  // --- 5. พิมพ์สรุปปิดกะ (Shift Closing) ---
  Future<void> printShiftClosingSlip({
    required ShiftSummary shift,
    required String paperSize,
    Printer? printerOverride,
    bool isPreview = false,
  }) async {
    try {
      final shopInfo = await _getShopInfo();
      Uint8List bytes;
      PdfPageFormat format;
      String targetPrinterKey = _keyCashPrinter;

      if (paperSize == 'A4' || paperSize == 'SAVE_PDF') {
        format = PdfPageFormat.a4;
        bytes = await ShiftReportPdf.generateFull(shift: shift, shopInfo: shopInfo);
      } else {
        // Thermal or A5 (Shortened version)
        if (paperSize == 'A5') {
          format = PdfPageFormat.a5;
        } else if (paperSize == '80mm') {
          format = PdfPageFormat(
            72 * PdfPageFormat.mm,
            double.infinity,
            marginAll: 1 * PdfPageFormat.mm,
          );
        } else {
          format = await _getCashPageFormat();
        }
        bytes = await ShiftReportPdf.generateShort(shift: shift, shopInfo: shopInfo, pageFormat: format);
      }

      if (paperSize == 'SAVE_PDF' || isPreview) {
        // Force preview to allow Save As PDF
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'Shift_Summary_${DateFormat('yyyyMMdd_HHmm').format(shift.closedAt)}',
        );
      } else {
        Printer? printer = printerOverride ?? await _getPrinterBySettingKey(targetPrinterKey);
        await _printOrPreview(bytes, printer, targetPrinterKey, false, 'Shift_Summary', format: format);
      }
    } catch (e, stack) {
      debugPrint('❌ printShiftClosingSlip Error: $e\n$stack');
      AlertService.show(message: 'พิมพ์สรุปกะไม่สำเร็จ: ${e.toString()}', type: 'error');
    }
  }
}
