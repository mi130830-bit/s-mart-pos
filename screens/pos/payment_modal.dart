import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart'; // ✅ Import Decimal
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart'; // ✅ Import Pasteboard
import '../../services/alert_service.dart';
import '../../services/settings_service.dart'; // ✅ Import Settings
import '../../services/mysql_service.dart'; // ✅ For Notification Logging
import '../../services/firebase_service.dart'; // ✅ For Line Push + Log
import '../../models/payment_record.dart';
import '../../models/delivery_type.dart';
import '../../models/order_item.dart';
import '../../models/customer.dart';
import 'pos_state_manager.dart';
import 'pos_payment_panel.dart';
import '../../services/printing/receipt_service.dart';
import '../../widgets/common/custom_buttons.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/dialogs/point_redemption_dialog.dart'; // ✅ Point Dialog
import '../../repositories/reward_repository.dart'; // ✅ Coupon Validation

class PaymentModal extends StatefulWidget {
  final VoidCallback onPaymentSuccess;

  const PaymentModal({super.key, required this.onPaymentSuccess});

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  final ReceiptService _receiptService = ReceiptService();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl =
      TextEditingController(); // ✅ Note Controller
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

  // Slip Verification
  bool _isVerifyingSlip = false;
  String? _slipVerificationMsg;
  bool? _slipVerificationSuccess;

  // ✅ Coupon
  final TextEditingController _couponCtrl = TextEditingController();
  bool _isValidatingCoupon = false;
  CouponValidationResult? _couponResult;
  bool _couponApplied = false;

  @override
  void initState() {
    super.initState();
    _amountFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.space) {
          _fillRemainingAmount();
          return KeyEventResult.handled;
        }
        // ✅ Detect Ctrl+V
        if (event.logicalKey == LogicalKeyboardKey.keyV &&
            HardwareKeyboard.instance.isControlPressed) {
          _handlePaste();
          return KeyEventResult.handled;
        }
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
    _noteCtrl.dispose();
    _couponCtrl.dispose(); // ✅ Coupon
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

  // ✅ Handle Paste (Ctrl+V)
  Future<void> _handlePaste() async {
    if (_isVerifyingSlip) return;
    if (_selectedPaymentType != PaymentType.qr) {
      // Allow paste only for QR payment? Or auto-switch?
      // Let's auto-switch to QR if image pasted
      setState(() => _selectedPaymentType = PaymentType.qr);
    }

    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null) {
        _verifySlipFromBytes(imageBytes);
      } else {
        // Optionally show toast "No image in clipboard"
      }
    } catch (e) {
      debugPrint('Paste Error: $e');
    }
  }

  // ✅ Refactored Verification Logic to accept bytes
  Future<void> _verifySlipFromBytes(Uint8List bytes) async {
    setState(() {
      _isVerifyingSlip = true;
      _slipVerificationMsg = 'กำลังตรวจสอบสลิป...';
      _slipVerificationSuccess = null;
    });

    try {
      final base64Image = base64Encode(bytes);

      if (!mounted) return;

      final posState = Provider.of<PosStateManager>(context, listen: false);
      final Decimal grandTotal = Decimal.parse(posState.grandTotal.toString());
      // Calculate Amount to verify (Remaining or Entered)
      Decimal amountToVerify = _receivedAmount;
      if (amountToVerify <= Decimal.zero) {
        amountToVerify = grandTotal - _totalPaid;
      }

      final apiUrl =
          Uri.parse('http://localhost:8080/api/v1/payment/verify-slip');

      final response = await http.post(
        apiUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'amount': amountToVerify.toDouble(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _slipVerificationSuccess = data['success'] == true;
          _slipVerificationMsg = data['message'];

          if (_slipVerificationSuccess == true) {
            if (_receivedAmount <= Decimal.zero) {
              _receivedAmount = amountToVerify;
              _amountCtrl.text = amountToVerify.toDouble().toStringAsFixed(2);
            }
          }
        });
      } else {
        setState(() {
          _slipVerificationSuccess = false;
          _slipVerificationMsg = 'Server Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _slipVerificationSuccess = false;
        _slipVerificationMsg = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => _isVerifyingSlip = false);
    }
  }

  Future<void> _pickAndVerifySlip() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        _verifySlipFromBytes(bytes); // Use shared logic
      }
    } catch (e) {
      // Error handling inside shared logic mostly, but file pick specific here
    }
  }

  void _addPayment() {
    if (_selectedPaymentType == PaymentType.credit) return;

    final Decimal currentInput = _receivedAmount;
    if (currentInput <= Decimal.zero) return;

    setState(() {
      _payments.add(PaymentRecord(
        method: _selectedPaymentType.name,
        amount: currentInput.toDouble(),
      ));

      // Reset input for next payment
      _amountCtrl.clear();
      _receivedAmount = Decimal.zero;
    });

    // Auto-fill remaining for convenience (Calls its own setState)
    _fillRemainingAmount();
  }

  Future<void> _processFinish() async {
    // 1. Prevent Double Submission
    if (_isLoading) return;

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

      if (!mounted) return; // Guard after await
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

    // 2. Start Loading
    if (mounted) setState(() => _isLoading = true);

    try {
      final orderId = await posState.saveOrder(
        payments: _payments,
        deliveryType: _deliveryType,
        note: _noteCtrl.text.trim(), // ✅ Pass Note
      );

      // 3. Success & Safe Close IMMEDIATELY to prevent freeze
      if (mounted) {
        Navigator.of(context).pop(true);
      }

      // 4. Print in Background (Fire & Forget)
      if (_shouldPrint) {
        // ✅ Snapshot Cashier Name before usage
        final String cashierName = posState.currentUser?.displayName ?? 'Staff';

        // Do NOT await here to keep UI snappy.
        // AlertService.navigatorKey handles errors if context is dead.
        _printReceipt(
          orderId: orderId,
          items: snapshotItems,
          customer: snapshotCustomer,
          total: snapshotTotal,
          discount: snapshotDiscount,
          grandTotal: grandTotalDouble,
          received: totalReceived.toDouble(),
          change: change.toDouble(),
          payments: _payments,
          cashierName: cashierName,
          remark: _noteCtrl.text.trim(), // ✅ Pass Note as Remark
        );
      }

      // 5. ✅ Send Line Notifications (Text → Image) Sequential + Logged
      bool hasLineId = snapshotCustomer?.lineUserId != null &&
          snapshotCustomer!.lineUserId!.isNotEmpty;
      Customer? effCustomer = snapshotCustomer;

      if (!hasLineId && snapshotCustomer != null && snapshotCustomer.id != 0) {
        try {
          final db = MySQLService();
          if (!db.isConnected()) await db.connect();
          final res = await db.query(
              'SELECT line_user_id FROM customer WHERE id = :cid',
              {'cid': snapshotCustomer.id});
          if (res.isNotEmpty &&
              res.first['line_user_id'] != null &&
              res.first['line_user_id'].toString().isNotEmpty) {
            effCustomer = snapshotCustomer.copyWith(
                lineUserId: res.first['line_user_id'].toString());
            hasLineId = true;
          }
        } catch (e) {
          debugPrint('⚠️ Fetch DB Line ID Error: $e');
        }
      }

      if (hasLineId && effCustomer != null) {
        final String cashierName = posState.currentUser?.displayName ?? 'Staff';
        // Fire & Forget — ไม่ await เพื่อไม่ block UI
        _sendLineNotifications(
          orderId: orderId,
          customer: effCustomer,
          items: snapshotItems,
          total: snapshotTotal,
          grandTotal: grandTotalDouble,
          received: totalReceived.toDouble(),
          change: change.toDouble(),
          payments: _payments,
          cashierName: cashierName,
        );
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
      setState(() => _isLoading = false);
    }
  }

  /// ✅ ส่ง Line OA: (1) ข้อความสรุปการซื้อ + (2) รูปบิล 80mm
  /// รวมทุกอย่างไว้ที่นี่ ไม่พึ่ง pos_state_manager เพราะ snapshot อาจ expire
  Future<void> _sendLineNotifications({
    required int orderId,
    required Customer customer,
    required List<OrderItem> items,
    required double total,
    required double grandTotal,
    required double received,
    required double change,
    List<PaymentRecord>? payments,
    String? cashierName,
  }) async {
    final String lineUserId = customer.lineUserId!;
    final db = MySQLService();
    final firebaseSvc = FirebaseService();
    final settings = SettingsService();

    try {
      if (!db.isConnected()) await db.connect();

      bool hasCash = payments?.any((p) =>
              p.method.toUpperCase().contains('CASH') ||
              p.method.toUpperCase().contains('TRANSFER') ||
              p.method.toUpperCase().contains('QR') ||
              p.method == 'เงินสด' ||
              p.method.contains('โอน')) ??
          false;

      // ถ้าไม่มีเงินสดเลย แต่มีเครดิต -> เป็นบิลเงินเชื่อ (Credit Only)
      bool isCreditOnly = !hasCash &&
          (payments?.any((p) =>
                  p.method.toUpperCase().contains('CREDIT') ||
                  p.method == 'เงินเชื่อ' ||
                  p.method == 'Credit') ??
              false);

      // ── Step 1: ส่ง Push Scenario Text (REMOVED) ──────
      // ✅ Text notifications are now handled natively inside OrderProcessingService.
      // Doing it here caused duplicate notifications with incorrect 'received' calculations.

      // ── Step 2: Capture และส่งรูปบิล ───────────────────────────
      // ✅ ส่งรูปให้ทุกเคส (รวม Case 2 และ Case 4) ตามความต้องการใหม่

      debugPrint('📤 [Line] Capturing receipt/delivery image for #$orderId');

      Uint8List? imageBytes;
      if (isCreditOnly) {
        // ใช้เป็นใบส่งของ A5 สำหรับบิลเงินเชื่อ
        imageBytes = await _receiptService.captureDeliveryNoteImage(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: 0,
        );
      } else {
        // ใช้บิลสลิป 80mm ปกติ
        imageBytes = await _receiptService.captureReceiptImage(
          orderId: orderId,
          items: items,
          total: total,
          grandTotal: grandTotal,
          received: received,
          change: change,
          payments: payments,
          customer: customer,
          cashierName: cashierName,
        );
      }

      if (imageBytes == null) {
        debugPrint(
            '⚠️ [Line] Receipt image capture returned null for #$orderId');
        return;
      }

      final base64Image = base64Encode(imageBytes);
      String baseUrl = settings.apiUrl;
      if (baseUrl.endsWith('/api/v1')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 7);
      } else if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
      final url = Uri.parse('$baseUrl/api/v1/line/push-receipt-image');

      debugPrint('📤 [Line] Sending receipt image for #$orderId → $lineUserId');
      await firebaseSvc.sendLineReceiptImageDirect(
        db: db,
        orderId: orderId,
        lineUserId: lineUserId,
        url: url,
        base64Image: base64Image,
      );
    } catch (e) {
      debugPrint('❌ [Line] _sendLineNotifications error: $e');
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
    String? remark, // ✅ Added
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
          remark: remark, // ✅ Pass
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
          remark: remark, // ✅ Pass
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
    AlertService.show(context: context, message: msg, type: 'error');
  }

  // ✅ เปิด Point Redemption Dialog
  Future<void> _openPointRedemptionDialog(
      PosStateManager posState, SettingsService settings) async {
    if (posState.currentCustomer == null) return;
    if (!settings.pointEnabled) return;

    final result = await showDialog<int>(
      context: context,
      builder: (_) => PointRedemptionDialog(
        customer: posState.currentCustomer!,
        grandTotal: posState.grandTotal,
        pointRedemptionRate: settings.pointRedemptionRate,
        currentPointsUsed: posState.pointsToRedeem.toInt(),
      ),
    );

    if (result != null && mounted) {
      posState.applyPointDiscount(result);
      _fillRemainingAmount();
    }
  }

  // ✅ ตรวจสอบและใช้คูปองส่วนลด (Phase 2)
  Future<void> _validateAndApplyCoupon(PosStateManager posState) async {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isValidatingCoupon = true;
      _couponResult = null;
    });

    final repo = RewardRepository();
    final result = await repo.validateCoupon(code);

    setState(() {
      _isValidatingCoupon = false;
      _couponResult = result;
    });

    if (result.isValid) {
      // Auto-apply
      posState.applyCouponDiscount(result.discountValue ?? 0, result.couponCode);
      setState(() => _couponApplied = true);
      _fillRemainingAmount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎟️ ใช้คูปอง ${result.couponCode} — ลด ฿${result.discountValue?.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }

  String _getLabelForMethod(String method) {
    try {
      return PaymentType.values.firstWhere((e) => e.name == method).label;
    } catch (_) {
      return method;
    }
  }

  // bool _isSplitMode = false; // ❌ Removed

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
                // height: 700, // ❌ Remove fixed height to prevent overflow or allow shrink
                constraints:
                    const BoxConstraints(maxHeight: 800, minHeight: 600),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // ✅ Allow shrinking
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ชำระเงิน',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context))
                        ]),
                    const Divider(),

                    // ✅ Wrap Scrollable Content in Expanded
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildInfoColumn('ยอดรวมทั้งหมด', grandTotal,
                                      Colors.black87),
                                  _buildDivider(height: 50),
                                  _buildInfoColumn('รับเงินมาแล้ว',
                                      totalCaptured, Colors.blue.shade800),
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
                            const SizedBox(height: 12),

                            // ✅ Point Discount Breakdown + Button
                            Builder(builder: (ctx) {
                              final settings = SettingsService();
                              final customer = posState.currentCustomer;
                              final hasPointsEnabled = settings.pointEnabled;
                              final isRealCustomer = customer != null && customer.id != 1;
                              final pointsAvailable = customer?.currentPoints ?? 0;
                              final pointsUsed = posState.pointsToRedeem.toInt();
                              final pointDiscount = posState.pointDiscountAmount;

                              return Column(
                                children: [
                                  // ปุ่มแลกแต้ม
                                  if (hasPointsEnabled)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: OutlinedButton.icon(
                                        onPressed: isRealCustomer && pointsAvailable > 0
                                            ? () => _openPointRedemptionDialog(posState, settings)
                                            : () {
                                                if (!isRealCustomer) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกลูกค้า (มุมขวาบน) ก่อนใช้แต้ม')));
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลูกค้าท่านนี้ยังไม่มีแต้มเพียงพอ')));
                                                }
                                              },
                                        icon: Icon(
                                            pointsUsed > 0
                                                ? Icons.stars
                                                : Icons.stars_outlined,
                                            color: (isRealCustomer && pointsAvailable > 0) ? Colors.amber.shade700 : Colors.grey),
                                        label: Text(
                                          pointsUsed > 0
                                              ? 'ใช้ $pointsUsed แต้ม = ลด ฿${NumberFormat('#,##0.00').format(pointDiscount)}'
                                              : isRealCustomer 
                                                ? 'แลกแต้มโดยตรง (ลูกค้ามี ${NumberFormat('#,##0').format(pointsAvailable)} แต้ม)'
                                                : 'แลกแต้ม (เฉพาะสมาชิก)',
                                          style: TextStyle(
                                              color: (isRealCustomer && pointsAvailable > 0) ? Colors.amber.shade800 : Colors.grey.shade700,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: (isRealCustomer && pointsAvailable > 0) ? Colors.amber.shade400 : Colors.grey.shade400,
                                              width: 1.5),
                                          minimumSize: const Size(double.infinity, 44),
                                        ),
                                      ),
                                    ), // <-- This is the missing bracket that I deleted!
                                    // ปุ่มแลกของรางวัล (Coming Soon)
                                    if (hasPointsEnabled && (isRealCustomer && pointsAvailable > 0))
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('🕒 ระบบแคตตาล็อกแลกของรางวัลกำลังพัฒนาสำหรับ Line Web-App พบกันเร็วๆ นี้!'),
                                                backgroundColor: Colors.blue,
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.card_giftcard, color: Colors.blueAccent),
                                          label: const Text(
                                            'แคตตาล็อกแลกของรางวัล',
                                            style: TextStyle(
                                                color: Colors.blueAccent,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                                color: Colors.blue.shade300,
                                                width: 1.5),
                                            minimumSize:
                                                const Size(double.infinity, 44),
                                          ),
                                        ),
                                      ), // <-- third brace
                                    // แสดงส่วนลดเมื่อใช้แต้ม
                                  if (pointsUsed > 0)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.amber.shade300),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(children: [
                                            Icon(Icons.star, color: Colors.amber, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                                "สวนลดแตม: $pointsUsed แตม",
                                                style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ]),
                                          Text(
                                            "- ${NumberFormat('#,##0.00').format(pointDiscount)}",
                                            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }),

                            // ✅ Coupon Discount Section
                            Builder(builder: (ctx) {
                              final posState = Provider.of<PosStateManager>(ctx, listen: false);
                              return Column(children: [
                                // Coupon Input Row
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _couponCtrl,
                                        textCapitalization: TextCapitalization.characters,
                                        enabled: !_couponApplied,
                                        decoration: InputDecoration(
                                          labelText: '🎟️ รหัสคูปองส่วนลด',
                                          hintText: 'สแกน QR หรือพิมพ์รหัส เช่น SMR-XXXX-XXXX',
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.discount_outlined),
                                          suffixIcon: _couponApplied
                                              ? IconButton(
                                                  icon: const Icon(Icons.close, color: Colors.red),
                                                  onPressed: () {
                                                    setState(() {
                                                      _couponApplied = false;
                                                      _couponResult = null;
                                                      _couponCtrl.clear();
                                                      posState.applyCouponDiscount(0, null);
                                                    });
                                                  },
                                                )
                                              : null,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          filled: _couponApplied,
                                          fillColor: _couponApplied ? Colors.green.shade50 : null,
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: _couponApplied ? Colors.green : Colors.grey.shade400),
                                          ),
                                        ),
                                        onChanged: (v) => setState(() => _couponResult = null),
                                        onSubmitted: (_) => _validateAndApplyCoupon(posState),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _couponApplied || _isValidatingCoupon ? null : () => _validateAndApplyCoupon(posState),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      child: _isValidatingCoupon
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Text('ตรวจสอบ', style: TextStyle(color: Colors.white)),
                                    ),
                                  ]),
                                ),
                                // Coupon validation result
                                if (_couponResult != null && !_couponResult!.isValid)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(children: [
                                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                      const SizedBox(width: 8),
                                      Text(_couponResult!.error ?? '', style: const TextStyle(color: Colors.red, fontSize: 13)),
                                    ]),
                                  ),
                                if (_couponApplied && _couponResult != null)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.discount, color: Colors.green, size: 18),
                                          const SizedBox(width: 6),
                                          Text('คูปอง: ${_couponResult!.couponCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ]),
                                        Text('- ฿${NumberFormat("#,##0.00").format(_couponResult!.discountValue ?? 0)}',
                                            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                                  ),
                              ]);
                            }),

                            const Text("ใสจำนวนเงนทรบมา",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _amountCtrl,
                                    focusNode: _amountFocusNode,
                                    textAlign: TextAlign.center,
                                    readOnly: _selectedPaymentType ==
                                        PaymentType.credit,
                                    style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedPaymentType ==
                                                PaymentType.credit
                                            ? Colors.grey
                                            : Colors.blue),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: _selectedPaymentType ==
                                              PaymentType.credit
                                          ? Colors.grey.shade200
                                          : Colors.white,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      prefixText: _selectedPaymentType ==
                                              PaymentType.credit
                                          ? ''
                                          : '฿ ',
                                      labelText: _selectedPaymentType ==
                                              PaymentType.credit
                                          ? 'ไม่ต้องใส่ยอดเงิน (บันทึกหนี้)'
                                          : 'รับเงินสด (Space = ยอดพอดี)',
                                      hintText: _selectedPaymentType ==
                                              PaymentType.credit
                                          ? '-'
                                          : '0.00',
                                    ),
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[0-9.]'))
                                    ],
                                    onSubmitted: (_) {
                                      _processFinish();
                                    },
                                    onChanged: (val) {
                                      setState(() {
                                        if (val.isEmpty) {
                                          _receivedAmount = Decimal.zero;
                                        } else {
                                          _receivedAmount =
                                              Decimal.tryParse(val) ??
                                                  Decimal.zero;
                                        }
                                        _updateDisplayToCustomer();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_selectedPaymentType == PaymentType.qr) ...[
                              Row(
                                children: [
                                  Expanded(
                                      child: OutlinedButton.icon(
                                    onPressed: _isVerifyingSlip
                                        ? null
                                        : _pickAndVerifySlip,
                                    icon: _isVerifyingSlip
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : Icon(Icons.upload_file),
                                    label: Text(_isVerifyingSlip
                                        ? 'กำลังตรวจสอบ...'
                                        : 'แนบสลิป (Verify Slip)'),
                                    style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.all(16)),
                                  )),
                                ],
                              ),
                              if (_slipVerificationMsg != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _slipVerificationSuccess == true
                                            ? Icons.check_circle
                                            : Icons.error,
                                        color: _slipVerificationSuccess == true
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(_slipVerificationMsg!,
                                              style: TextStyle(
                                                  color:
                                                      _slipVerificationSuccess ==
                                                              true
                                                          ? Colors.green
                                                          : Colors.red,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ],
                                  ),
                                )
                            ],
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
                                  if (_selectedPaymentType ==
                                      PaymentType.credit) {
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
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: TextField(
                                controller: _noteCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'หมายเหตุเพิ่มเติม (Note)',
                                  hintText: 'Note',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.note_alt_outlined),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
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
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
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
                          ],
                        ),
                      ),
                    ),

                    // ✅ Footer (Fixed at bottom)
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
                          width: 160,
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
                        ),
                        // ✅ Add Partial Payment Button (Always visible if amount > 0)
                        if (!isFullyPaid &&
                            _selectedPaymentType != PaymentType.credit &&
                            _receivedAmount > Decimal.zero) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 56,
                            width: 140,
                            child: OutlinedButton.icon(
                              onPressed: _addPayment,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('รับเงินเพิ่ม\n(Split)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ]
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


