import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/customer.dart';
import '../../../../models/debtor_transaction.dart';
import '../../../../repositories/debtor_repository.dart';
import '../../../../services/alert_service.dart';

/// Dialog รับชำระหนี้ พร้อม numpad และ suggestion chips
Future<void> showDebtPaymentDialog({
  required BuildContext context,
  required Customer currentCustomer,
  required List<DebtorTransaction> ledger,
  required Set<int> selectedIds,
  required DebtorRepository debtRepo,
  required VoidCallback onSuccess,
}) async {
  final TextEditingController amountController = TextEditingController();

  // ยอดเงินเริ่มต้น: เลือกจากยอดรวมที่เลือก หรือ ยอดหนี้ทั้งหมด
  double selectedTotal = 0.0;
  for (var item in ledger) {
    if (item.type == 'CREDIT_SALE' && selectedIds.contains(item.id)) {
      selectedTotal += item.amount.toDouble();
    }
  }

  double defaultAmount =
      selectedIds.isNotEmpty ? selectedTotal : currentCustomer.currentDebt;
  amountController.text =
      defaultAmount > 0 ? NumberFormat('#,###.##').format(defaultAmount) : '';

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      bool isProcessing = false;
      return StatefulBuilder(builder: (builderContext, setStateDialog) {
        double getRawAmount() {
          String clean = amountController.text.replaceAll(',', '');
          return double.tryParse(clean) ?? 0.0;
        }

        double inputAmount = getRawAmount();
        double debtToPay = defaultAmount;
        double change = inputAmount > debtToPay ? inputAmount - debtToPay : 0;
        double remainingDebt =
            inputAmount < debtToPay ? debtToPay - inputAmount : 0;

        void updateAmount(String val) {
          if (isProcessing) return;
          setStateDialog(() {
            String currentRaw = amountController.text.replaceAll(',', '');
            if (val == 'C') {
              amountController.clear();
              return;
            } else if (val == '⌫') {
              if (currentRaw.isNotEmpty) {
                currentRaw = currentRaw.substring(0, currentRaw.length - 1);
              }
            } else {
              currentRaw += val;
            }

            if (currentRaw.isEmpty) {
              amountController.clear();
            } else {
              double d = double.tryParse(currentRaw) ?? 0.0;
              final fmt = NumberFormat('#,###.##');
              amountController.text = fmt.format(d);
            }
          });
        }

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('รับชำระหนี้ (Payment)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. ข้อมูลหนี้
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ยอดที่ต้องชำระ:',
                          style: TextStyle(fontSize: 16)),
                      Text(NumberFormat('#,##0.00').format(debtToPay),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. ช่องกรอกจำนวนเงิน
                TextField(
                  controller: amountController,
                  readOnly: true,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'รับเงินมา',
                    prefixText: '฿ ',
                    border: OutlineInputBorder(),
                  ),
                ),

                // 3. Change / Remaining Display
                if (change > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('เงินทอน:',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                        Text(NumberFormat('#,##0.00').format(change),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  )
                else if (remainingDebt > 0 && inputAmount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ค้างชำระเพิ่ม:',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                        Text(NumberFormat('#,##0.00').format(remainingDebt),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                const Divider(),

                // 4. Calculator Pad
                Opacity(
                  opacity: isProcessing ? 0.5 : 1.0,
                  child: IgnorePointer(
                    ignoring: isProcessing,
                    child: GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        for (var key in [
                          '7', '8', '9',
                          '4', '5', '6',
                          '1', '2', '3',
                          'C', '0', '⌫'
                        ])
                          ElevatedButton(
                            onPressed: () => updateAmount(key),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (key == 'C' || key == '⌫')
                                  ? Colors.red.shade50
                                  : Colors.grey.shade100,
                              foregroundColor: (key == 'C' || key == '⌫')
                                  ? Colors.red
                                  : Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(key,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Suggestion Chips
                Opacity(
                  opacity: isProcessing ? 0.5 : 1.0,
                  child: IgnorePointer(
                    ignoring: isProcessing,
                    child: Wrap(
                      spacing: 8,
                      children: [100, 500, 1000].map((note) {
                        return ActionChip(
                          label: Text('+$note'),
                          onPressed: () {
                            double current = getRawAmount();
                            setStateDialog(() {
                              double newVal = current + note;
                              final fmt = NumberFormat('#,###.##');
                              amountController.text = fmt.format(newVal);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!isProcessing)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
                child: const Text('ยกเลิก', style: TextStyle(fontSize: 16)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: (inputAmount > 0 && !isProcessing)
                  ? () async {
                      setStateDialog(() => isProcessing = true);
                      final nav = Navigator.of(dialogContext);

                      try {
                        if (selectedIds.isNotEmpty) {
                          final selectedOrderIds = ledger
                              .where((item) =>
                                  selectedIds.contains(item.id) &&
                                  item.orderId != null)
                              .map((item) => item.orderId!)
                              .toList();

                          await debtRepo.processBatchPayment(
                              customerId: currentCustomer.id,
                              payAmount: inputAmount - change,
                              orderIds: selectedOrderIds);
                        } else {
                          final pendingBills = await debtRepo
                              .getPendingBills(currentCustomer.id);
                          final pendingOrderIds =
                              pendingBills.map((b) => b.orderId).toList();

                          if (pendingOrderIds.isNotEmpty) {
                            await debtRepo.processBatchPayment(
                                customerId: currentCustomer.id,
                                payAmount: inputAmount - change,
                                orderIds: pendingOrderIds);
                          } else {
                            await debtRepo.payDebt(
                                customerId: currentCustomer.id,
                                amount: inputAmount - change);
                          }
                        }

                        if (dialogContext.mounted) {
                          nav.pop();
                          onSuccess();
                          AlertService.show(
                            context: dialogContext,
                            message: 'บันทึกการชำระเงินสำเร็จ',
                            type: 'success',
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isProcessing = false);
                        if (dialogContext.mounted) {
                          AlertService.show(
                            context: dialogContext,
                            message: 'Error: $e',
                            type: 'error',
                          );
                        }
                      }
                    }
                  : null,
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('ยืนยันการรับเงิน',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      });
    },
  );
}
