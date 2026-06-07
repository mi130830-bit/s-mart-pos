class AdvanceDeduction {
  final int id;
  final int advanceId;
  final int payrollId;
  final double deductedAmount;
  final DateTime? deductedAt;

  AdvanceDeduction({
    required this.id,
    required this.advanceId,
    required this.payrollId,
    required this.deductedAmount,
    this.deductedAt,
  });

  factory AdvanceDeduction.fromJson(Map<String, dynamic> json) {
    return AdvanceDeduction(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      advanceId: int.tryParse(json['advance_id']?.toString() ?? '0') ?? 0,
      payrollId: int.tryParse(json['payroll_id']?.toString() ?? '0') ?? 0,
      deductedAmount: double.tryParse(json['deducted_amount']?.toString() ?? '0') ?? 0.0,
      deductedAt: DateTime.tryParse(json['deducted_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'advance_id': advanceId,
      'payroll_id': payrollId,
      'deducted_amount': deductedAmount,
      'deducted_at': deductedAt?.toIso8601String(),
    };
  }
}
