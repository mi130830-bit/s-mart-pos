import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../models/customer.dart';
import '../../../models/order_item.dart';
import '../../../repositories/customer_repository.dart';
import '../../../repositories/sales_repository.dart';
import '../../../services/printing/receipt_service.dart';

/// Dialog เลือกประเภทเอกสารแล้วพิมพ์ซ้ำ
class DashboardReprintDialog {
  /// แสดง Dialog เลือกรูปแบบเอกสาร แล้วพิมพ์บิลขาย
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> orderRow,
    required SalesRepository salesRepo,
  }) async {
    if (orderRow['type'] == 'DEBT_PAYMENT') return;
    if (!context.mounted) return;

    final orderId = int.tryParse(orderRow['id'].toString()) ?? 0;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('เลือกประเภทเอกสาร'),
        children: [
          _option(ctx, 'SLIP', Icons.receipt, Colors.green,
              '1. สลิป 80mm/58mm (Thermal)'),
          const Divider(),
          _option(ctx, 'RECEIPT_A4', Icons.description, Colors.blue,
              '2. บิลเงินสด A4 (เต็มแผ่น)'),
          _option(ctx, 'RECEIPT_A5', Icons.description, Colors.blue,
              '3. บิลเงินสด A5 (ครึ่งแผ่น)'),
          const Divider(),
          _option(ctx, 'DELIVERY_A4', Icons.local_shipping, Colors.orange,
              '4. ใบส่งของ A4'),
          _option(ctx, 'DELIVERY_A5', Icons.local_shipping, Colors.orange,
              '5. ใบส่งของ A5'),
          const Divider(),
          _option(ctx, 'SAVE_RECEIPT_PDF', Icons.picture_as_pdf, Colors.red,
              '6. ดาวน์โหลดบิลเงินสด (PDF)'),
          _option(ctx, 'SAVE_DELIVERY_PDF', Icons.picture_as_pdf, Colors.red,
              '7. ดาวน์โหลดใบส่งของ (PDF)'),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    final result = await salesRepo.getOrderWithItems(orderId);
    if (result == null) return;

    final order = result['order'] as Map<String, dynamic>;
    final items = (result['items'] as List<OrderItem>?) ?? [];

    final customer = Customer.fromJson({
      'id': int.tryParse(order['customerId'].toString()) ?? 0,
      'firstName': order['firstName'] ?? '',
      'lastName': order['lastName'] ?? '',
      'phone': order['phone'] ?? '',
      'address': order['address'] ?? '',
    });

    switch (choice) {
      case 'SLIP':
        await ReceiptService().printReceipt(
          orderId: orderId,
          items: items,
          total: double.tryParse(order['total'].toString()) ?? 0,
          grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0,
          received: double.tryParse(order['received'].toString()) ?? 0,
          change: double.tryParse(order['changeAmount'].toString()) ?? 0,
          customer: customer,
          isPreview: false,
          useCashBillSettings: false,
        );
      case 'RECEIPT_A4' || 'RECEIPT_A5':
        await ReceiptService().printReceipt(
          orderId: orderId,
          items: items,
          total: double.tryParse(order['total'].toString()) ?? 0,
          grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0,
          received: double.tryParse(order['received'].toString()) ?? 0,
          change: double.tryParse(order['changeAmount'].toString()) ?? 0,
          customer: customer,
          isPreview: false,
          useCashBillSettings: true,
          pageFormatOverride:
              choice == 'RECEIPT_A4' ? PdfPageFormat.a4 : null,
        );
      case 'DELIVERY_A4' || 'DELIVERY_A5':
        await ReceiptService().printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: double.tryParse(order['discount'].toString()) ?? 0.0,
          isPreview: false,
          pageFormatOverride:
              choice == 'DELIVERY_A4' ? PdfPageFormat.a4 : null,
        );
      case 'SAVE_RECEIPT_PDF':
        await ReceiptService().printReceipt(
          orderId: orderId,
          items: items,
          total: double.tryParse(order['total'].toString()) ?? 0,
          grandTotal: double.tryParse(order['grandTotal'].toString()) ?? 0,
          received: double.tryParse(order['received'].toString()) ?? 0,
          change: double.tryParse(order['changeAmount'].toString()) ?? 0,
          customer: customer,
          isPreview: true,
          useCashBillSettings: true,
        );
      case 'SAVE_DELIVERY_PDF':
        await ReceiptService().printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: double.tryParse(order['discount'].toString()) ?? 0.0,
          isPreview: true,
        );
    }
  }

  /// แสดง Dialog เลือกรูปแบบแล้วพิมพ์ใบเสร็จชำระหนี้
  static Future<void> showDebtPayment(
    BuildContext context, {
    required Map<String, dynamic> o,
    required CustomerRepository customerRepo,
  }) async {
    final int id = int.tryParse(o['id'].toString()) ?? 0;
    final double amount = double.tryParse(o['amount'].toString()) ?? 0.0;
    final String customerName = o['customerName'] ?? 'ลูกค้าทั่วไป';
    final DateTime date =
        DateTime.tryParse(o['createdAt'].toString()) ?? DateTime.now();

    Customer customer = Customer(
      id: 0,
      firstName: customerName,
      lastName: '',
      currentPoints: 0,
      phone: '',
      address: '',
      memberCode: '',
    );

    final cid = int.tryParse(o['customerId']?.toString() ?? '0') ?? 0;
    if (cid > 0) {
      final real = await customerRepo.getCustomerById(cid);
      if (real != null) customer = real;
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('เลือกรูปแบบใบเสร็จ (Select Format)'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await ReceiptService().printDebtPayment(
                transactionId: id,
                customer: customer,
                amount: amount,
                date: date,
                paperSizeOverride: '80mm',
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(children: [
                Icon(Icons.receipt_long, color: Colors.blue),
                SizedBox(width: 10),
                Text('สลิปความร้อน (80mm)'),
              ]),
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              await ReceiptService().printDebtPayment(
                transactionId: id,
                customer: customer,
                amount: amount,
                date: date,
                paperSizeOverride: 'A5',
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(children: [
                Icon(Icons.description, color: Colors.green),
                SizedBox(width: 10),
                Text('ใบเสร็จ A5'),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper ──────────────────────────────────────────────────────────────────

  static SimpleDialogOption _option(BuildContext ctx, String value,
      IconData icon, Color color, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 16)),
        ]),
      ),
    );
  }
}
