import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/order_item.dart';
import '../../../../repositories/debtor_repository.dart';
import '../../../../repositories/sales_repository.dart';
import '../../../../services/alert_service.dart';

class DebtorDialogs {
  /// Shows the detailed order items for a specific order.
  static Future<void> showBillDetails({
    required BuildContext context,
    required int orderId,
    required SalesRepository salesRepo,
  }) async {
    // Show a global loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final fullOrderData = await salesRepo.getOrderWithItems(orderId);
      
      // Close the progress spinner if mounted
      if (!context.mounted) return;
      Navigator.pop(context);

      if (fullOrderData == null) return;

      final items = fullOrderData['items'] as List<OrderItem>;
      final order = fullOrderData['order'];

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('รายละเอียดบิล #$orderId'),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      'ลูกค้า: ${order['firstName']} ${order['lastName'] ?? ''}',
                    ),
                    subtitle: Text(
                      'ยอดรวม: ${NumberFormat('#,##0.00').format(double.tryParse(order['grandTotal']?.toString() ?? '0') ?? 0)} บาท',
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        return ListTile(
                          dense: true,
                          leading: Text('${i + 1}.'),
                          title: Text(item.productName),
                          subtitle: item.comment.isNotEmpty
                              ? Text(
                                  item.comment,
                                  style: const TextStyle(color: Colors.grey),
                                )
                              : null,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${NumberFormat('#,##0.##').format(item.quantity.toDouble())} x ${NumberFormat('#,##0.00').format(item.price.toDouble())}',
                              ),
                              Text(
                                NumberFormat('#,##0.00').format(item.total.toDouble()),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // pop the spinner
      if (context.mounted) Navigator.pop(context);
      debugPrint("View Details Error: $e");
      if (context.mounted) {
        AlertService.show(
          context: context,
          message: 'เกิดข้อผิดพลาด: $e',
          type: 'error',
        );
      }
    }
  }

  /// Shows the payment keypad dialog to settle outstanding amount.
  static Future<void> showPaymentDialog({
    required BuildContext context,
    required int orderId,
    required double remainingAmount,
    required DebtorRepository debtorRepo,
    required VoidCallback onSuccess,
  }) async {
    final TextEditingController amountController = TextEditingController();
    amountController.text = NumberFormat('#,###.##').format(remainingAmount);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double getRawAmount() =>
                double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
            double inputAmount = getRawAmount();

            return AlertDialog(
              title: Text('ชำระเงิน (บิล #$orderId)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ยอดคงค้าง: ${NumberFormat('#,##0.00').format(remainingAmount)}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'ระบุยอดชำระ',
                      border: OutlineInputBorder(),
                      suffixText: 'บาท',
                    ),
                    onChanged: (val) {
                      setStateDialog(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  if (inputAmount > remainingAmount)
                    const Text(
                      'ยอดชำระเกินยอดคงค้าง!',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (inputAmount > 0 &&
                          inputAmount <= remainingAmount + 0.01)
                      ? () async {
                          Navigator.pop(context);
                          
                          // Show loading spinner
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          final success = await debtorRepo.paySpecificBill(
                            orderId: orderId,
                            amount: inputAmount,
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context); // Close loading spinner

                          if (success) {
                            AlertService.show(
                              context: context,
                              message: 'บันทึกการชำระเงินสำเร็จ',
                              type: 'success',
                            );
                            onSuccess();
                          } else {
                            AlertService.show(
                              context: context,
                              message: 'เกิดข้อผิดพลาดในการบันทึก',
                              type: 'error',
                            );
                          }
                        }
                      : null,
                  child: const Text('ยืนยัน'),
                )
              ],
            );
          },
        );
      },
    );
  }
}
