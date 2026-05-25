//import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pos_state_manager.dart';
import 'payment_modal.dart';
import 'widgets/held_bills_dialog.dart';
import '../customers/customer_search_dialog.dart';
import '../customers/customer_form_dialog.dart';
import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';
import 'widgets/digital_clock.dart';
import 'widgets/customer_card.dart';
import 'widgets/display_box.dart';
import 'widgets/action_button.dart';

enum PaymentType {
  cash('เงินสด', Icons.money),
  qr('QR/โอน', Icons.qr_code),
  card('บัตรเครดิต', Icons.credit_card),
  credit('เงินเชื่อ', Icons.credit_score);

  final String label;
  final IconData icon;
  const PaymentType(this.label, this.icon);
}

class PosPaymentPanel extends ConsumerWidget {
  final VoidCallback onPaymentSuccess;
  final VoidCallback? onClear;
  final VoidCallback? onHoldSuccess;

  const PosPaymentPanel({
    super.key,
    required this.onPaymentSuccess,
    this.onClear,
    this.onHoldSuccess,
  });

  void _openPaymentModal(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentModal(onPaymentSuccess: onPaymentSuccess),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(posProvider);
    final posState = ref.read(posProvider.notifier);
    final finalTotal = posState.grandTotal;
    final vatAmt = posState.vatAmount;
    final selectedVat = posState.vatType;

    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.grey[100],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ✅ Extracted Clock Widget
          const Center(child: DigitalClock()),
          const SizedBox(height: 10),

          // ✅ Extracted Customer Card Widget
          CustomerCard(
            customer: posState.currentCustomer,
            onQuickAddPressed: () => _showQuickAddCustomerDialog(context, posState),
            onClearCustomer: () => posState.selectCustomer(null),
            onSearchPressed: () async {
              final Customer? selected = await showDialog<Customer>(
                context: context,
                builder: (_) => const CustomerSearchDialog(),
              );
              if (selected != null) posState.selectCustomer(selected);
            },
          ),
          const SizedBox(height: 10),

          if (posState.heldBills.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showHeldBillsDialog(context, posState),
                icon: const Icon(Icons.receipt_long, color: Colors.orange),
                label: Text('รายการพักบิล (${posState.heldBills.length})'),
              ),
            ),

          SegmentedButton<VatType>(
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            segments: VatType.values
                .map((v) =>
                    ButtonSegment<VatType>(value: v, label: Text(v.label)))
                .toList(),
            selected: {selectedVat},
            onSelectionChanged: (Set<VatType> newSelection) {
              posState.setVatType(newSelection.first);
            },
          ),
          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ✅ Extracted Display Box Widgets
                  DisplayBox(
                    label: 'รวมเป็นเงิน',
                    val: posState.total,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 4),
                  DisplayBox(
                    label: 'ส่วนลดรวมสินค้า',
                    val: posState.cart.fold(0.0, (sum, item) => sum + item.discount.toDouble()) +
                        posState.discountAmount -
                        posState.extraBillDiscount -
                        posState.promoDiscount,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 4),
                  if (posState.promoDiscount > 0) ...[
                    DisplayBox(
                      label: "🎯 ${posState.appliedPromotion?.name ?? 'โปรโมชั่น'}",
                      val: posState.promoDiscount,
                      color: Colors.purple,
                      icon: Icons.local_activity,
                    ),
                    const SizedBox(height: 4),
                  ],
                  InkWell(
                    onTap: () => _showExtraDiscountDialog(context, posState),
                    child: DisplayBox(
                      label: 'ส่วนลด 2 (เพิ่มเติม)',
                      val: posState.extraBillDiscount,
                      color: Colors.orange,
                      icon: Icons.edit,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DisplayBox(
                    label: 'ภาษีมูลค่าเพิ่ม (7%)',
                    val: vatAmt,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]!
                        : Colors.grey[700]!,
                    fontSize: 20,
                  ),
                  const SizedBox(height: 4),
                  DisplayBox(
                    label: 'ยอดสุทธิ',
                    val: finalTotal,
                    color: Colors.green,
                    isHighlight: true,
                    fontSize: 36,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    // ✅ Extracted Action Button Widget
                    child: ActionButton(
                      label: 'พักบิล',
                      icon: Icons.history_rounded,
                      colors: const [Color(0xFFF39C12), Color(0xFFF1C40F)],
                      onPressed: posState.cart.isNotEmpty
                          ? () async {
                              try {
                                await posState.holdCurrentBill(note: 'พักบิลโดย Cashier');
                                if (onHoldSuccess != null) onHoldSuccess!();
                              } catch (e) {
                                // Ignore error
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: 'ยกเลิก',
                      icon: Icons.delete_sweep_outlined,
                      colors: const [Color(0xFFE74C3C), Color(0xFFC0392B)],
                      onPressed: () {
                        if (onClear != null) onClear!();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'คิดเงิน',
                      icon: Icons.account_balance_wallet_outlined,
                      colors: const [Color(0xFF27AE60), Color(0xFF2ECC71)],
                      onPressed: posState.cart.isNotEmpty
                          ? () => _openPaymentModal(context)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExtraDiscountDialog(BuildContext context, PosStateNotifier posState) {
    final ctrl = TextEditingController(text: posState.extraBillDiscount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ส่วนลด 2 (เพิ่มเติม)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'มูลค่าส่วนลด (บาท)',
                suffixText: 'บาท',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              posState.setExtraBillDiscount(double.tryParse(ctrl.text) ?? 0);
              Navigator.pop(ctx);
            },
            child: const Text('ตกลง'),
          )
        ],
      ),
    );
  }

  void _showHeldBillsDialog(BuildContext context, PosStateNotifier posState) {
    showDialog(
      context: context,
      builder: (_) => const HeldBillsDialog(),
    );
  }

  void _showQuickAddCustomerDialog(
      BuildContext context, PosStateNotifier posState) async {
    final repo = CustomerRepository();
    final result = await showDialog<Customer>(
      context: context,
      builder: (ctx) => CustomerFormDialog(repo: repo),
    );
    if (result != null) {
      posState.selectCustomer(result);
    }
  }
}
