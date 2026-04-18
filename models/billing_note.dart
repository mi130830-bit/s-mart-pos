class BillingNote {
  final int? id;
  final int customerId;
  final String? customerName; // Joined from DB or passed for display
  final String documentNo;
  final DateTime issueDate;
  final DateTime dueDate;
  final double totalAmount;
  final String? note;
  final String status; // 'PENDING', 'PAID', 'CANCELLED'
  final DateTime? createdAt;
  final int itemCount; // ✅ Added for display
  final DateTime? paymentDate; // ✅ Added for display

  BillingNote({
    this.id,
    required this.customerId,
    this.customerName,
    required this.documentNo,
    required this.issueDate,
    required this.dueDate,
    required this.totalAmount,
    this.note,
    this.status = 'PENDING',
    this.createdAt,
    this.itemCount = 0,
    this.paymentDate,
  });

  factory BillingNote.fromJson(Map<String, dynamic> json) {
    return BillingNote(
      id: int.tryParse(json['id'].toString()),
      customerId: int.tryParse(json['customerId'].toString()) ?? 0,
      customerName: json['customerName'] as String?,
      documentNo: json['documentNo']?.toString() ?? '',
      issueDate:
          DateTime.tryParse(json['issueDate'].toString()) ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['dueDate'].toString()) ?? DateTime.now(),
      totalAmount: double.tryParse(json['totalAmount'].toString()) ?? 0.0,
      note: json['note'] as String?,
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: DateTime.tryParse(json['createdAt'].toString()),
      itemCount: int.tryParse(json['itemCount'].toString()) ?? 0,
      paymentDate: DateTime.tryParse(json['paymentDate'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'documentNo': documentNo,
      'issueDate': issueDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'totalAmount': totalAmount,
      'note': note,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'itemCount': itemCount,
      'paymentDate': paymentDate?.toIso8601String(),
    };
  }
}
