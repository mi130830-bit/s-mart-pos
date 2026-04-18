// last_order_info.dart
// รวมข้อมูลออเดอร์ล่าสุดให้อยู่ใน Model เดียว (Fix 2 Phase 7.1)
// แทน 8 fields ที่กระจายอยู่ใน PosStateManager

import 'customer.dart';
import 'order_item.dart';
import 'payment_record.dart';

class LastOrderInfo {
  final int orderId;
  final List<OrderItem> items;
  final Customer? customer;
  final double grandTotal;
  final double received;
  final double change;
  final String paymentMethod;
  final double discountAmount;
  final List<PaymentRecord> payments;
  final DateTime orderTime;

  const LastOrderInfo({
    required this.orderId,
    required this.items,
    required this.customer,
    required this.grandTotal,
    required this.received,
    required this.change,
    required this.paymentMethod,
    required this.discountAmount,
    required this.payments,
    required this.orderTime,
  });
}
