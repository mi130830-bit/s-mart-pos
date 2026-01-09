import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  // ✅ FIX Rounding
  double get _totalPaid =>
      _round(_payments.fold(0.0, (sum, p) => sum + p.amount));

  PaymentType _selectedPaymentType = PaymentType.cash;
  double _receivedAmount = 0.0;
  DeliveryType _deliveryType = DeliveryType.none;
  bool _isLoading = false;
  bool _shouldPrint = true; // ✅ Default Add

  // ✅ Helper for Precision
  double _round(double val) => (val * 100).round() / 100.0;

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
    final total = posState.grandTotal;
    final remaining = _round((total - _totalPaid).clamp(0.0, double.infinity));

    if (remaining > 0) {
      setState(() {
        _receivedAmount = remaining;
        _amountCtrl.text = remaining.toStringAsFixed(2);
        _amountCtrl.selection =
            TextSelection(baseOffset: 0, extentOffset: _amountCtrl.text.length);
      });
    } else {
      setState(() {
        _receivedAmount = 0;
        _amountCtrl.text = '';
      });
    }
    _updateDisplayToCustomer(); // ✅ Update Display
  }

  void _removePayment(int index) {
    setState(() {
      _payments.removeAt(index);
      _fillRemainingAmount();
      _updateDisplayToCustomer(); // ✅ Update Display
    });
  }

  Future<void> _processFinish() async {
    final posState = Provider.of<PosStateManager>(context, listen: false);
    final grandTotal = posState.grandTotal;

    // ✅ Snapshot Data for Receipt (Capture BEFORE saveOrder/clearCart)
    final snapshotItems = List<OrderItem>.from(posState.cart);
    final snapshotCustomer = posState.currentCustomer;
    final snapshotDiscount = posState.discountAmount;
    final snapshotTotal =
        posState.grandTotal + snapshotDiscount; // Pre-discount total

    double currentInput = _receivedAmount;
    double totalPaidSoFar = _round(_totalPaid + currentInput);
    double remaining =
        _round((grandTotal - totalPaidSoFar).clamp(0.0, double.infinity));

    if (remaining > 0.01) {
      if (posState.currentCustomer == null ||
          posState.currentCustomer!.id == 0) {
        _showError('ลูกค้าทั่วไปไม่สามารถค้างจ่ายได้ (กรุณาเลือกสมาชิก)');
        return;
      }
    }

    if (_deliveryType != DeliveryType.none) {
      if (posState.currentCustomer == null ||
          posState.currentCustomer?.id == 0) {
        // Strict Check for Delivery
        if (_deliveryType == DeliveryType.delivery) {
          _showError('การจัดส่ง (Delivery) ต้องระบุลูกค้าสมาชิกเท่านั้น');
          return;
        }

        // WARN: General Customer (Pickup Only)
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

    if (remaining > 0.01) {
      bool? confirmDebt = await ConfirmDialog.show(
        context,
        title: '⚠️ ยอดเงินไม่ครบ',
        content:
            'รับเงินมา: ${NumberFormat('#,##0.00').format(totalPaidSoFar)}\n'
            'ขาดอีก: ${NumberFormat('#,##0.00').format(remaining)}\n\n'
            'ต้องการบันทึกส่วนที่เหลือเป็น "หนี้ค้างจ่าย" ใช่หรือไม่?',
        confirmText: 'ใช่, บันทึกเป็นหนี้',
        cancelText: 'ไม่, กลับไปแก้ไข',
        isDestructive: false,
      );

      if (confirmDebt != true) return;

      if (currentInput > 0) {
        _payments.add(PaymentRecord(
            method: _selectedPaymentType.name, amount: currentInput));
      }
      _payments.add(
          PaymentRecord(method: PaymentType.credit.name, amount: remaining));

      _amountCtrl.clear();
      _receivedAmount = 0;
    } else {
      if (currentInput > 0) {
        _payments.add(PaymentRecord(
          method: _selectedPaymentType.name,
          amount: currentInput,
        ));
        _amountCtrl.clear();
        _receivedAmount = 0;
      }
    }

    // Final calculations for Change/Received
    double totalReceived = _payments.fold(0.0, (sum, p) => sum + p.amount);
    double change =
        _round((totalReceived - grandTotal).clamp(0.0, double.infinity));

    setState(() => _isLoading = true);
    try {
      // 1. Save Order (Returns ID)
      final orderId = await posState.saveOrder(
        payments: _payments,
        deliveryType: _deliveryType,
      );

      // 2. Print Receipt using SNAPSHOT data (Safe & Accurate)
      // ✅ Check local toggle first
      if (_shouldPrint) {
        await _printReceipt(
          orderId: orderId,
          items: snapshotItems,
          customer: snapshotCustomer,
          total: snapshotTotal,
          discount: snapshotDiscount,
          grandTotal: grandTotal,
          received: totalReceived,
          change: change,
          payments: _payments,
          cashierName: posState.currentUser?.displayName ??
              'Staff', // ✅ Pass Cashier Name
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
    String? cashierName, // ✅ Receive Cashier Name
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
        // ✅ Auto-print Delivery Note for Credit Sales
        await _receiptService.printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: discount,
        );
      } else {
        // ✅ Standard Receipt for Cash/Mixed
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
          cashierName: cashierName, // ✅ Pass to Service
        );
      }
    } catch (e) {
      debugPrint("Print Error: $e");
    }
  }

  Widget _buildInfoColumn(String label, double val, Color color,
      {double fontSize = 28}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Text(
          '฿${NumberFormat('#,##0.00').format(val)}',
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
    // ... UI Code remains largely similar but uses _round() on calculations ...
    // Focusing on Logic fix. UI parts below are standard.
    final posState = context.watch<PosStateManager>();
    final grandTotal = posState.grandTotal;

    final totalPaidInList = _totalPaid;
    final currentlyTyping = _receivedAmount;
    final totalCaptured = _round(totalPaidInList + currentlyTyping);

    final remaining =
        _round((grandTotal - totalCaptured).clamp(0.0, double.infinity));
    final change =
        _round((totalCaptured - grandTotal).clamp(0.0, double.infinity));
    final isFullyPaid = totalCaptured >= grandTotal - 0.01; // Tolerance

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                Navigator.pop(context);
              },
              // ✅ F12: Finish without Printing
              const SingleActivator(LogicalKeyboardKey.f12): () {
                if (!_isLoading) {
                  setState(() => _shouldPrint = false); // Visual feedback
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
                    // ... Header ...
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

                    // ... Summary Box ...
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

                    // ... Input & Buttons (Same as original) ...
                    // Only displaying Input logic to show controller usage
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
                                    _receivedAmount =
                                        double.tryParse(val) ?? 0.0;
                                    _updateDisplayToCustomer(); // ✅ Update Display
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ... Segments & List ...
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
                            _receivedAmount = 0;
                            _amountCtrl.clear();
                            FocusScope.of(context).unfocus();
                          } else {
                            _amountFocusNode.requestFocus();
                          }
                          _updateDisplayToCustomer(); // ✅ Update Display
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // List of Payments (Hidden detail, same as original)
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

                    // Bottom Buttons
                    Row(
                      children: [
                        // ... Delivery Type ...
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
                        // ✅ Print Toggle Checkbox
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

  // ✅ Helper to Sync Data to Customer Display
  // ✅ Helper to Sync Data to Customer Display
  void _updateDisplayToCustomer() {
    final posState = Provider.of<PosStateManager>(context, listen: false);
    final currentInput = _receivedAmount; // ยอดที่กำลังกรอก
    final totalPaidInList = _totalPaid; // ยอดที่จ่ายไปแล้ว (รายการก่อนหน้า)
    final totalCaptured = _round(totalPaidInList + currentInput);

    final change = _round(
        (totalCaptured - posState.grandTotal).clamp(0.0, double.infinity));

    if (_selectedPaymentType == PaymentType.qr) {
      // ถ้าเลือก QR ให้ส่ง State Payment (Show QR)
      // ใช้ currentInput หรือ ยอดขาด (remaining) เป็นยอด QR
      double qrAmount = currentInput;
      if (qrAmount <= 0) {
        // ถ้าไม่ได้กรอก ให้คำนวณจากยอดคงเหลือ
        final remaining = _round((posState.grandTotal - totalPaidInList)
            .clamp(0.0, double.infinity));
        qrAmount = remaining;
      }

      // เรียก showPaymentQr (ซึ่งจะไปเขียนไฟล์ state: payment)
      posState.showPaymentQr(qrAmount);
      // หมายเหตุ: showPaymentQr ใน PosState ปัจจุบันยัง hardcode received/change
      // แต่เป้าหมายหลักคือให้ QR ขึ้นก่อน เรื่องตัวเลข received ค่อยว่ากัน
    } else {
      // ถ้าโหมดอื่น ให้ส่ง State Active ปกติ
      posState.updateCustomerDisplay(received: totalCaptured, change: change);
    }
  }
}
