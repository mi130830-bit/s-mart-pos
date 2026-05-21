import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/outstanding_bill.dart';

class DebtorTableRow extends StatelessWidget {
  final int index;
  final OutstandingBill bill;
  final VoidCallback onPayPressed;
  final VoidCallback onViewLedgerPressed;
  final VoidCallback onViewDetailsPressed;
  final VoidCallback onPrintPressed;
  final VoidCallback onDeliveryPressed;

  const DebtorTableRow({
    super.key,
    required this.index,
    required this.bill,
    required this.onPayPressed,
    required this.onViewLedgerPressed,
    required this.onViewDetailsPressed,
    required this.onPrintPressed,
    required this.onDeliveryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dt = bill.createdAt;
    final amount = bill.amount;
    final remaining = bill.remaining;

    return Container(
      color: index % 2 == 0
          ? Colors.white
          : Colors.blue.shade50.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // No.
          Expanded(
            flex: 1,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('dd/MM/yyyy').format(dt),
              textAlign: TextAlign.center,
            ),
          ),
          // Customer
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bill.customerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (bill.phone != null && bill.phone!.isNotEmpty)
                  Text(
                    bill.phone!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          // Bill #
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#${bill.orderId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (bill.status == 'HELD')
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'พักบิล',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
              ],
            ),
          ),
          // Amount
          Expanded(
            flex: 2,
            child: Text(
              NumberFormat('#,##0.00').format(amount),
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          // Paid
          Expanded(
            flex: 2,
            child: Text(
              NumberFormat('#,##0.00').format(amount - remaining),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.green),
            ),
          ),
          // Remaining
          Expanded(
            flex: 2,
            child: Text(
              NumberFormat('#,##0.00').format(remaining),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
          // Actions
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pay Button
                IconButton(
                  icon: const Icon(Icons.monetization_on, color: Colors.green),
                  tooltip: 'ชำระเงิน',
                  onPressed: remaining > 0 ? onPayPressed : null,
                ),
                // View Ledger
                IconButton(
                  icon: const Icon(Icons.list_alt, color: Colors.purple),
                  tooltip: 'ดูบัญชีรายคน',
                  onPressed: onViewLedgerPressed,
                ),
                // View Details
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.teal),
                  tooltip: 'ดูรายการสินค้า',
                  onPressed: onViewDetailsPressed,
                ),
                // Print
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.blueGrey),
                  tooltip: 'พิมพ์บิล',
                  onPressed: onPrintPressed,
                ),
                // Delivery
                IconButton(
                  icon: const Icon(Icons.local_shipping, color: Colors.orange),
                  tooltip: 'ส่งงานจัดส่ง',
                  onPressed: onDeliveryPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
