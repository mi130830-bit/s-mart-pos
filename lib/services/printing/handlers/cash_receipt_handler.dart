import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:decimal/decimal.dart';

import '../../../models/order_item.dart';
import '../../../models/customer.dart';
import '../../../models/payment_record.dart';
import '../../alert_service.dart';

import '../core/print_core_service.dart';
import '../utils/print_settings_helper.dart';
import '../utils/print_data_helper.dart';

import '../../pdf/thermal_receipt_pdf.dart';
import '../delivery_note_pdf.dart';

class CashReceiptHandler {
  static Future<void> printReceipt({
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
      final validCustomer = await PrintDataHelper.refreshCustomer(customer);
      final pageFormat = pageFormatOverride ??
          (useCashBillSettings
              ? await PrintSettingsHelper.getCashBillPageFormat()
              : await PrintSettingsHelper.getCashPageFormat());

      final shopInfo = await PrintDataHelper.getShopInfo();
      final shopLogoBytes = await PrintDataHelper.getShopLogoBytes();
      final printer = printerOverride ??
          await PrintSettingsHelper.getPrinterBySettingKey(
              useCashBillSettings ? PrintSettingsHelper.keyCashBillPrinter : PrintSettingsHelper.keyCashPrinter);
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
          customer: validCustomer,
          pageFormat: pageFormat,
          shopInfo: shopInfo,
          cashierName: cashierName,
          shopLogoBytes: shopLogoBytes,
        );
      } else {
        final isContinuous = pageFormat.width > 200 * PdfPageFormat.mm;
        final finalPageFormat = isContinuous
            ? PdfPageFormat(
                9.0 * PdfPageFormat.inch,
                5.5 * PdfPageFormat.inch,
                marginLeft: 0.5 * PdfPageFormat.cm,
                marginRight: 2.50 * PdfPageFormat.cm,
                marginTop: 0.8 * PdfPageFormat.cm,
                marginBottom: 0.8 * PdfPageFormat.cm,
              )
            : pageFormat;

        final isA4 = pageFormat == PdfPageFormat.a4;
        bytes = await DeliveryNotePdf.generate(
          orderId: orderId,
          items: items,
          customer: validCustomer,
          discount: discount,
          shopInfo: shopInfo,
          remark: remark,
          pageFormat: finalPageFormat,
          documentTitleTh: isA4 ? 'บิลเงินสด' : 'ใบเสร็จรับเงิน',
          documentTitleEn: isA4 ? 'บิลเงินสด' : 'ใบเสร็จรับเงิน',
          signatureLabel: 'ผู้รับเงิน',
          useShippingAddress: false,
          shopLogoBytes: shopLogoBytes,
        );

        await PrintCoreService.printDocument(
          bytes: bytes,
          docName: 'Receipt_$orderId',
          format: finalPageFormat,
          printer: printer,
          isPreview: isPreview,
        );
        return;
      }

      await PrintCoreService.printDocument(
        bytes: bytes,
        docName: 'Receipt_$orderId',
        format: pageFormat,
        printer: printer,
        isPreview: isPreview,
      );
    } catch (e, stack) {
      debugPrint('❌ printReceipt Error: $e\n$stack');
      AlertService.show(message: 'พิมพ์ใบเสร็จไม่สำเร็จ: ${e.toString()}', type: 'error');
    }
  }

  static Future<Uint8List?> captureReceiptImage({
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
      final validCustomer = await PrintDataHelper.refreshCustomer(customer);
      final pageFormat = await PrintSettingsHelper.getCashPageFormat();
      final shopInfo = await PrintDataHelper.getShopInfo();

      final bytes = await ThermalReceiptPdf.generate(
        orderId: orderId,
        items: items,
        total: total,
        discount: 0,
        grandTotal: grandTotal,
        received: received,
        change: change,
        payments: payments,
        customer: validCustomer,
        pageFormat: pageFormat,
        shopInfo: shopInfo,
        cashierName: cashierName,
      );

      await for (final page in Printing.raster(bytes, pages: [0], dpi: 120)) {
        return await page.toPng();
      }
      return null;
    } catch (e) {
      debugPrint('❌ captureReceiptImage Error: $e');
      return null;
    }
  }

  static Future<void> printDebtPayment({
    required int transactionId,
    required Customer customer,
    required double amount,
    required DateTime date,
    String? paperSizeOverride,
  }) async {
    try {
      Printer? printer = await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyCashPrinter) ??
          await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyCashBillPrinter);

      if (printer == null) {
        debugPrint('⚠️ ไม่พบการตั้งค่าเครื่องพิมพ์สำหรับการชำระหนี้ ข้ามการพิมพ์');
        return;
      }

      final validCustomer = await PrintDataHelper.refreshCustomer(customer);
      final PdfPageFormat format = await PrintSettingsHelper.getCashPageFormat();
      final shopInfo = await PrintDataHelper.getShopInfo();
      final shopLogoBytes = await PrintDataHelper.getShopLogoBytes();
      final bool isThermal = format.width < 270;

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
          shopLogoBytes: shopLogoBytes,
        );
      } else {
        final isContinuous = format.width > 200 * PdfPageFormat.mm;
        final finalPageFormat = isContinuous
            ? PdfPageFormat(
                9.0 * PdfPageFormat.inch,
                5.5 * PdfPageFormat.inch,
                marginLeft: 0.5 * PdfPageFormat.cm,
                marginRight: 2.50 * PdfPageFormat.cm,
                marginTop: 0.8 * PdfPageFormat.cm,
                marginBottom: 0.8 * PdfPageFormat.cm,
              )
            : format;

        final isA4 = format == PdfPageFormat.a4;
        bytes = await DeliveryNotePdf.generate(
          orderId: transactionId,
          items: [dummyItem],
          customer: validCustomer,
          discount: 0,
          shopInfo: shopInfo,
          pageFormat: finalPageFormat,
          documentTitleTh: isA4 ? 'บิลเงินสด' : 'ใบเสร็จรับเงิน',
          documentTitleEn: isA4 ? 'บิลเงินสด' : 'ใบเสร็จรับเงิน',
          signatureLabel: 'ผู้รับเงิน',
          useShippingAddress: false,
          shopLogoBytes: shopLogoBytes,
        );

        await PrintCoreService.printDocument(
          bytes: bytes,
          docName: 'DebtReceipt_$transactionId',
          format: finalPageFormat,
          printer: printer,
          isPreview: false,
        );
        return;
      }

      await PrintCoreService.printDocument(
        bytes: bytes,
        docName: 'DebtReceipt_$transactionId',
        format: format,
        printer: printer,
        isPreview: false,
      );
    } catch (e) {
      debugPrint('❌ printDebtPayment Error: $e');
    }
  }

  static Future<void> printBill({
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
    try {
      Printer? printer = await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyCashBillPrinter) ??
          await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyCashPrinter);

      if (printer == null) {
        debugPrint('⚠️ ไม่พบการตั้งค่าเครื่องพิมพ์บิล ข้ามการพิมพ์');
        return;
      }

      final validCustomer = await PrintDataHelper.refreshCustomer(customer);
      final PdfPageFormat format = await PrintSettingsHelper.getCashPageFormat();
      final shopInfo = await PrintDataHelper.getShopInfo();
      final shopLogoBytes = await PrintDataHelper.getShopLogoBytes();
      final bool isThermal = format.width < 270;

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
          shopLogoBytes: shopLogoBytes,
        );
      } else {
        final isContinuous = format.width > 200 * PdfPageFormat.mm;
        final finalPageFormat = isContinuous
            ? PdfPageFormat(
                9.0 * PdfPageFormat.inch,
                5.5 * PdfPageFormat.inch,
                marginLeft: 0.5 * PdfPageFormat.cm,
                marginRight: 2.50 * PdfPageFormat.cm,
                marginTop: 0.8 * PdfPageFormat.cm,
                marginBottom: 0.8 * PdfPageFormat.cm,
              )
            : format;

        final isA4 = format == PdfPageFormat.a4;
        bytes = await DeliveryNotePdf.generate(
          orderId: orderId,
          items: items,
          customer: validCustomer,
          discount: discount,
          shopInfo: shopInfo,
          pageFormat: finalPageFormat,
          documentTitleTh: isA4 ? 'บิลเงินสด' : 'ใบเสร็จรับเงิน',
          documentTitleEn: isA4 ? 'บิลเงินสด' : 'ใบเสร็จรับเงิน',
          signatureLabel: 'ผู้รับเงิน',
          useShippingAddress: false,
          shopLogoBytes: shopLogoBytes,
        );

        await PrintCoreService.printDocument(
          bytes: bytes,
          docName: 'Bill_$orderId',
          format: finalPageFormat,
          printer: printer,
          isPreview: false,
        );
        return;
      }

      await PrintCoreService.printDocument(
        bytes: bytes,
        docName: 'Bill_$orderId',
        format: format,
        printer: printer,
        isPreview: false,
      );
    } catch (e) {
      debugPrint('❌ printBill Error: $e');
    }
  }

  static Future<Uint8List> testReceiptPreview(String paperSize) async {
    PdfPageFormat format;
    if (paperSize == 'A4') {
      format = PdfPageFormat.a4;
    } else if (paperSize == 'A5') {
      format = PdfPageFormat.a5;
    } else if (paperSize == 'Continuous') {
      format = PrintSettingsHelper.customA5;
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
      format = await PrintSettingsHelper.getCashPageFormat();
    }

    final shopInfo = await PrintDataHelper.getShopInfo();
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

      final isContinuous = format.width > 200 * PdfPageFormat.mm;
      final finalPageFormat = isContinuous
          ? PdfPageFormat(
              9.0 * PdfPageFormat.inch,
              5.5 * PdfPageFormat.inch,
              marginLeft: 0.5 * PdfPageFormat.cm,
              marginRight: 2.50 * PdfPageFormat.cm,
              marginTop: 0.8 * PdfPageFormat.cm,
              marginBottom: 0.8 * PdfPageFormat.cm,
            )
          : format;

      final isA4 = format == PdfPageFormat.a4;
      final shopLogoBytes = await PrintDataHelper.getShopLogoBytes();
      return DeliveryNotePdf.generate(
        orderId: 99999,
        items: dummyItems,
        customer: customer,
        discount: 0,
        shopInfo: shopInfo,
        pageFormat: finalPageFormat,
        showRuler: true,
        documentTitleTh: isA4 ? 'บิลเงินสด' : 'ใบเสร็จรับเงิน',
        documentTitleEn: isA4 ? 'บิลเงินสด' : 'ใบเสร็จรับเงิน',
        signatureLabel: 'ผู้รับเงิน',
        useShippingAddress: false,
        shopLogoBytes: shopLogoBytes,
      );
    }
  }

  static Future<void> testReceipt(Printer? printer, String paperSize, bool isPreview) async {
    final bytes = await testReceiptPreview(paperSize);
    PdfPageFormat format;
    if (paperSize == 'A4') {
      format = PdfPageFormat.a4;
    } else if (paperSize == 'A5') {
      format = PdfPageFormat.a5;
    } else if (paperSize == 'Continuous') {
      format = PrintSettingsHelper.customA5;
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
      format = await PrintSettingsHelper.getCashPageFormat();
    }

    final isContinuous = format.width > 200 * PdfPageFormat.mm;
    final finalPageFormat = isContinuous
        ? PdfPageFormat(
            9.0 * PdfPageFormat.inch,
            5.5 * PdfPageFormat.inch,
            marginLeft: 0.5 * PdfPageFormat.cm,
            marginRight: 2.50 * PdfPageFormat.cm,
            marginTop: 0.8 * PdfPageFormat.cm,
            marginBottom: 0.8 * PdfPageFormat.cm,
          )
        : format;

    await PrintCoreService.printDocument(
        bytes: bytes,
        printer: printer,
        docName: 'Test_Receipt',
        format: finalPageFormat,
        isPreview: isPreview);
  }
}
