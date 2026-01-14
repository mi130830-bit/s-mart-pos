import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pos_state_manager.dart';
import 'payment_modal.dart';
import '../customers/customer_search_dialog.dart';
import '../customers/customer_form_dialog.dart';
import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';

enum PaymentType {
  cash('เงินสด', Icons.money),
  qr('QR/โอน', Icons.qr_code),
  card('บัตรเครดิต', Icons.credit_card),
  credit('เงินเชื่อ', Icons.credit_score);

  final String label;
  final IconData icon;
  const PaymentType(this.label, this.icon);
}

class PosPaymentPanel extends StatelessWidget {
  final VoidCallback onPaymentSuccess;
  final VoidCallback? onClear;

  const PosPaymentPanel(
      {super.key, required this.onPaymentSuccess, this.onClear});

  void _openPaymentModal(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentModal(onPaymentSuccess: onPaymentSuccess),
    );

    if (result == true) {
      onPaymentSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final posState = context.watch<PosStateManager>();
    final finalTotal = posState.grandTotal;
    final vatAmt = posState.vatAmount;
    final selectedVat = posState.vatType;

    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ✅ Optimized Clock Widget
          const Center(child: _DigitalClock()),
          const SizedBox(height: 10),

          _buildCustomerCard(context, posState),
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
                  _buildDisplayBox('รวมเป็นเงิน', posState.total,
                      color: Colors.blue[800]!),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _showDiscountDialog(context, posState),
                    child: _buildDisplayBox(
                      'ส่วนลด ${posState.isPercentDiscount ? "(${posState.billDiscount}%)" : ""}',
                      posState.discountAmount,
                      color: Colors.red[700]!,
                      icon: Icons.edit,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildDisplayBox('ภาษีมูลค่าเพิ่ม (7%)', vatAmt,
                      color: Colors.grey[700]!, fontSize: 20),
                  const SizedBox(height: 4),
                  _buildDisplayBox('ยอดสุทธิ', finalTotal,
                      color: Colors.green, isHighlight: true, fontSize: 36),
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
                    child: _buildActionButton(
                      label: 'พักบิล',
                      icon: Icons.history_rounded,
                      colors: [
                        const Color(0xFFF39C12),
                        const Color(0xFFF1C40F)
                      ],
                      onPressed: posState.cart.isNotEmpty
                          ? () {
                              posState.holdCurrentBill(
                                  note: 'พักบิลโดย Cashier');
                              onPaymentSuccess();
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      label: 'ยกเลิก',
                      icon: Icons.delete_sweep_outlined,
                      colors: [
                        const Color(0xFFE74C3C),
                        const Color(0xFFC0392B)
                      ],
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
                    child: _buildActionButton(
                      label: 'คิดเงิน',
                      subLabel: '(Enter)',
                      icon: Icons.account_balance_wallet_outlined,
                      colors: [
                        const Color(0xFF27AE60),
                        const Color(0xFF2ECC71)
                      ],
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

  // ... (Other Helpers: _buildActionButton, _buildCustomerCard, _buildDisplayBox are same) ...
  // For brevity, displaying only changed/extracted parts.

  Widget _buildActionButton({
    required String label,
    String? subLabel,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: onPressed != null
              ? colors
              : [Colors.grey.shade300, Colors.grey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (subLabel != null)
                    Text(subLabel,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, PosStateManager posState) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.person, size: 36),
        title: Text(posState.currentCustomer?.firstName ?? 'ลูกค้าทั่วไป',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        subtitle: Text(posState.currentCustomer?.phone ?? ''),
        trailing: IconButton(
          icon: const Icon(Icons.person_add, color: Colors.green),
          onPressed: () => _showQuickAddCustomerDialog(context, posState),
        ),
        onTap: () async {
          final Customer? selected = await showDialog<Customer>(
            context: context,
            builder: (_) => const CustomerSearchDialog(),
          );
          if (selected != null) posState.selectCustomer(selected);
        },
      ),
    );
  }

  Widget _buildDisplayBox(String label, double val,
      {required Color color,
      bool isHighlight = false,
      double fontSize = 24,
      IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold)),
            if (icon != null) ...[
              const SizedBox(width: 5),
              Icon(icon, size: 16, color: Colors.grey)
            ]
          ]),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('฿${NumberFormat('#,##0.00').format(val)}',
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, PosStateManager posState) {
    final ctrl = TextEditingController(text: posState.billDiscount.toString());
    bool isPercent = posState.isPercentDiscount;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (c, st) => AlertDialog(
                  title: const Text('ส่วนลดท้ายบิล'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: 'มูลค่า', suffixText: 'บาท/%')),
                    Row(children: [
                      Checkbox(
                          value: isPercent,
                          onChanged: (v) => st(() => isPercent = v!)),
                      const Text('ลดเป็น %')
                    ]),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('ยกเลิก')),
                    ElevatedButton(
                        onPressed: () {
                          posState.setBillDiscount(
                              double.tryParse(ctrl.text) ?? 0,
                              isPercent: isPercent);
                          Navigator.pop(ctx);
                        },
                        child: const Text('ตกลง'))
                  ],
                )));
  }

  void _showHeldBillsDialog(BuildContext context, PosStateManager posState) {
    // ... same as before
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('รายการพักบิล'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.separated(
            itemCount: posState.heldBills.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final bill = posState.heldBills[i];
              return ListTile(
                title: Text(bill.customer?.firstName ?? "ลูกค้าทั่วไป"),
                subtitle: Text(
                    '${bill.items.length} รายการ - ฿${NumberFormat('#,##0.00').format(bill.total)}'),
                onTap: () async {
                  final warnings = await posState.checkHeldBillStock(i);
                  if (warnings.isEmpty) {
                    // No issues, recall immediately
                    await posState.recallHeldBill(i);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } else {
                    // Show warning
                    if (!ctx.mounted) return;
                    showDialog(
                      context: ctx,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('สินค้าไม่เพียงพอ (Insufficient Stock)'),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                  'รายการต่อไปนี้มีสินค้าในคลังไม่พอจ่าย:'),
                              const SizedBox(height: 8),
                              ...warnings.map((w) => Text(w,
                                  style: const TextStyle(color: Colors.red))),
                              const SizedBox(height: 16),
                              const Text('คุณต้องการดึงบิลคืนมาหรือไม่?'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ยกเลิก'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange),
                            onPressed: () async {
                              Navigator.pop(context); // Close warning
                              await posState.recallHeldBill(i); // Force recall
                              if (ctx.mounted) Navigator.pop(ctx); // Close list
                            },
                            child: const Text('ทำต่อ (Proceed Anyway)'),
                          ),
                        ],
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showQuickAddCustomerDialog(
      BuildContext context, PosStateManager posState) async {
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

// ✅ Extracted Clock Widget
class _DigitalClock extends StatefulWidget {
  const _DigitalClock();

  @override
  State<_DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<_DigitalClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      DateFormat('d MMM yyyy HH:mm:ss', 'th').format(_now),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    );
  }
}
