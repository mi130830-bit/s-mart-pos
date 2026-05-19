import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/payment_record.dart';
import '../../repositories/shift_repository.dart';

// Import Handlers
import '../hardware/cash_drawer_handler.dart';
import 'handlers/cash_receipt_handler.dart';
import 'handlers/tax_invoice_handler.dart';
import 'handlers/delivery_note_handler.dart';
import 'handlers/shift_report_handler.dart';
import 'handlers/barcode_label_handler.dart';
import 'handlers/picking_list_handler.dart';

/// Facade class to maintain backward compatibility for existing UI code.
/// Delegates all printing logic to domain-specific static handlers.
class ReceiptService {
  Future<void> printPickingList(List<OrderItem> items) async {
    return PickingListHandler.printPickingList(items);
  }

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
    return CashReceiptHandler.printReceipt(
      orderId: orderId,
      items: items,
      total: total,
      discount: discount,
      grandTotal: grandTotal,
      received: received,
      change: change,
      payments: payments,
      customer: customer,
      printerOverride: printerOverride,
      pageFormatOverride: pageFormatOverride,
      isPreview: isPreview,
      useCashBillSettings: useCashBillSettings,
      cashierName: cashierName,
      remark: remark,
    );
  }

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
    return CashReceiptHandler.captureReceiptImage(
      orderId: orderId,
      items: items,
      total: total,
      grandTotal: grandTotal,
      received: received,
      change: change,
      payments: payments,
      customer: customer,
      cashierName: cashierName,
    );
  }

  Future<Uint8List?> captureDeliveryNoteImage({
    required int orderId,
    required List<OrderItem> items,
    required Customer customer,
    double discount = 0.0,
    double vatAmount = 0.0,
    double? grandTotalOverride,
    String? remark,
  }) async {
    return DeliveryNoteHandler.captureDeliveryNoteImage(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: discount,
      vatAmount: vatAmount,
      grandTotalOverride: grandTotalOverride,
      remark: remark,
    );
  }

  Future<void> printDebtPayment({
    required int transactionId,
    required Customer customer,
    required double amount,
    required DateTime date,
    String? paperSizeOverride,
  }) async {
    return CashReceiptHandler.printDebtPayment(
      transactionId: transactionId,
      customer: customer,
      amount: amount,
      date: date,
      paperSizeOverride: paperSizeOverride,
    );
  }

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
    return CashReceiptHandler.printBill(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: discount,
      grandTotal: grandTotal,
      received: received,
      change: change,
      paymentMethod: paymentMethod,
      isReprint: isReprint,
    );
  }

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
    return TaxInvoiceHandler.printTaxInvoice(
      orderId: orderId,
      items: items,
      total: total,
      grandTotal: grandTotal,
      vatRate: vatRate,
      customer: customer,
      printerOverride: printerOverride,
      isPreview: isPreview,
    );
  }

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
    return DeliveryNoteHandler.printDeliveryNote(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: discount,
      printerOverride: printerOverride,
      pageFormatOverride: pageFormatOverride,
      isPreview: isPreview,
      remark: remark,
    );
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
    return DeliveryNoteHandler.generateDeliveryNoteData(
      orderId: orderId,
      items: items,
      customer: customer,
      discount: discount,
      vatAmount: vatAmount,
      grandTotalOverride: grandTotalOverride,
      pageFormatOverride: pageFormatOverride,
      showRuler: showRuler,
      remark: remark,
    );
  }

  Future<void> testA5Document(Printer? printer) async {
    return TaxInvoiceHandler.testA5Document(printer);
  }

  Future<void> printBarcode({
    required String barcode,
    required String name,
    required double price,
    Printer? printerOverride,
  }) async {
    return BarcodeLabelHandler.printBarcode(
      barcode: barcode,
      name: name,
      price: price,
      printerOverride: printerOverride,
    );
  }

  Future<void> openDrawer({bool isTest = false}) async {
    return CashDrawerHandler.openDrawer(isTest: isTest);
  }

  Future<void> printShiftClosingSlip({
    required ShiftSummary shift,
    required String paperSize,
    Printer? printerOverride,
    bool isPreview = false,
  }) async {
    return ShiftReportHandler.printShiftClosingSlip(
      shift: shift,
      paperSize: paperSize,
      printerOverride: printerOverride,
      isPreview: isPreview,
    );
  }

  Future<void> testReceipt(Printer? printer, String paperSize, bool isPreview) async {
    return CashReceiptHandler.testReceipt(printer, paperSize, isPreview);
  }

  Future<void> testDeliveryNote(Printer? printer, String paperSize, bool isPreview) async {
    return DeliveryNoteHandler.testDeliveryNote(printer, paperSize, isPreview);
  }

  Future<void> testTaxInvoice(Printer? printer, bool isPreview) async {
    return TaxInvoiceHandler.testTaxInvoice(printer, isPreview);
  }

  Future<Uint8List> testReceiptPreview(String paperSize) async {
    return CashReceiptHandler.testReceiptPreview(paperSize);
  }

  Future<Uint8List> testDeliveryNotePreview(String paperSize) async {
    return DeliveryNoteHandler.testDeliveryNotePreview(paperSize);
  }

  Future<Uint8List> testTaxInvoicePreview() async {
    return TaxInvoiceHandler.testTaxInvoicePreview();
  }
}
