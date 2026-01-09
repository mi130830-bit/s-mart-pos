class DebtorTransaction {
  final int id;
  final int customerId;
  final int? orderId;
  final String type; // 'CREDIT_SALE' or 'PAYMENT'
  final double amount;
  final double balanceBefore; // ✅ ต้องมีตัวนี้
  final double balanceAfter; // ✅ ต้องมีตัวนี้
  final String note;
  final DateTime createdAt;

  DebtorTransaction({
    required this.id,
    required this.customerId,
    this.orderId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.note,
    required this.createdAt,
  });

  factory DebtorTransaction.fromJson(Map<String, dynamic> json) {
    return DebtorTransaction(
      id: int.parse(json['id'].toString()),
      customerId: int.parse(json['customerId'].toString()),
      orderId: json['orderId'] != null
          ? int.parse(json['orderId'].toString())
          : null,
      type: json['transactionType'].toString(),
      amount: double.parse(json['amount'].toString()),
      // ✅ เพิ่มการดึงค่า balanceBefore/After (ใส่ Default 0.0 กัน Error)
      balanceBefore: json['balanceBefore'] != null
          ? double.parse(json['balanceBefore'].toString())
          : 0.0,
      balanceAfter: json['balanceAfter'] != null
          ? double.parse(json['balanceAfter'].toString())
          : 0.0,
      note: json['note']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }
}
