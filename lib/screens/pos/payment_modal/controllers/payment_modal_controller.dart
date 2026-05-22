import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';
import 'package:pasteboard/pasteboard.dart';
import '../../../../services/alert_service.dart';
import '../../../../services/settings_service.dart';
import '../../../../services/mysql_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/logger_service.dart';
import '../../../../services/printing/receipt_service.dart';
import '../../../../models/payment_record.dart';
import '../../../../models/delivery_type.dart';
import '../../../../models/order_item.dart';
import '../../../../models/customer.dart';
import '../../pos_state_manager.dart';
import '../../pos_payment_panel.dart';
import '../../../../widgets/common/confirm_dialog.dart';
import '../../../../widgets/dialogs/point_redemption_dialog.dart';
import '../../../../utils/pos_reprint_barcode_router.dart';
import 'slip_verification_controller.dart';
import '../widgets/reprint_dialog.dart';

mixin PaymentModalControllerMixin<T extends StatefulWidget>
    on State<T>, SlipVerificationControllerMixin<T> {
  final ReceiptService receiptService = ReceiptService();
  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();

  final List<PaymentRecord> payments = [];

  Decimal get totalPaid => payments.fold(
      Decimal.zero, (sum, p) => sum + Decimal.parse(p.amount.toString()));

  PaymentType selectedPaymentType = PaymentType.cash;
  Decimal receivedAmount = Decimal.zero;
  DeliveryType deliveryType = DeliveryType.none;
  bool isLoading = false;
  bool shouldPrint = true;

  void disposePaymentController() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    amountFocusNode.dispose();
  }

  void fillRemainingAmount(PosStateNotifier posState) {
    if (selectedPaymentType == PaymentType.credit) return;

    final Decimal total = Decimal.parse(posState.grandTotal.toString());
    final Decimal paid = totalPaid;
    final Decimal remaining = (total - paid)
        .clamp(Decimal.zero, Decimal.parse('999999999')); // Clamp max safe

    if (remaining > Decimal.zero) {
      setState(() {
        receivedAmount = remaining;
        amountCtrl.text = remaining.toDouble().toStringAsFixed(2);
        amountCtrl.selection =
            TextSelection(baseOffset: 0, extentOffset: amountCtrl.text.length);
      });
    } else {
      setState(() {
        receivedAmount = Decimal.zero;
        amountCtrl.text = '';
      });
    }
    updateDisplayToCustomer(posState);
  }

  void removePayment(int index, PosStateNotifier posState) {
    setState(() {
      payments.removeAt(index);
      fillRemainingAmount(posState);
      updateDisplayToCustomer(posState);
    });
  }

  Future<void> handlePaste(PosStateNotifier posState) async {
    if (isVerifyingSlip) return;
    if (selectedPaymentType != PaymentType.qr) {
      setState(() => selectedPaymentType = PaymentType.qr);
    }

    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null) {
        verifySlipFromBytes(
          bytes: imageBytes,
          posState: posState,
          receivedAmount: receivedAmount,
          totalPaid: totalPaid,
          onValidAmountApplied: (amount) {
            receivedAmount = amount;
            amountCtrl.text = amount.toDouble().toStringAsFixed(2);
          },
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('PaymentModal', 'Paste Error: $e', e, stackTrace);
      showError('ไม่สามารถดึงรูปภาพสลิปจากคลิปบอร์ดได้: $e');
    }
  }

  void updateDisplayToCustomer(PosStateNotifier posState) {
    final Decimal currentInput = receivedAmount;
    final Decimal totalPaidInList = totalPaid;
    final Decimal totalCaptured = totalPaidInList + currentInput;

    final Decimal grandTotal = Decimal.parse(posState.grandTotal.toString());
    Decimal change = Decimal.zero;
    if (totalCaptured > grandTotal) {
      change = totalCaptured - grandTotal;
    }

    if (selectedPaymentType == PaymentType.qr) {
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

  void addPayment(PosStateNotifier posState) {
    if (selectedPaymentType == PaymentType.credit) return;

    final Decimal currentInput = receivedAmount;
    if (currentInput <= Decimal.zero) return;

    setState(() {
      payments.add(PaymentRecord(
        method: selectedPaymentType.name,
        amount: currentInput.toDouble(),
      ));

      amountCtrl.clear();
      receivedAmount = Decimal.zero;
    });

    fillRemainingAmount(posState);
  }

  void showError(String msg) {
    final activeContext = mounted ? context : AlertService.navigatorKey.currentContext;
    if (activeContext != null) {
      AlertService.show(context: activeContext, message: msg, type: 'error');
    } else {
      LoggerService.warning('PaymentModal', 'Cannot show error dialog (unmounted and no root context): $msg');
    }
  }

  Future<void> openPointRedemptionDialog(
      PosStateNotifier posState, SettingsService settings) async {
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
      fillRemainingAmount(posState);
    }
  }

  Future<void> printReceipt({
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
    String? remark,
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
        await receiptService.printDeliveryNote(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: discount,
          remark: remark,
        );
      } else {
        await receiptService.printReceipt(
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
          remark: remark,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('PaymentModal', 'Print Error: $e', e, stackTrace);
      showError('พิมพ์ใบเสร็จไม่สำเร็จ: $e');
    }
  }

  Future<void> sendLineNotifications({
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

      bool isCreditOnly = !hasCash &&
          (payments?.any((p) =>
                  p.method.toUpperCase().contains('CREDIT') ||
                  p.method == 'เงินเชื่อ' ||
                  p.method == 'Credit') ??
              false);

      LoggerService.info('PaymentModal', '📤 [Line] Capturing receipt/delivery image for #$orderId');

      Uint8List? imageBytes;
      if (isCreditOnly) {
        imageBytes = await receiptService.captureDeliveryNoteImage(
          orderId: orderId,
          items: items,
          customer: customer,
          discount: 0,
        );
      } else {
        imageBytes = await receiptService.captureReceiptImage(
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
        LoggerService.warning(
            'PaymentModal', '⚠️ [Line] Receipt image capture returned null for #$orderId');
        showError('ไม่สามารถสร้างรูปภาพสลิปเพื่อส่ง Line ได้');
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

      LoggerService.info('PaymentModal', '📤 [Line] Sending receipt image for #$orderId → $lineUserId');
      final result = await firebaseSvc.sendLineReceiptImageDirect(
        db: db,
        orderId: orderId,
        lineUserId: lineUserId,
        url: url,
        base64Image: base64Image,
      );
      if (!result) {
        showError('ส่งสลิปผ่าน Line ไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต');
      }
    } catch (e, stackTrace) {
      LoggerService.error('PaymentModal', '❌ [Line] sendLineNotifications error: $e', e, stackTrace);
      showError('ไม่สามารถส่ง Line ใบเสร็จได้: $e');
    }
  }

  Future<void> processFinish(PosStateNotifier posState) async {
    if (isLoading) return;

    final double grandTotalDouble = posState.grandTotal;
    final Decimal grandTotal = Decimal.parse(grandTotalDouble.toString());

    final snapshotItems = List<OrderItem>.from(posState.cart);
    final snapshotCustomer = posState.currentCustomer;
    final snapshotDiscount = posState.discountAmount;
    final snapshotTotal = posState.grandTotal + snapshotDiscount;

    Decimal currentInput = receivedAmount;
    Decimal totalPaidSoFar = totalPaid + currentInput;
    Decimal remaining = (grandTotal - totalPaidSoFar);

    if (remaining > Decimal.parse('0.01')) {
      if (posState.currentCustomer == null ||
          posState.currentCustomer!.id == 0) {
        showError('ลูกค้าทั่วไปไม่สามารถค้างจ่ายได้ (กรุณาเลือกสมาชิก)');
        return;
      }
    }

    if (deliveryType != DeliveryType.none) {
      if (posState.currentCustomer == null ||
          posState.currentCustomer?.id == 0) {
        if (deliveryType == DeliveryType.delivery) {
          showError('การจัดส่ง (Delivery) ต้องระบุลูกค้าสมาชิกเท่านั้น');
          return;
        }
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

      if (!mounted) return;
      if (confirmDebt != true) return;

      if (currentInput > Decimal.zero) {
        payments.add(PaymentRecord(
            method: selectedPaymentType.name,
            amount: currentInput.toDouble()));
      }
      payments.add(PaymentRecord(
          method: PaymentType.credit.name, amount: remaining.toDouble()));

      amountCtrl.clear();
      receivedAmount = Decimal.zero;
    } else {
      if (currentInput > Decimal.zero) {
        payments.add(PaymentRecord(
          method: selectedPaymentType.name,
          amount: currentInput.toDouble(),
        ));
        amountCtrl.clear();
        receivedAmount = Decimal.zero;
      }
    }

    Decimal totalReceived = payments.fold(
        Decimal.zero, (sum, p) => sum + Decimal.parse(p.amount.toString()));
    Decimal change = Decimal.zero;
    if (totalReceived > grandTotal) {
      change = totalReceived - grandTotal;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      final orderId = await posState.saveOrder(
        payments: payments,
        deliveryType: deliveryType,
        note: noteCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }

      if (shouldPrint) {
        final String cashierName = posState.currentUser?.displayName ?? 'Staff';

        printReceipt(
          orderId: orderId,
          items: snapshotItems,
          customer: snapshotCustomer,
          total: snapshotTotal,
          discount: snapshotDiscount,
          grandTotal: grandTotalDouble,
          received: totalReceived.toDouble(),
          change: change.toDouble(),
          payments: payments,
          cashierName: cashierName,
          remark: noteCtrl.text.trim(),
        );
      }

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
        } catch (e, stackTrace) {
          LoggerService.error('PaymentModal', '⚠️ Fetch DB Line ID Error: $e', e, stackTrace);
        }
      }

      if (hasLineId && effCustomer != null) {
        final String cashierName = posState.currentUser?.displayName ?? 'Staff';
        sendLineNotifications(
          orderId: orderId,
          customer: effCustomer,
          items: snapshotItems,
          total: snapshotTotal,
          grandTotal: grandTotalDouble,
          received: totalReceived.toDouble(),
          change: change.toDouble(),
          payments: payments,
          cashierName: cashierName,
        );
      }

      final bool hasCashPayment = payments.any((p) =>
          p.method.toUpperCase().contains('CASH') ||
          p.method.toUpperCase().contains('TRANSFER') ||
          p.method.toUpperCase().contains('QR') ||
          p.method == 'เงินสด' ||
          p.method.contains('โอน'));
      final bool isCreditOnlyReprint = !hasCashPayment &&
          payments.any((p) =>
              p.method.toUpperCase().contains('CREDIT') ||
              p.method == 'เงินเชื่อ' ||
              p.method == 'Credit');

      if (!isCreditOnlyReprint) {
        final rootContext = AlertService.navigatorKey.currentContext;
        if (rootContext != null && rootContext.mounted) {
          final cashierNameStr = posState.currentUser?.displayName ?? 'Staff';
          final paymentsSnapshot = List<PaymentRecord>.from(payments);

          showDialog(
            context: rootContext,
            builder: (_) => ReprintDialog(
              orderId: orderId,
              items: snapshotItems,
              customer: snapshotCustomer,
              total: snapshotTotal,
              discount: snapshotDiscount,
              grandTotal: grandTotalDouble,
              received: totalReceived.toDouble(),
              change: change.toDouble(),
              payments: paymentsSnapshot,
              cashierName: cashierNameStr,
              receiptService: receiptService,
              onBarcodeScanned: (barcode, _) {
                Future.delayed(const Duration(milliseconds: 150), () {
                  LoggerService.info('PaymentModal',
                      '📦 [Reprint Dialog] Forwarding barcode to POS: $barcode');
                  PosReprintBarcodeRouter.broadcast(barcode);
                });
              },
            ),
          );
        }
      } else {
        LoggerService.info('PaymentModal', 'ℹ️ [Reprint] isCreditOnlyReprint=true — ข้าม Reprint Dialog');
      }

    } catch (e, stackTrace) {
      LoggerService.error('PaymentModal', 'เกิดข้อผิดพลาดในการบันทึกบิล: $e', e, stackTrace);
      showError('เกิดข้อผิดพลาด: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
}
