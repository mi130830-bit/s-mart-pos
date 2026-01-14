import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart'; // ✅ Import Decimal
import '../../models/payment_record.dart';
import '../../models/delivery_type.dart';
import '../../models/order_item.dart';
import '../../models/customer.dart';
import 'pos_state_manager.dart';
import 'pos_payment_panel.dart';
import '../../services/printing/receipt_service.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/common/custom_buttons.dart';

class PaymentModal extends StatefulWidget {
  final VoidCallback onPaymentSuccess;

  const PaymentModal({super.key, required this.onPaymentSuccess});

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  final ReceiptService _receiptService = ReceiptService();
  final TextEditingController _amountCtrl = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  final List<PaymentRecord> _payments = [];

  // ✅ FIX Rounding using Decimal
  Decimal get _totalPaid => _payments.fold(
      Decimal.zero, (sum, p) => sum + Decimal.parse(p.amount.toString()));

  PaymentType _selectedPaymentType = PaymentType.cash;
  Decimal _receivedAmount = Decimal.zero; // ✅ Use Decimal
  DeliveryType _deliveryType = DeliveryType.none;
  bool _isLoading = false;
  bool _shouldPrint = true;

  @override
  void initState() {
    super.initState();
    _amountFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.space) {
        _fillRemainingAmount();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocusNode.requestFocus();
      _fillRemainingAmount();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _fillRemainingAmount() {
    if (_selectedPaymentType == PaymentType.credit) return;

    final posState = Provider.of<PosStateManager>(context, listen: false);
    final Decimal total = Decimal.parse(posState.grandTotal.toString());
    final Decimal paid = _totalPaid;
    final Decimal remaining = (total - paid)
        .clamp(Decimal.zero, Decimal.parse('999999999')); // Clamp max safe

    if (remaining > Decimal.zero) {
      setState(() {
        _receivedAmount = remaining;
        _amountCtrl.text = remaining.toStringAsFixed(
            2); // Decimal has toStringAsFixed? No, toDouble -> string
        // Decimal toStringAsFixed needs typical double handling or implementation
        // Decimal works usually with toString
        _amountCtrl.text = remaining.toDouble().toStringAsFixed(2);

        _amountCtrl.selection =
            TextSelection(baseOffset: 0, extentOffset: _amountCtrl.text.length);
      });
    } else {
      setState(() {
        _receivedAmount = Decimal.zero;
        _amountCtrl.text = '';
      });
    }
    _updateDisplayToCustomer();
  }

  void _removePayment(int index) {
    setState(() {
      _payments.removeAt(index);
      _fillRemainingAmount();
      _updateDisplayToCustomer();
    });
  }

  Future<void> _processFinish() async {
    final posState = Provider.of<PosStateManager>(context, listen: false);
    final double grandTotalDouble = posState.grandTotal;
    final Decimal grandTotal = Decimal.parse(grandTotalDouble.toString());

    // ✅ Snapshot Data
    final snapshotItems = List<OrderItem>.from(posState.cart);
    final snapshotCustomer = posState.currentCustomer;
    final snapshotDiscount = posState.discountAmount;
    final snapshotTotal = posState.grandTotal + snapshotDiscount;

    Decimal currentInput = _receivedAmount;
    Decimal totalPaidSoFar = _totalPaid + currentInput;
    Decimal remaining = (grandTotal - totalPaidSoFar);

    // Precision check: if remaining is very small negative/positive, treat as 0 logic if needed,
    // but Decimal handles 0.00 exactly.
    // If remaining < 0, it means change.

    // Logic: If remaining > 0, ask to owe.
    if (remaining > Decimal.parse('0.01')) {
      if (posState.currentCustomer == null ||
          posState.currentCustomer!.id == 0) {
        _showError('ลูกค้าทั่วไปไม่สามารถค้างจ่ายได้ (กรุณาเลือกสมาชิก)');
        return;
      }
    }

    if (_deliveryType != DeliveryType.none) {
      if (posState.currentCustomer == null ||
          posState.currentCustomer?.id == 0) {
        if (_deliveryType == DeliveryType.delivery) {
          _showError('การจัดส่ง (Delivery) ต้องระบุลูกค้าสมาชิกเท่านั้น');
          return;
        }
        bool? confirmGeneral = await ConfirmDialog.show(
          context,
          title: '⚠️ ไม่ได้เลือกสมาชิก',
          content: 'คุณกำลังทำรายการ "รับของหลังร้าน" สำหรับลูกค้าทั่วไป\n'
              'ระบบจะสร้างข้อมูลลูกค้าชั่วคราวในระบบส่งของ\n\n'
              'ต้องการดำเนินการต่อหรือไม่?',
          confirmText: 'ดำเนินการต่อ',
          cancelText: 'ยกเลิก',
        );
        if (!mounted) return;
        if (confirmGeneral != true) return;
      }
    }

    if (remaining > Decimal.parse('0.01')) {
      bool? confirmDebt = await ConfirmDialog.show(
        context,
        title: '⚠️ ยอดเงินไม่ครบ',
        content:
            'รับเงินมา: ${NumberFormat('#,##0.00').format(totalPaidSoFar.toDouble())}\n'
            'ขาดอีก: ${NumberFormat('#,##0.00').format(remaining.toDouble())}\n\n'
            'ต้องการบันทึกส่วนที่เหลือเป็น "หนี้ค้างจ่าย" ใช่หรือไม่?',
        confirmText: 'ใช่, บันทึกเป็นหนี้',
        cancelText: 'ไม่, กลับไปแก้ไข',
        isDestructive: false,
      );

      if (confirmDebt != true) return;

      if (currentInput > Decimal.zero) {
        _payments.add(PaymentRecord(
            method: _selectedPaymentType.name,
            amount: currentInput.toDouble()));
      }
      _payments.add(PaymentRecord(
          method: PaymentType.credit.name, amount: remaining.toDouble()));

      _amountCtrl.clear();
      _receivedAmount = Decimal.zero;
    } else {
      if (currentInput > Decimal.zero) {
        _payments.add(PaymentRecord(
          method: _selectedPaymentType.name,
          amount: currentInput.toDouble(),
        ));
        _amountCtrl.clear();
        _receivedAmount = Decimal.zero;
      }
    }

    // Final calculations
    Decimal totalReceived = _payments.fold(
        Decimal.zero, (sum, p) => sum + Decimal.parse(p.amount.toString()));
    Decimal change = Decimal.zero;
    if (totalReceived > grandTotal) {
      change = totalReceived - grandTotal;
    }

    setState(() => _isLoading = true);
    try {
      final orderId = await posState.saveOrder(
        payments: _payments,
        deliveryType: _deliveryType,
      );

      if (_shouldPrint) {
        await _printReceipt(
          orderId: orderId,
          items: snapshotItems,
          customer: snapshotCustomer,
          total: snapshotTotal,
          discount: snapshotDiscount,
          grandTotal: grandTotalDouble,
          received: totalReceived.toDouble(),
          change: change.toDouble(),
          payments: _payments,
          cashierName: posState.currentUser?.displayName ?? 'Staff',
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printReceipt({
    required int orderId,
    required List<OrderItem> items,
    required Customer? customer,
    required double total,
    required double discount,
    required double grandTotal,
    required double received,
    required double change,
    required List<PaymentRecord> payments,
    String? cashierName,
  }) async {
    try {
      bool hasCash = payments.any((p) =>
          p.method.toUpperCase().contains('CASH') ||
          p.method.toUpperCase().contains('TRANSFER') ||
          p.method.toUpperCase().contains('QR') ||
          p.method == 'เงินสด' ||
          p.method.contains('โอน'));

      bool isCreditOnly = !hasCash &&
          payments.any((p) =>
              p.method.toUpperCase().contains('CREDIT') ||
              p.method == 'เงินเชื่อ' ||
              p.method == 'Credit');

      if (isCreditOnly && customer != null) {
        await _receiptService.printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: discount,
        );
      } else {
        await _receiptService.printReceipt(
          orderId: orderId,
          items: items,
          total: total,
          discount: discount,
          grandTotal: grandTotal,
          received: received,
          change: change,
          payments: payments,
          customer: customer,
          cashierName: cashierName,
        );
      }
    } catch (e) {
      debugPrint("Print Error: $e");
    }
  }

  Widget _buildInfoColumn(String label, Decimal val, Color color,
      {double fontSize = 28}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Text(
          '฿${NumberFormat('#,##0.00').format(val.toDouble())}',
          style: TextStyle(
              fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildDivider({double height = 40}) {
    return Container(width: 1, height: height, color: Colors.grey.shade300);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _getLabelForMethod(String method) {
    try {
      return PaymentType.values.firstWhere((e) => e.name == method).label;
    } catch (_) {
      return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final posState = context.watch<PosStateManager>();
    final Decimal grandTotal = Decimal.parse(posState.grandTotal.toString());

    final Decimal totalPaidInList = _totalPaid;
    final Decimal currentlyTyping = _receivedAmount;
    final Decimal totalCaptured = totalPaidInList + currentlyTyping;

    Decimal remaining = Decimal.zero;
    Decimal change = Decimal.zero;

    if (totalCaptured < grandTotal) {
      remaining = grandTotal - totalCaptured;
    } else {
      change = totalCaptured - grandTotal;
    }

    // Tolerance check for "Fully Paid"
    final bool isFullyPaid = remaining <= Decimal.parse('0.01');

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                Navigator.pop(context);
              },
              const SingleActivator(LogicalKeyboardKey.f12): () {
                if (!_isLoading) {
                  setState(() => _shouldPrint = false);
                  _processFinish();
                }
              },
            },
            child: Focus(
              autofocus: true,
              child: Container(
                width: 700,
                height: 700,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ชำระเงิน (Split Payment)',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context))
                        ]),
                    const Divider(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 24),
                      decoration: BoxDecoration(
                          color: isFullyPaid
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isFullyPaid
                                  ? Colors.green.shade200
                                  : Colors.blue.shade200,
                              width: 2)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoColumn(
                              'ยอดรวมทั้งหมด', grandTotal, Colors.black87),
                          _buildDivider(height: 50),
                          _buildInfoColumn('รับเงินมาแล้ว', totalCaptured,
                              Colors.blue.shade800),
                          _buildDivider(height: 50),
                          if (!isFullyPaid)
                            _buildInfoColumn(
                                'ยังค้างชำระ', remaining, Colors.red)
                          else
                            _buildInfoColumn('เงินทอน (Change)', change,
                                Colors.green.shade800,
                                fontSize: 36),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        const Text("ใส่จำนวนเงินที่รับมา",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _amountCtrl,
                                focusNode: _amountFocusNode,
                                textAlign: TextAlign.center,
                                readOnly:
                                    _selectedPaymentType == PaymentType.credit,
                                style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedPaymentType ==
                                            PaymentType.credit
                                        ? Colors.grey
                                        : Colors.blue),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor:
                                      _selectedPaymentType == PaymentType.credit
                                          ? Colors.grey.shade200
                                          : Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  prefixText:
                                      _selectedPaymentType == PaymentType.credit
                                          ? ''
                                          : '฿ ',
                                  labelText:
                                      _selectedPaymentType == PaymentType.credit
                                          ? 'ไม่ต้องใส่ยอดเงิน (บันทึกหนี้)'
                                          : 'รับเงินสด (Space = ยอดพอดี)',
                                  hintText:
                                      _selectedPaymentType == PaymentType.credit
                                          ? '-'
                                          : '0.00',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]'))
                                ],
                                onSubmitted: (_) => _processFinish(),
                                onChanged: (val) {
                                  setState(() {
                                    if (val.isEmpty) {
                                      _receivedAmount = Decimal.zero;
                                    } else {
                                      _receivedAmount =
                                          Decimal.tryParse(val) ?? Decimal.zero;
                                    }
                                    _updateDisplayToCustomer();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<PaymentType>(
                      segments: PaymentType.values
                          .map((p) => ButtonSegment(
                              value: p,
                              label: Text(p.label),
                              icon: Icon(p.icon)))
                          .toList(),
                      selected: {_selectedPaymentType},
                      onSelectionChanged: (val) {
                        setState(() {
                          _selectedPaymentType = val.first;
                          if (_selectedPaymentType == PaymentType.credit) {
                            _receivedAmount = Decimal.zero;
                            _amountCtrl.clear();
                            FocusScope.of(context).unfocus();
                          } else {
                            _amountFocusNode.requestFocus();
                          }
                          _updateDisplayToCustomer();
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_payments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12)),
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _payments.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final p = _payments[i];
                            return Chip(
                              label: Text(
                                  "${_getLabelForMethod(p.method)}: ฿${p.amount}"),
                              onDeleted: () => _removePayment(i),
                            );
                          },
                        ),
                      ),
                    const Spacer(),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('การจัดส่ง:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            SegmentedButton<DeliveryType>(
                              segments: const [
                                ButtonSegment(
                                    value: DeliveryType.none,
                                    label: Text('หน้าร้าน'),
                                    icon: Icon(Icons.store)),
                                ButtonSegment(
                                    value: DeliveryType.delivery,
                                    label: Text('จัดส่ง'),
                                    icon: Icon(Icons.local_shipping)),
                                ButtonSegment(
                                    value: DeliveryType.pickup,
                                    label: Text('หลังร้าน'),
                                    icon: Icon(Icons.shopping_basket)),
                              ],
                              selected: {_deliveryType},
                              onSelectionChanged: (val) =>
                                  setState(() => _deliveryType = val.first),
                              style: const ButtonStyle(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact),
                            ),
                          ],
                        )),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('พิมพ์ใบเสร็จ',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[700])),
                            Transform.scale(
                              scale: 1.2,
                              child: Checkbox(
                                value: _shouldPrint,
                                onChanged: (val) =>
                                    setState(() => _shouldPrint = val ?? true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 56,
                          width: 240,
                          child: CustomButton(
                            onPressed: (isFullyPaid ||
                                        _selectedPaymentType ==
                                            PaymentType.credit) &&
                                    !_isLoading
                                ? _processFinish
                                : null,
                            backgroundColor:
                                _selectedPaymentType == PaymentType.credit
                                    ? Colors.orange
                                    : Colors.green,
                            icon: _isLoading ? null : Icons.check_circle,
                            label: _selectedPaymentType == PaymentType.credit
                                ? 'บันทึกหนี้'
                                : 'เสร็จสิ้น',
                            isLoading: _isLoading,
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            )));
  }

  void _updateDisplayToCustomer() {
    final posState = Provider.of<PosStateManager>(context, listen: false);
    final Decimal currentInput = _receivedAmount;
    final Decimal totalPaidInList = _totalPaid;
    final Decimal totalCaptured = totalPaidInList + currentInput;

    final Decimal grandTotal = Decimal.parse(posState.grandTotal.toString());
    Decimal change = Decimal.zero;
    if (totalCaptured > grandTotal) {
      change = totalCaptured - grandTotal;
    }

    if (_selectedPaymentType == PaymentType.qr) {
      double qrAmount = currentInput.toDouble();
      if (qrAmount <= 0) {
        if (totalCaptured < grandTotal) {
          qrAmount = (grandTotal - totalPaidInList).toDouble();
        }
      }
      posState.showPaymentQr(qrAmount);
    } else {
      posState.updateCustomerDisplay(
          received: totalCaptured.toDouble(), change: change.toDouble());
    }
  }
}
