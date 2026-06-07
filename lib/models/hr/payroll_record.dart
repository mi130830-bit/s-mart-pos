class PayrollRecord {
  final int id;
  final int employeeId;
  final String payCycle; // 'DAILY', 'WEEKLY', 'MONTHLY'
  final DateTime periodStart;
  final DateTime periodEnd;
  final double workDays;
  final int absentDays;
  final int lateCount;
  final double leaveDays;
  final double dailyWageTotal;
  final double baseSalary;
  final int tripCount;
  final double tripTotalFee;
  final double overtimeHours;
  final double overtimePay;
  final double bonus;
  final double grossPay;
  final double advanceDeductions;
  final double socialSecurity;
  final double otherDeductions;
  final double totalDeductions;
  final double netPay;
  final String status; // 'DRAFT', 'CONFIRMED', 'PAID'
  final int? confirmedBy;
  final DateTime? paidAt;
  final String? note;
  final DateTime? createdAt;
  
  // Joined field
  final String? employeeName;

  PayrollRecord({
    required this.id,
    required this.employeeId,
    required this.payCycle,
    required this.periodStart,
    required this.periodEnd,
    this.workDays = 0.0,
    this.absentDays = 0,
    this.lateCount = 0,
    this.leaveDays = 0.0,
    this.dailyWageTotal = 0.0,
    this.baseSalary = 0.0,
    this.tripCount = 0,
    this.tripTotalFee = 0.0,
    this.overtimeHours = 0.0,
    this.overtimePay = 0.0,
    this.bonus = 0.0,
    required this.grossPay,
    this.advanceDeductions = 0.0,
    this.socialSecurity = 0.0,
    this.otherDeductions = 0.0,
    required this.totalDeductions,
    required this.netPay,
    required this.status,
    this.confirmedBy,
    this.paidAt,
    this.note,
    this.createdAt,
    this.employeeName,
  });

  factory PayrollRecord.fromJson(Map<String, dynamic> json) {
    return PayrollRecord(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      employeeId: int.tryParse(json['employee_id']?.toString() ?? '0') ?? 0,
      payCycle: json['pay_cycle']?.toString() ?? 'MONTHLY',
      periodStart: DateTime.tryParse(json['period_start']?.toString() ?? '') ?? DateTime.now(),
      periodEnd: DateTime.tryParse(json['period_end']?.toString() ?? '') ?? DateTime.now(),
      workDays: double.tryParse(json['work_days']?.toString() ?? '0') ?? 0.0,
      absentDays: int.tryParse(json['absent_days']?.toString() ?? '0') ?? 0,
      lateCount: int.tryParse(json['late_count']?.toString() ?? '0') ?? 0,
      leaveDays: double.tryParse(json['leave_days']?.toString() ?? '0') ?? 0.0,
      dailyWageTotal: double.tryParse(json['daily_wage_total']?.toString() ?? '0') ?? 0.0,
      baseSalary: double.tryParse(json['base_salary']?.toString() ?? '0') ?? 0.0,
      tripCount: int.tryParse(json['trip_count']?.toString() ?? '0') ?? 0,
      tripTotalFee: double.tryParse(json['trip_total_fee']?.toString() ?? '0') ?? 0.0,
      overtimeHours: double.tryParse(json['overtime_hours']?.toString() ?? '0') ?? 0.0,
      overtimePay: double.tryParse(json['overtime_pay']?.toString() ?? '0') ?? 0.0,
      bonus: double.tryParse(json['bonus']?.toString() ?? '0') ?? 0.0,
      grossPay: double.tryParse(json['gross_pay']?.toString() ?? '0') ?? 0.0,
      advanceDeductions: double.tryParse(json['advance_deductions']?.toString() ?? '0') ?? 0.0,
      socialSecurity: double.tryParse(json['social_security']?.toString() ?? '0') ?? 0.0,
      otherDeductions: double.tryParse(json['other_deductions']?.toString() ?? '0') ?? 0.0,
      totalDeductions: double.tryParse(json['total_deductions']?.toString() ?? '0') ?? 0.0,
      netPay: double.tryParse(json['net_pay']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'DRAFT',
      confirmedBy: int.tryParse(json['confirmed_by']?.toString() ?? ''),
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      note: json['note']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      employeeName: json['employeeName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'pay_cycle': payCycle,
      'period_start': "${periodStart.year}-${periodStart.month.toString().padLeft(2, '0')}-${periodStart.day.toString().padLeft(2, '0')}",
      'period_end': "${periodEnd.year}-${periodEnd.month.toString().padLeft(2, '0')}-${periodEnd.day.toString().padLeft(2, '0')}",
      'work_days': workDays,
      'absent_days': absentDays,
      'late_count': lateCount,
      'leave_days': leaveDays,
      'daily_wage_total': dailyWageTotal,
      'base_salary': baseSalary,
      'trip_count': tripCount,
      'trip_total_fee': tripTotalFee,
      'overtime_hours': overtimeHours,
      'overtime_pay': overtimePay,
      'bonus': bonus,
      'gross_pay': grossPay,
      'advance_deductions': advanceDeductions,
      'social_security': socialSecurity,
      'other_deductions': otherDeductions,
      'total_deductions': totalDeductions,
      'net_pay': netPay,
      'status': status,
      'confirmed_by': confirmedBy,
      'paid_at': paidAt?.toIso8601String(),
      'note': note,
    };
  }
}
