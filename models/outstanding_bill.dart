class OutstandingBill {
  final int orderId;
  final int customerId;
  final double amount; // Original Total Amount
  final double received; // Total Received
  final double remaining; // Remaining Debt for this bill
  final DateTime createdAt;
  final String status; // 'CREDIT' or 'HELD'

  // Debtor Info (Joined)
  final String customerName;
  final String? phone;
  final double currentDebt; // Overall Debt of Customer

  OutstandingBill({
    required this.orderId,
    required this.customerId,
    required this.amount,
    required this.received,
    required this.remaining,
    required this.createdAt,
    required this.status,
    required this.customerName,
    this.phone,
    this.currentDebt = 0.0,
  });

  factory OutstandingBill.fromMap(Map<String, dynamic> map) {
    return OutstandingBill(
      orderId: int.parse(map['orderId'].toString()),
      customerId: int.tryParse(map['customerId'].toString()) ?? 0,
      amount: double.tryParse(map['amount'].toString()) ?? 0.0,
      received: double.tryParse(map['received'].toString()) ?? 0.0,
      remaining: double.tryParse(map['remaining'].toString()) ?? 0.0,
      createdAt: DateTime.parse(map['createdAt'].toString()),
      status: map['status']?.toString() ?? 'CREDIT',
      customerName: '${map["firstName"] ?? ""} ${map["lastName"] ?? ""}'.trim(),
      phone: map['phone']?.toString(),
      currentDebt: double.tryParse(map['currentDebt'].toString()) ?? 0.0,
    );
  }
}
