import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decimal/decimal.dart';

import 'pos_state_manager.dart';
import 'pos_payment_panel.dart';

import 'payment_modal/widgets/payment_summary_section.dart';
import 'payment_modal/widgets/payment_coupon_section.dart';
import 'payment_modal/widgets/payment_point_section.dart';
import 'payment_modal/widgets/payment_method_input_section.dart';
import 'payment_modal/widgets/payments_list_footer.dart';

import 'payment_modal/controllers/coupon_controller.dart';
import 'payment_modal/controllers/slip_verification_controller.dart';
import 'payment_modal/controllers/payment_modal_controller.dart';

import '../../services/settings_service.dart';

class PaymentModal extends ConsumerStatefulWidget {
  final VoidCallback onPaymentSuccess;

  const PaymentModal({super.key, required this.onPaymentSuccess});

  @override
  ConsumerState<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends ConsumerState<PaymentModal>
    with
        CouponControllerMixin,
        SlipVerificationControllerMixin,
        PaymentModalControllerMixin {
  @override
  void initState() {
    super.initState();
    amountFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.space) {
          final posState = ref.read(posProvider.notifier);
          fillRemainingAmount(posState);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyV &&
            HardwareKeyboard.instance.isControlPressed) {
          final posState = ref.read(posProvider.notifier);
          handlePaste(posState);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountFocusNode.requestFocus();
      final posState = ref.read(posProvider.notifier);
      fillRemainingAmount(posState);
    });
  }

  @override
  void dispose() {
    disposePaymentController();
    disposeCouponController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(posProvider);
    final posState = ref.read(posProvider.notifier);
    final Decimal grandTotal = Decimal.parse(posState.grandTotal.toString());

    final Decimal totalPaidInList = totalPaid;
    final Decimal currentlyTyping = receivedAmount;
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
            if (!isLoading) {
              setState(() => shouldPrint = false);
              processFinish(posState);
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 800, minHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        PaymentSummarySection(
                          grandTotal: grandTotal,
                          totalPaid: totalCaptured,
                          remaining: remaining,
                          change: change,
                          isFullyPaid: isFullyPaid,
                        ),
                        const SizedBox(height: 12),
                        PaymentPointSection(
                          customer: posState.currentCustomer,
                          pointsToRedeem: posState.pointsToRedeem.toInt(),
                          pointDiscountAmount: posState.pointDiscountAmount,
                          onOpenRedemptionDialog: () {
                            final settings = SettingsService();
                            openPointRedemptionDialog(posState, settings);
                          },
                        ),
                        PaymentCouponSection(
                          couponCtrl: couponCtrl,
                          couponApplied: couponApplied,
                          isValidatingCoupon: isValidatingCoupon,
                          couponResult: couponResult,
                          onClearCoupon: () => clearCoupon(posState),
                          onValidateCoupon: () => validateAndApplyCoupon(
                              posState, () => fillRemainingAmount(posState)),
                          onChanged: (v) =>
                              setState(() => couponResult = null),
                        ),
                        PaymentMethodInputSection(
                          amountCtrl: amountCtrl,
                          amountFocusNode: amountFocusNode,
                          selectedPaymentType: selectedPaymentType,
                          isVerifyingSlip: isVerifyingSlip,
                          slipVerificationMsg: slipVerificationMsg,
                          slipVerificationSuccess: slipVerificationSuccess,
                          noteCtrl: noteCtrl,
                          onAmountChanged: (val) {
                            setState(() {
                              if (val.isEmpty) {
                                receivedAmount = Decimal.zero;
                              } else {
                                receivedAmount =
                                    Decimal.tryParse(val) ?? Decimal.zero;
                              }
                              updateDisplayToCustomer(posState);
                            });
                          },
                          onAmountSubmitted: (_) => processFinish(posState),
                          onPaymentTypeChanged: (type) {
                            setState(() {
                              selectedPaymentType = type;
                              if (selectedPaymentType == PaymentType.credit) {
                                receivedAmount = Decimal.zero;
                                amountCtrl.clear();
                                FocusScope.of(context).unfocus();
                              } else {
                                amountFocusNode.requestFocus();
                              }
                              updateDisplayToCustomer(posState);
                            });
                          },
                          onVerifySlip: () => pickAndVerifySlip(
                            posState: posState,
                            receivedAmount: receivedAmount,
                            totalPaid: totalPaid,
                            onValidAmountApplied: (amount) {
                              receivedAmount = amount;
                              amountCtrl.text =
                                  amount.toDouble().toStringAsFixed(2);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                PaymentsListFooter(
                  payments: payments,
                  deliveryType: deliveryType,
                  shouldPrint: shouldPrint,
                  isLoading: isLoading,
                  isFullyPaid: isFullyPaid,
                  selectedPaymentType: selectedPaymentType,
                  receivedAmount: receivedAmount,
                  onRemovePayment: (i) => removePayment(i, posState),
                  onDeliveryTypeChanged: (val) =>
                      setState(() => deliveryType = val),
                  onShouldPrintChanged: (val) =>
                      setState(() => shouldPrint = val ?? true),
                  onProcessFinish: () => processFinish(posState),
                  onAddPayment: () => addPayment(posState),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
