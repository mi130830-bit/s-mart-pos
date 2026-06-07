class DashboardAttendanceSummary {
  final int employeeId;
  final String employeeName;
  final DateTime? todayIn;
  final DateTime? todayOut;
  final DateTime? todayTempOut;
  final DateTime? todayBackToWork;
  final int tempLeaveMinutes; // รวมนาทีออกชั่วคราว (กลับแล้วเท่านั้น)
  final double totalPresent;
  final double totalLeave;

  DashboardAttendanceSummary({
    required this.employeeId,
    required this.employeeName,
    this.todayIn,
    this.todayOut,
    this.todayTempOut,
    this.todayBackToWork,
    this.tempLeaveMinutes = 0,
    required this.totalPresent,
    required this.totalLeave,
  });

  factory DashboardAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return DashboardAttendanceSummary(
      employeeId: int.tryParse(json['employee_id']?.toString() ?? '0') ?? 0,
      employeeName: json['employeeName'] ?? 'ไม่ระบุชื่อ',
      todayIn: json['today_in'] != null ? DateTime.tryParse(json['today_in'].toString()) : null,
      todayOut: json['today_out'] != null ? DateTime.tryParse(json['today_out'].toString()) : null,
      todayTempOut: json['today_temp_out'] != null ? DateTime.tryParse(json['today_temp_out'].toString()) : null,
      todayBackToWork: json['today_back_to_work'] != null ? DateTime.tryParse(json['today_back_to_work'].toString()) : null,
      tempLeaveMinutes: int.tryParse(json['temp_leave_minutes']?.toString() ?? '0') ?? 0,
      totalPresent: double.tryParse(json['total_present']?.toString() ?? '0') ?? 0.0,
      totalLeave: double.tryParse(json['total_leave']?.toString() ?? '0') ?? 0.0,
    );
  }
}
