import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/customer.dart';
import '../../../models/debtor_transaction.dart';

/// Tab แสดงรายการเดินบัญชี / หนี้
class CustomerDebtorLedgerTab extends StatelessWidget {
  final Customer currentCustomer;
  final List<DebtorTransaction> ledger;
  final Set<int> selectedIds;
  final Set<int> outstandingOrderIds;
  final bool isLoading;
  final NumberFormat moneyFormat;
  final DateFormat dateFormat;
  final VoidCallback onOpenPaymentDialog;
  final void Function(int id) onToggleSelection;
  final void Function(DebtorTransaction item) onDeleteTransaction;
  final void Function(int orderId) onShowOrderDetail;
  final VoidCallback onRecalculateDebt;

  const CustomerDebtorLedgerTab({
    super.key,
    required this.currentCustomer,
    required this.ledger,
    required this.selectedIds,
    required this.outstandingOrderIds,
    required this.isLoading,
    required this.moneyFormat,
    required this.dateFormat,
    required this.onOpenPaymentDialog,
    required this.onToggleSelection,
    required this.onDeleteTransaction,
    required this.onShowOrderDetail,
    required this.onRecalculateDebt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ยอดหนี้คงเหลือ',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('คำนวณยอดหนี้ใหม่?'),
                        content: const Text(
                            'ระบบจะรวมยอดจากรายการเดินบัญชีทั้งหมดเพื่อให้ได้ยอดปัจจุบันที่ถูกต้องที่สุด'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('ยกเลิก')),
                          TextButton(
                              onPressed: () {
                                Navigator.pop(c);
                                onRecalculateDebt();
                              },
                              child: const Text('ยืนยัน')),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.sync,
                        size: 16, color: Colors.blueGrey),
                  ),
                ],
              ),
              Text(
                '฿${moneyFormat.format(currentCustomer.currentDebt)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: onOpenPaymentDialog,
            icon: const Icon(Icons.payment),
            label: Text(selectedIds.isNotEmpty
                ? 'ชำระ ${selectedIds.length} รายการ'
                : 'รับชำระหนี้'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ledger.isEmpty) {
      return const Center(
          child: Text('ยังไม่มีรายการเคลื่อนไหว',
              style: TextStyle(color: Colors.grey)));
    }

    return ListView.separated(
      itemCount: ledger.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = ledger[i];
        final id = item.id;
        final type = item.type;
        final amount = item.amount.toDouble();
        final dt = item.createdAt;

        final isPayment = type == 'DEBT_PAYMENT';
        final isCreditSale = type == 'CREDIT_SALE';
        final isSelected = selectedIds.contains(id);
        final bool isFullyPaid = isCreditSale &&
            item.orderId != null &&
            !outstandingOrderIds.contains(item.orderId);

        return ListTile(
          leading: isCreditSale
              ? (isFullyPaid
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : Checkbox(
                      value: isSelected,
                      onChanged: (v) => onToggleSelection(id)))
              : CircleAvatar(
                  backgroundColor: isPayment
                      ? Colors.green.shade100
                      : Colors.red.shade100,
                  child: Icon(
                    isPayment ? Icons.check_circle : Icons.shopping_cart,
                    color: isPayment ? Colors.green : Colors.red,
                  ),
                ),
          title: Text(isPayment
              ? 'ชำระหนี้'
              : 'ซื้อเชื่อ (บิล #${item.orderId ?? "-"})'),
          subtitle: Text(dateFormat.format(dt)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (amount > 0 ? '+' : '') + moneyFormat.format(amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: amount > 0 ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey),
                onPressed: () => onDeleteTransaction(item),
                tooltip: 'ลบรายการ',
              ),
            ],
          ),
          onTap: (isCreditSale && item.orderId != null)
              ? () => onShowOrderDetail(item.orderId!)
              : null,
        );
      },
    );
  }
}
