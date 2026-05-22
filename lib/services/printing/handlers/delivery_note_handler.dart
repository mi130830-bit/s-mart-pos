import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:decimal/decimal.dart';

import '../../../models/order_item.dart';
import '../../../models/customer.dart';
import '../../alert_service.dart';

import '../core/print_core_service.dart';
import '../utils/print_settings_helper.dart';
import '../utils/print_data_helper.dart';

import '../../pdf/delivery_note_pdf.dart';

class DeliveryNoteHandler {
  static Future<void> printDeliveryNote({
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
      final validCustomer = await PrintDataHelper.refreshCustomer(customer);
      final pageFormat = pageFormatOverride ?? await PrintSettingsHelper.getDeliveryPageFormat();

      final bytes = await generateDeliveryNoteData(
        orderId: orderId,
        items: items,
        customer: validCustomer!,
        discount: discount,
        pageFormatOverride: pageFormat,
        showRuler: isPreview,
        remark: remark,
      );

      final printer = printerOverride ?? await PrintSettingsHelper.getPrinterBySettingKey(PrintSettingsHelper.keyDeliveryPrinter);

      await PrintCoreService.printDocument(
        bytes: bytes,
        docName: 'Delivery_$orderId',
        format: pageFormat,
        printer: printer,
        isPreview: isPreview,
      );
    } catch (e, stack) {
      debugPrint('❌ printDeliveryNote Error: $e\n$stack');
      AlertService.show(message: 'พิมพ์ใบส่งของไม่สำเร็จ: ${e.toString()}', type: 'error');
    }
  }

  static Future<Uint8List> generateDeliveryNoteData({
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
    final pageFormat = pageFormatOverride ?? await PrintSettingsHelper.getDeliveryPageFormat();
    final shopInfo = await PrintDataHelper.getShopInfo();
    final shopLogoBytes = await PrintDataHelper.getShopLogoBytes();

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

    return DeliveryNotePdf.generate(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: discount,
      vatAmount: vatAmount,
      grandTotalOverride: grandTotalOverride,
      shopInfo: shopInfo,
      showRuler: showRuler,
      remark: remark,
      pageFormat: finalPageFormat,
      shopLogoBytes: shopLogoBytes,
    );
  }

  static Future<Uint8List?> captureDeliveryNoteImage({
    required int orderId,
    required List<OrderItem> items,
    required Customer customer,
    double discount = 0.0,
    double vatAmount = 0.0,
    double? grandTotalOverride,
    String? remark,
  }) async {
    try {
      final validCustomer = await PrintDataHelper.refreshCustomer(customer) ?? customer;
      final pageFormat = PrintSettingsHelper.customA5; 

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

      await for (final page in Printing.raster(bytes, pages: [0], dpi: 100)) {
        return await page.toPng();
      }
      return null;
    } catch (e) {
      debugPrint('❌ captureDeliveryNoteImage Error: $e');
      return null;
    }
  }

  static Future<void> testDeliveryNote(Printer? printer, String paperSize, bool isPreview) async {
    final bytes = await testDeliveryNotePreview(paperSize);
    final format = paperSize == 'A4'
        ? PdfPageFormat.a4
        : (paperSize == 'A5' ? PdfPageFormat.a5 : PrintSettingsHelper.customA5);

    await PrintCoreService.printDocument(
        bytes: bytes,
        printer: printer,
        docName: 'Test_Delivery_Note',
        format: format,
        isPreview: isPreview);
  }

  static Future<Uint8List> testDeliveryNotePreview(String paperSize) async {
    final format = paperSize == 'A4'
        ? PdfPageFormat.a4
        : (paperSize == 'A5' ? PdfPageFormat.a5 : PrintSettingsHelper.customA5);
    final shopInfo = await PrintDataHelper.getShopInfo();
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

    final shopLogoBytes = await PrintDataHelper.getShopLogoBytes();

    return DeliveryNotePdf.generate(
        orderId: 88888,
        items: dummyItems,
        customer: customer,
        discount: 0,
        shopInfo: shopInfo,
        pageFormat: finalPageFormat,
        showRuler: true,
        shopLogoBytes: shopLogoBytes);
  }
}
