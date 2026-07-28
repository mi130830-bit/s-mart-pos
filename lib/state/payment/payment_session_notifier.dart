import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';

import '../../models/payment_record.dart';
import '../../models/payment/payment_type.dart';
import '../../models/delivery_type.dart';

@immutable
class PaymentSessionState {
  final List<PaymentRecord> payments;
  final PaymentType selectedPaymentType;
  final Decimal receivedAmount;
  final DeliveryType deliveryType;
  final bool isLoading;
  final bool shouldPrint;

  const PaymentSessionState({
    required this.payments,
    required this.selectedPaymentType,
    required this.receivedAmount,
    required this.deliveryType,
    required this.isLoading,
    required this.shouldPrint,
  });

  PaymentSessionState copyWith({
    List<PaymentRecord>? payments,
    PaymentType? selectedPaymentType,
    Decimal? receivedAmount,
    DeliveryType? deliveryType,
    bool? isLoading,
    bool? shouldPrint,
  }) {
    return PaymentSessionState(
      payments: payments ?? this.payments,
      selectedPaymentType: selectedPaymentType ?? this.selectedPaymentType,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      deliveryType: deliveryType ?? this.deliveryType,
      isLoading: isLoading ?? this.isLoading,
      shouldPrint: shouldPrint ?? this.shouldPrint,
    );
  }
}

final paymentSessionProvider =
    NotifierProvider.autoDispose<PaymentSessionNotifier, PaymentSessionState>(
  PaymentSessionNotifier.new,
);

class PaymentSessionNotifier extends AutoDisposeNotifier<PaymentSessionState> {
  @override
  PaymentSessionState build() {
    return PaymentSessionState(
      payments: [],
      selectedPaymentType: PaymentType.cash,
      receivedAmount: Decimal.zero,
      deliveryType: DeliveryType.none,
      isLoading: false,
      shouldPrint: true,
    );
  }

  Decimal get totalPaid => state.payments.fold(
      Decimal.zero, (sum, p) => sum + Decimal.parse(p.amount.toString()));

  void addPayment() {
    if (state.selectedPaymentType == PaymentType.credit) return;

    final Decimal currentInput = state.receivedAmount;
    if (currentInput <= Decimal.zero) return;

    final newPayments = List<PaymentRecord>.from(state.payments)
      ..add(PaymentRecord(
        method: state.selectedPaymentType.name,
        amount: currentInput.toDouble(),
      ));

    state = state.copyWith(
      payments: newPayments,
      receivedAmount: Decimal.zero,
    );
  }

  void removePayment(int index) {
    if (index >= 0 && index < state.payments.length) {
      final newPayments = List<PaymentRecord>.from(state.payments)
        ..removeAt(index);
      state = state.copyWith(payments: newPayments);
    }
  }

  void fillRemainingAmount(Decimal grandTotal) {
    if (state.selectedPaymentType == PaymentType.credit) {
      return;
    }

    final Decimal paid = totalPaid;
    final Decimal remaining = (grandTotal - paid)
        .clamp(Decimal.zero, Decimal.parse('999999999')); // Clamp max safe

    state = state.copyWith(
      receivedAmount: remaining,
    );
  }

  void setReceivedAmount(Decimal amount) {
    state = state.copyWith(receivedAmount: amount);
  }

  void setPaymentType(PaymentType type) {
    state = state.copyWith(selectedPaymentType: type);
  }

  void setDeliveryType(DeliveryType type) {
    state = state.copyWith(deliveryType: type);
  }

  void setShouldPrint(bool value) {
    state = state.copyWith(shouldPrint: value);
  }

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void reset() {
    state = build();
  }
}
