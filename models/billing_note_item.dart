class BillingNoteItem {
  final int? id;
  final int? billingNoteId;
  final int? orderId;
  final double amount;

  BillingNoteItem({
    this.id,
    this.billingNoteId,
    this.orderId,
    required this.amount,
  });

  factory BillingNoteItem.fromJson(Map<String, dynamic> json) {
    return BillingNoteItem(
      id: int.tryParse(json['id'].toString()),
      billingNoteId: int.tryParse(json['billingNoteId'].toString()),
      orderId: int.tryParse(json['orderId'].toString()),
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'billingNoteId': billingNoteId,
      'orderId': orderId,
      'amount': amount,
    };
  }
}
