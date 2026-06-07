class LeaveRequest {
  final int id;
  final int employeeId;
  final String leaveType; // 'SICK', 'PERSONAL', 'VACATION', 'MATERNITY', 'OTHER'
  final String leaveFormat; // 'FULL_DAY', 'HALF_MORNING', 'HALF_AFTERNOON', 'HOURLY'
  final DateTime startDate;
  final DateTime endDate;
  final double totalDays;
  final String? reason;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'
  final int? approvedBy;
  final DateTime? approvedAt;
  final String? rejectReason;
  final DateTime? createdAt;
  
  // Joined field
  final String? employeeName;

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.leaveType,
    this.leaveFormat = 'FULL_DAY',
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.reason,
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.rejectReason,
    this.createdAt,
    this.employeeName,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      employeeId: int.tryParse(json['employee_id']?.toString() ?? '0') ?? 0,
      leaveType: json['leave_type']?.toString() ?? 'OTHER',
      leaveFormat: json['leave_format']?.toString() ?? 'FULL_DAY',
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ?? DateTime.now(),
      totalDays: double.tryParse(json['total_days']?.toString() ?? '0') ?? 0.0,
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      approvedBy: int.tryParse(json['approved_by']?.toString() ?? ''),
      approvedAt: DateTime.tryParse(json['approved_at']?.toString() ?? ''),
      rejectReason: json['reject_reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      employeeName: json['employeeName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'leave_type': leaveType,
      'leave_format': leaveFormat,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_days': totalDays,
      'reason': reason,
      'status': status,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'reject_reason': rejectReason,
    };
  }
}
