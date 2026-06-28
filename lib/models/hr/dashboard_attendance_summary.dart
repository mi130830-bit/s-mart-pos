class DashboardAttendanceSummary {
  final int employeeId;
  final String employeeName;
  final DateTime? todayIn;
  final DateTime? todayOut;
  // รอบที่ 1
  final DateTime? todayTempOut;
  final DateTime? todayBackToWork;
  // รอบที่ 2
  final DateTime? todayTempOut2;
  final DateTime? todayBackToWork2;
  // รอบที่ 3
  final DateTime? todayTempOut3;
  final DateTime? todayBackToWork3;
  final int tempLeaveMinutes; // รวมนาทีออกชั่วคราว (กลับแล้วเท่านั้น)
  final double totalPresent;
  final double totalLeave;
  final bool isLeaveToday;

  DashboardAttendanceSummary({
    required this.employeeId,
    required this.employeeName,
    this.todayIn,
    this.todayOut,
    this.todayTempOut,
    this.todayBackToWork,
    this.todayTempOut2,
    this.todayBackToWork2,
    this.todayTempOut3,
    this.todayBackToWork3,
    this.tempLeaveMinutes = 0,
    required this.totalPresent,
    required this.totalLeave,
    this.isLeaveToday = false,
  });

  /// Helper: รอบที่กำลังออกพักอยู่ (null = ไม่ได้ออกพัก)
  int? get activeTempLeaveRound {
    if (todayTempOut != null && todayBackToWork == null) return 1;
    if (todayTempOut2 != null && todayBackToWork2 == null) return 2;
    if (todayTempOut3 != null && todayBackToWork3 == null) return 3;
    return null;
  }

  /// Helper: เวลา tempOut ของรอบที่กำลัง active
  DateTime? get activeTempOutTime {
    final r = activeTempLeaveRound;
    if (r == 1) return todayTempOut;
    if (r == 2) return todayTempOut2;
    if (r == 3) return todayTempOut3;
    return null;
  }

  factory DashboardAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return DashboardAttendanceSummary(
      employeeId: int.tryParse(json['employee_id']?.toString() ?? '0') ?? 0,
      employeeName: json['employeeName'] ?? 'ไม่ระบุชื่อ',
      todayIn: json['today_in'] != null ? DateTime.tryParse(json['today_in'].toString()) : null,
      todayOut: json['today_out'] != null ? DateTime.tryParse(json['today_out'].toString()) : null,
      todayTempOut: json['today_temp_out'] != null ? DateTime.tryParse(json['today_temp_out'].toString()) : null,
      todayBackToWork: json['today_back_to_work'] != null ? DateTime.tryParse(json['today_back_to_work'].toString()) : null,
      todayTempOut2: json['today_temp_out_2'] != null ? DateTime.tryParse(json['today_temp_out_2'].toString()) : null,
      todayBackToWork2: json['today_back_to_work_2'] != null ? DateTime.tryParse(json['today_back_to_work_2'].toString()) : null,
      todayTempOut3: json['today_temp_out_3'] != null ? DateTime.tryParse(json['today_temp_out_3'].toString()) : null,
      todayBackToWork3: json['today_back_to_work_3'] != null ? DateTime.tryParse(json['today_back_to_work_3'].toString()) : null,
      tempLeaveMinutes: int.tryParse(json['temp_leave_minutes']?.toString() ?? '0') ?? 0,
      totalPresent: double.tryParse(json['total_present']?.toString() ?? '0') ?? 0.0,
      totalLeave: double.tryParse(json['total_leave']?.toString() ?? '0') ?? 0.0,
      isLeaveToday: (json['is_leave_today']?.toString() == '1' || json['is_leave_today'] == true) ? true : false,
    );
  }
}
