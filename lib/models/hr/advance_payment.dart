class AdvancePayment {
  final int id;
  final int employeeId;
  final double amount;
  final DateTime requestDate;
  final String? reason;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED', 'DEDUCTED', 'PARTIAL'
  final int? approvedBy;
  final DateTime? approvedAt;
  final double remainingAmount;
  final double? installmentAmount;
  final String? note;
  final DateTime? createdAt;
  
  // Joined field
  final String? employeeName;

  AdvancePayment({
    required this.id,
    required this.employeeId,
    required this.amount,
    required this.requestDate,
    this.reason,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    required this.remainingAmount,
    this.installmentAmount,
    this.note,
    this.createdAt,
    this.employeeName,
  });

  factory AdvancePayment.fromJson(Map<String, dynamic> json) {
    return AdvancePayment(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      employeeId: int.tryParse(json['employee_id']?.toString() ?? '0') ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      requestDate: DateTime.tryParse(json['request_date']?.toString() ?? '') ?? DateTime.now(),
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      approvedBy: int.tryParse(json['approved_by']?.toString() ?? ''),
      approvedAt: DateTime.tryParse(json['approved_at']?.toString() ?? ''),
      remainingAmount: double.tryParse(json['remaining_amount']?.toString() ?? '0') ?? 0.0,
      installmentAmount: json['installment_amount'] != null ? double.tryParse(json['installment_amount'].toString()) : null,
      note: json['note']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      employeeName: json['employeeName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'amount': amount,
      'request_date': "${requestDate.year}-${requestDate.month.toString().padLeft(2, '0')}-${requestDate.day.toString().padLeft(2, '0')}",
      'reason': reason,
      'status': status,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'remaining_amount': remainingAmount,
      'installment_amount': installmentAmount,
      'note': note,
    };
  }
}
