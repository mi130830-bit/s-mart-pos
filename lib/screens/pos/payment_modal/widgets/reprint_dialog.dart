import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../../models/order_item.dart';
import '../../../../models/customer.dart';
import '../../../../models/payment_record.dart';
import '../../../../services/printing/receipt_service.dart';
import '../../../../widgets/common/barcode_listener_wrapper.dart';

/// Post-checkout dialog that lets the cashier reprint the receipt
/// (80mm thermal or A5 cash bill) or dismiss.
///
/// All business logic lives in [PaymentModalControllerMixin].
/// This widget is Pure UI — only receives data and callbacks via constructor.
///
/// [onBarcodeScanned] fires if the cashier scans a new product barcode
/// while this dialog is open. The controller handles forwarding to POS.
class ReprintDialog extends StatelessWidget {
  final int orderId;
  final List<OrderItem> items;
  final Customer? customer;
  final double total;
  final double discount;
  final double grandTotal;
  final double received;
  final double change;
  final List<PaymentRecord> payments;
  final String cashierName;
  final ReceiptService receiptService;

  /// Called when the cashier scans a barcode while the dialog is open.
  /// The controller closes the dialog and forwards the barcode to POS.
  final void Function(String barcode, BuildContext ctx)? onBarcodeScanned;

  const ReprintDialog({
    super.key,
    required this.orderId,
    required this.items,
    required this.customer,
    required this.total,
    required this.discount,
    required this.grandTotal,
    required this.received,
    required this.change,
    required this.payments,
    required this.cashierName,
    required this.receiptService,
    this.onBarcodeScanned,
  });

  void _print80mm(BuildContext ctx) {
    receiptService.printReceipt(
      orderId: orderId,
      items: items,
      customer: customer,
      total: total,
      discount: discount,
      grandTotal: grandTotal,
      received: received,
      change: change,
      payments: payments,
      cashierName: cashierName,
      remark: 'ใบเสร็จรับเงิน (สำเนา)',
    );
    Navigator.pop(ctx);
  }

  void _printA5(BuildContext ctx) {
    receiptService.printReceipt(
      orderId: orderId,
      items: items,
      customer: customer,
      total: total,
      discount: discount,
      grandTotal: grandTotal,
      received: received,
      change: change,
      payments: payments,
      cashierName: cashierName,
      remark: 'ใบเสร็จรับเงิน (สำเนา)',
      pageFormatOverride: PdfPageFormat.a5,
      useCashBillSettings: true,
    );
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return BarcodeListenerWrapper(
      onBarcodeScanned: (scannedCode) {
        Navigator.of(context).pop();
        onBarcodeScanned?.call(scannedCode, context);
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.print, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text('พิมพ์ใบเสร็จซ้ำหรือไม่?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'สามารถเลือกพิมพ์สลิปซ้ำ (80มม.) หรือพิมพ์บิลเงินสด (A5) ได้'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'หรือสแกนบาร์โค้ดสินค้าถัดไปเพื่อเริ่มขายทันที',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.receipt_long),
            label: const Text('พิมพ์ 80มม.'),
            onPressed: () => _print80mm(context),
          ),
          TextButton.icon(
            icon: const Icon(Icons.description),
            label: const Text('พิมพ์ A5 (บิลเงินสด)'),
            onPressed: () => _printA5(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('ไม่พิมพ์ (เสร็จสิ้น)'),
          ),
        ],
      ),
    );
  }
}
